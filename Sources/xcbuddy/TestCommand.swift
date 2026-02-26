import ArgumentParser
import Foundation

struct TestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Builds and runs tests."
    )
    
    @Option(name: .shortAndLong, help: "The scheme to test.")
    var scheme: String?
    
    @Option(name: .customLong("only"), help: "Run only a specific test class or method (e.g. MyAppTests/LoginTests)")
    var onlyTest: String?
    
    @Option(name: .shortAndLong, help: "The destination to test on (e.g. \"15 pro\"). Defaults to an iOS Simulator.")
    var destination: String?
    
    func run() throws {
        let context = ProjectContext()
        guard context.isValid else {
            TerminalUI.printError("No workspace, project, or Package.swift found in the current directory.")
            throw ExitCode.failure
        }
        
        var args = ["test"]
        args.append(contentsOf: context.xcodebuildTargetArgs)
        
        let buildScheme = scheme ?? context.inferredScheme
        if let buildScheme {
             args.append(contentsOf: ["-scheme", buildScheme])
        }
        
        // Resolve Destination (Simplified for now, similar to build)
        let finalDestination = destination ?? "generic/platform=iOS Simulator"
        args.append(contentsOf: ["-destination", finalDestination])
        
        if let onlyTest {
            args.append(contentsOf: ["-only-testing:\(onlyTest)"])
        }
        
        TerminalUI.printMainStep("🧪", message: "Testing \(buildScheme ?? "project")...")
        
        let useBeautify = try isCommandAvailable("xcbeautify")
        if useBeautify {
            TerminalUI.printSubStep("Using xcbeautify to format output...")
            let fullCommand = "xcodebuild \(args.joined(separator: " ")) | xcbeautify"
            try Shell.run("bash", arguments: ["-c", fullCommand], echoPattern: false)
        } else {
            try Shell.run("xcodebuild", arguments: args)
        }
        
        TerminalUI.printSuccess("Testing Completed")
    }
    
    private func isCommandAvailable(_ tool: String) throws -> Bool {
        do {
            _ = try Shell.capture("which", arguments: [tool])
            return true
        } catch {
            return false
        }
    }
}
