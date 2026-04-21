import ArgumentParser
import Foundation

struct CleanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Cleans the current project, including a deep DerivedData clean."
    )
    
    @Flag(name: .shortAndLong, help: "Perform a deep clean by blowing away the DerivedData folder associated with this project.")
    var deep: Bool = false
    
    @Flag(name: .customLong("isolated"), help: "Forces isolated caching mode for SPM and DerivedData.")
    var isolated: Bool = false
    
    func run() throws {
        let context = ProjectContext()
        
        guard context.isValid else {
            TerminalUI.printError("No workspace, project, or Package.swift found in the current directory.")
            throw ExitCode.failure
        }
        
        TerminalUI.printMainStep("🧹", message: "Cleaning project...")
        
        var args = ["clean"]
        
        let isIsolated = context.isIsolatedEnvironment(explicitlyRequested: isolated)
        if isIsolated {
            args.append(contentsOf: context.xcodebuildCacheArgs)
        }
        
        args.append(contentsOf: context.xcodebuildTargetArgs)
        
        // Always try to infer the scheme for xcodebuild clean
        if let scheme = context.inferredScheme {
            args.append(contentsOf: ["-scheme", scheme])
        }
        
        // Default clean
        _ = try? Shell.run("xcodebuild", arguments: args, echoPattern: false, quiet: true)
        
        if deep {
            if isIsolated {
                TerminalUI.printSubStep("✨ Isolated Cache Environment! Deep cleaning local folders...")
                let fm = FileManager.default
                let paths = [".derived-data", ".spm-clones", ".spm-cache"]
                for p in paths {
                    let url = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(p)
                    do {
                        if fm.fileExists(atPath: url.path) {
                            try fm.removeItem(at: url)
                            TerminalUI.printSubStep("💥 Deleted isolated folder: \(p)")
                        }
                    } catch {
                        TerminalUI.printError("Failed to delete \(p): \(error.localizedDescription)")
                    }
                }
            } else {
                // "Deep" clean means we want to find the DerivedData folder and delete it globally.
                let projectName = context.inferredScheme ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
                let derivedDataPath = URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Developer/Xcode/DerivedData")
                    
                let fileManager = FileManager.default
                
                do {
                    let directories = try fileManager.contentsOfDirectory(atPath: derivedDataPath.path)
                    
                    // Find directories that start with the project name
                    let matchingDirs = directories.filter { $0.hasPrefix("\(projectName)-") }
                    
                    if matchingDirs.isEmpty {
                        TerminalUI.printSubStep("⚠️ No specific DerivedData folder found for '\(projectName)'.")
                    } else {
                        for dir in matchingDirs {
                            let fullPath = derivedDataPath.appendingPathComponent(dir)
                            try fileManager.removeItem(at: fullPath)
                            TerminalUI.printSubStep("💥 Deleted global DerivedData: \(dir)")
                        }
                    }
                } catch {
                    TerminalUI.printError("Failed to perform deep clean of derived data: \(error.localizedDescription)")
                }
            }
        }
        
        TerminalUI.printSuccess("Clean Complete")
    }
}
