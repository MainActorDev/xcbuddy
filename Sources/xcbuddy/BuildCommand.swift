import ArgumentParser
import Foundation

struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Builds the current project automatically."
    )
    
    @Option(name: .shortAndLong, help: "The scheme to build. Defaults to the inferred project name.")
    var scheme: String?
    
    @Option(name: .shortAndLong, help: "The destination to build for. Defaults to iOS Simulator.")
    var destination: String?
    
    @Flag(name: .customLong("isolated"), help: "Forces isolated caching mode for SPM and DerivedData.")
    var isolated: Bool = false
    
    func run() throws {
        let context = ProjectContext()
        
        guard context.isValid else {
            TerminalUI.printError("No workspace, project, or Package.swift found in the current directory.")
            throw ExitCode.failure
        }
        
        var args = ["build"]
        
        if context.isIsolatedEnvironment(explicitlyRequested: isolated) {
            args.append(contentsOf: context.xcodebuildCacheArgs)
            TerminalUI.printSubStep("✨ Auto-detected Isolated Cache Environment!")
        }
        
        // Target args (-workspace or -project)
        args.append(contentsOf: context.xcodebuildTargetArgs)
        
        // Scheme
        let buildScheme = scheme ?? context.inferredScheme
        if let buildScheme {
             args.append(contentsOf: ["-scheme", buildScheme])
        } else {
             TerminalUI.printSubStep("⚠️ Could not infer a scheme automatically. You may need to provide one with --scheme.")
        }
        
        // Destination
        let finalDestination = SimulatorResolver.resolveDestination(from: destination)
        args.append(contentsOf: ["-destination", finalDestination])
        
        TerminalUI.printMainStep("🛠️", message: "Building \(buildScheme ?? "project") for \(finalDestination)...")
        
        do {
            if let beautifyPath = getXcbeautifyPath() {
                TerminalUI.printSubStep("Using xcbeautify to format output...")
                let fullCommand = "set -o pipefail && xcodebuild \(args.joined(separator: " ")) | \(beautifyPath) --quiet"
                try Shell.run("bash", arguments: ["-c", fullCommand], echoPattern: false, quiet: true)
            } else {
                try Shell.run("xcodebuild", arguments: args, quiet: true)
            }
        } catch Shell.ShellError.executionFailed(let status, let output, let error) {
            TerminalUI.printError("Build Failed (Status \(status))")
            
            print("\n🚨 ====== FAILURE DETAILS ======")
            if !output.isEmpty {
                print(output)
            }
            if !error.isEmpty {
                print("\n🚨 ====== SYSTEM ERRORS ======")
                print(error)
            }
            throw ExitCode.failure
        }
        
        TerminalUI.printSuccess("Build Succeeded")
    }
    
    /// Helper to check if a command exists in the user's path
    private func getXcbeautifyPath() -> String? {
        if let path = try? Shell.capture("which", arguments: ["xcbeautify"]), !path.isEmpty {
            return "xcbeautify"
        }
        let homebrewPath = "/opt/homebrew/bin/xcbeautify"
        if FileManager.default.fileExists(atPath: homebrewPath) {
            return homebrewPath
        }
        return nil
    }
}
