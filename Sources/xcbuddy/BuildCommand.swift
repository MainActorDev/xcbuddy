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
    
    func run() throws {
        let context = ProjectContext()
        
        guard context.isValid else {
            TerminalUI.printError("No workspace, project, or Package.swift found in the current directory.")
            throw ExitCode.failure
        }
        
        var args = ["build"]
        
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
        let finalDestination = destination ?? "generic/platform=iOS Simulator"
        args.append(contentsOf: ["-destination", finalDestination])
        
        // Default to beautified output if xcbeautify is installed
        let useBeautify = try isCommandAvailable("xcbeautify")
        
        TerminalUI.printMainStep("🛠️", message: "Building \(buildScheme ?? "project") for \(finalDestination)...")
        
        if useBeautify {
            TerminalUI.printSubStep("Using xcbeautify to format output...")
            
            // For xcbeautify, we pipe using the bash shell to handle the pipe properly
            let fullCommand = "xcodebuild \(args.joined(separator: " ")) | xcbeautify"
            try Shell.run("bash", arguments: ["-c", fullCommand], echoPattern: false)
        } else {
            // raw xcodebuild
            try Shell.run("xcodebuild", arguments: args)
        }
        
        TerminalUI.printSuccess("Build Succeeded")
    }
    
    /// Helper to check if a command exists in the user's path
    private func isCommandAvailable(_ tool: String) throws -> Bool {
        do {
            _ = try Shell.capture("which", arguments: [tool])
            return true
        } catch {
            return false
        }
    }
}
