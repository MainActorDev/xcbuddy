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
    public var inferredScheme: String? {
        if let workspace {
            return (workspace as NSString).deletingPathExtension
        } else if let project {
            return (project as NSString).deletingPathExtension
        } else if package != nil {
            let dirName = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
            return dirName
        }
        return nil
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
}
