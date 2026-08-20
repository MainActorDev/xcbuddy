import Foundation

/// Represents the Xcode project context in the current directory.
public struct ProjectContext {
    public var workspace: String?
    public var project: String?
    public var package: String?
    
    public init(directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory.path)
            
            // Auto-detect workspaces (prefer these)
            if let foundWorkspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
                self.workspace = foundWorkspace
            }
            
            // Auto-detect projects
            if let foundProject = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                self.project = foundProject
            }
            
            // Auto-detect Swift PM packages
            if contents.contains("Package.swift") {
                self.package = "Package.swift"
            }
        } catch {
            print("Failed to read directory contents: \(error)")
        }
    }
    
    /// True if we have some sort of buildable target
    public var isValid: Bool {
        workspace != nil || project != nil || package != nil
    }
    
    /// Guesses the default scheme based on the file names.
    /// This removes the .xcworkspace or .xcodeproj extension to guess a common scheme.
    /// For workspaces, filename ≠ scheme name in practice (CocoaPods workspaces
    /// expose app schemes like Dev/Production/Staging, not the workspace name).
    /// So: ask `xcodebuild -list` and prefer a scheme matching the directory or
    /// project name; fall back to the filename heuristic only if listing fails.
    public var inferredScheme: String? {
        let fm = FileManager.default
        let dirName = URL(fileURLWithPath: fm.currentDirectoryPath).lastPathComponent

        if let workspace {
            if let listed = Self.listSchemes(target: "-workspace", name: workspace) {
                // Preference order: directory name, project name, known app
                // build-config scheme names (CocoaPods repos expose Dev/
                // Staging/Production instead of the project name), then any
                // app-like scheme — skipping dependency-looking ones
                // (Pods-*, package/product names like Alamofire, test bundles).
                if listed.contains(dirName) { return dirName }
                if let project {
                    let projName = (project as NSString).deletingPathExtension
                    if listed.contains(projName) { return projName }
                }
                for candidate in ["Dev", "Development", "Staging", "Production"] where listed.contains(candidate) {
                    return candidate
                }
                let dependencyPrefixes = ["Pods-", "Pods_"]
                let dependencyish: (String) -> Bool = { s in
                    if dependencyPrefixes.contains(where: { s.hasPrefix($0) }) { return true }
                    // Ends in -Tests/-UITests = test bundle, not the app
                    if s.hasSuffix("-Tests") || s.hasSuffix("-UITests") { return true }
                    return false
                }
                if let first = listed.first(where: { !dependencyish($0) && !$0.hasPrefix("Pods-") }) {
                    return first
                }
            }
            return (workspace as NSString).deletingPathExtension
        } else if let project {
            if let listed = Self.listSchemes(target: "-project", name: project) {
                let projName = (project as NSString).deletingPathExtension
                if listed.contains(projName) { return projName }
                if let first = listed.first(where: { !$0.hasPrefix("Pods-") }) {
                    return first
                }
            }
            return (project as NSString).deletingPathExtension
        } else if package != nil {
            return dirName
        }
        return nil
    }

    /// Synchronous scheme listing via xcodebuild -list (best effort, cached per instance).
    private static let schemeCache = SchemeCache()
    private final class SchemeCache: @unchecked Sendable {
        private var storage: [String: [String]] = [:]
        private let lock = NSLock()
        func get(_ key: String) -> [String]? {
            lock.lock(); defer { lock.unlock() }
            return storage[key]
        }
        func set(_ key: String, _ value: [String]) {
            lock.lock(); defer { lock.unlock() }
            storage[key] = value
        }
    }
    private static func listSchemes(target: String, name: String) -> [String]? {
        let key = "\(target):\(name)"
        if let cached = schemeCache.get(key) { return cached }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xcodebuild", "-list", target, name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let data = try? pipe.fileHandleForReading.readToEnd(),
              let out = String(data: data, encoding: .utf8) else { return nil }

        var schemes: [String] = []
        var inSchemes = false
        for line in out.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "Schemes:" { inSchemes = true; continue }
            if inSchemes {
                if trimmed.isEmpty { break }
                schemes.append(trimmed)
            }
        }
        guard !schemes.isEmpty else { return nil }
        schemeCache.set(key, schemes)
        return schemes
    }
    
    /// Generates xcodebuild arguments based on the context
    public var xcodebuildTargetArgs: [String] {
        if let workspace {
            return ["-workspace", workspace]
        } else if let project {
            return ["-project", project]
        }
        return []
    }
    
    /// Determines if the current environment should natively intercept caching overrides
    public func isIsolatedEnvironment(explicitlyRequested: Bool) -> Bool {
        if explicitlyRequested { return true }
        
        let fm = FileManager.default
        let currentDir = fm.currentDirectoryPath
        let derivedData = URL(fileURLWithPath: currentDir).appendingPathComponent(".derived-data").path
        let spmClones = URL(fileURLWithPath: currentDir).appendingPathComponent(".spm-clones").path
        
        return fm.fileExists(atPath: derivedData) || fm.fileExists(atPath: spmClones)
    }
    
    /// The isolated xcodebuild overrides for local SPM caches
    public var xcodebuildCacheArgs: [String] {
        let currentDir = FileManager.default.currentDirectoryPath
        let derivedData = URL(fileURLWithPath: currentDir).appendingPathComponent(".derived-data").path
        let spmCache = URL(fileURLWithPath: currentDir).appendingPathComponent(".spm-cache").path
        let spmClones = URL(fileURLWithPath: currentDir).appendingPathComponent(".spm-clones").path
        
        return [
            "-clonedSourcePackagesDirPath", spmClones,
            "-packageCachePath", spmCache,
            "-derivedDataPath", derivedData,
            "-disableAutomaticPackageResolution",
            "-onlyUsePackageVersionsFromResolvedFile",
            "-skipPackageUpdates"
        ]
    }
}
