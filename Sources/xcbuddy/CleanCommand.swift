import ArgumentParser
import Foundation

struct CleanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Cleans the current project, including a deep DerivedData clean."
    )
    
    @Flag(name: .shortAndLong, help: "Perform a deep clean by blowing away the DerivedData folder associated with this project.")
    var deep: Bool = false
    
    func run() throws {
        let context = ProjectContext()
        
        guard context.isValid else {
            print("❌ No workspace, project, or Package.swift found in the current directory.")
            throw ExitCode.failure
        }
        
        print("🧹 Cleaning project...")
        
        var args = ["clean"]
        args.append(contentsOf: context.xcodebuildTargetArgs)
        
        // Always try to infer the scheme for xcodebuild clean
        if let scheme = context.inferredScheme {
            args.append(contentsOf: ["-scheme", scheme])
        }
        
        // Default clean
        _ = try? Shell.run("xcodebuild", arguments: args, echoPattern: false)
        
        if deep {
            // "Deep" clean means we want to find the DerivedData folder and delete it.
            // A simple approach is just to blow away the global DerivedData (if user really wants)
            // or we try to find the specific folder. For xcbuddy, blowing away the specific app folder is best.
            // Let's use `rm -rf ~/Library/Developer/Xcode/DerivedData/ProjectName-*`
            let projectName = context.inferredScheme ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
            let derivedDataPath = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Developer/Xcode/DerivedData")
                
            let fileManager = FileManager.default
            
            do {
                let directories = try fileManager.contentsOfDirectory(atPath: derivedDataPath.path)
                
                // Find directories that start with the project name
                let matchingDirs = directories.filter { $0.hasPrefix("\(projectName)-") }
                
                if matchingDirs.isEmpty {
                    print("⚠️ No specific DerivedData folder found for '\(projectName)'.")
                } else {
                    for dir in matchingDirs {
                        let fullPath = derivedDataPath.appendingPathComponent(dir)
                        try fileManager.removeItem(at: fullPath)
                        print("🗑️  Deleted specific DerivedData: \(dir)")
                    }
                }
            } catch {
                print("⚠️ Failed to perform deep clean of derived data: \(error.localizedDescription)")
            }
        }
        
        print("✅ Clean complete!")
    }
}
