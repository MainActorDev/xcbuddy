import ArgumentParser
import Foundation

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Opens the current project in Xcode, or opens its DerivedData folder."
    )
    
    @Flag(name: [.customLong("derived-data")], help: "Open the project's DerivedData folder in Finder.")
    var derivedData: Bool = false
    
    struct Options: ParsableArguments {
        @Flag(name: [.customLong("derived-data")], help: "Open the project's DerivedData folder in Finder.")
        var derivedData: Bool = false
    }
    
    // In order to allow parsing an empty array of arguments in the interactive repl
    init() {}
    
    init(options: Options) {
        self.derivedData = options.derivedData
    }

    func run() throws {
        let context = ProjectContext()
        
        guard context.isValid else {
            TerminalUI.printError("No Xcode project, workspace, or Package.swift found in the current directory.")
            throw ExitCode.failure
        }
        
        if derivedData {
            TerminalUI.printMainStep("📂", message: "OPENING DERIVED DATA")
            try openDerivedData(context: context)
        } else {
            TerminalUI.printMainStep("📂", message: "OPENING PROJECT")
            try openProject(context: context)
        }
    }
    
    private func openProject(context: ProjectContext) throws {
        let targetPath: String
        if let workspace = context.workspace {
            targetPath = workspace
        } else if let project = context.project {
            targetPath = project
        } else if let package = context.package {
            targetPath = package
        } else {
            TerminalUI.printError("Could not determine project path.")
            throw ExitCode.failure
        }
        
        do {
            // First try to open explicitly with Xcode
            let status = try? Shell.run("open", arguments: ["-a", "Xcode", targetPath], echoPattern: false, quiet: true)
            // If that fails (e.g. Xcode isn't named exactly "Xcode" in Applications), just open the file normally
            if status != 0 {
                try Shell.run("open", arguments: [targetPath], echoPattern: false)
            }
            TerminalUI.printSuccess("Opened \(targetPath).")
        } catch {
            TerminalUI.printError("Failed to open project: \(error)")
            throw ExitCode.failure
        }
    }
    
    private func openDerivedData(context: ProjectContext) throws {
        // Use xcodebuild to find the derived data path
        var args = ["-showBuildSettings"]
        args.append(contentsOf: context.xcodebuildTargetArgs)
        
        let output: String
        do {
            // Using quiet execution because we just want the output
            output = try Shell.capture("xcodebuild", arguments: args, echoPattern: false)
        } catch {
            TerminalUI.printError("Failed to fetch build settings. Are you in a valid Xcode project?")
            throw ExitCode.failure
        }
        
        // Grep for BUILD_DIR or similar to find the derived data root
        // A typical line looks like:     BUILD_DIR = /Users/name/Library/Developer/Xcode/DerivedData/Project-abc/Build/Products
        let lines = output.components(separatedBy: .newlines)
        guard let buildDirLine = lines.first(where: { $0.contains("BUILD_DIR =") }) else {
            TerminalUI.printError("Could not determine DerivedData path from build settings.")
            throw ExitCode.failure
        }
        
        let parts = buildDirLine.components(separatedBy: "=")
        guard parts.count == 2 else {
            TerminalUI.printError("Failed to parse BUILD_DIR.")
            throw ExitCode.failure
        }
        
        let buildDir = parts[1].trimmingCharacters(in: .whitespaces)
        
        // We want the root of the project's DerivedData, not the Build/Products dir
        // Usually it's `.../DerivedData/<ProjectName>-<hash>/Build/Products`
        // We'll walk up two directories from BUILD_DIR to get the project's derived data root
        let buildDirURL = URL(fileURLWithPath: buildDir)
        let projectDerivedDataURL = buildDirURL.deletingLastPathComponent().deletingLastPathComponent()
        
        do {
            try Shell.run("open", arguments: [projectDerivedDataURL.path], echoPattern: false)
            TerminalUI.printSuccess("Opened DerivedData: \(projectDerivedDataURL.path)")
        } catch {
            TerminalUI.printError("Failed to open DerivedData folder in Finder.")
            throw ExitCode.failure
        }
    }
}
