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

    @Flag(name: .long, help: "Emit a machine-readable JSON failure envelope (for lpctl/agents).")
    var json: Bool = false
    
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
        
        let startTime = Date()
        
        do {
            if let beautifyPath = getXcbeautifyPath() {
                TerminalUI.printSubStep("Using xcbeautify to format output...")
                let escapedArgs = args.map { $0.contains(" ") ? "\"\($0)\"" : $0 }
                let fullCommand = "set -o pipefail && xcodebuild \(escapedArgs.joined(separator: " ")) 2>&1 | \(beautifyPath) --quiet"
                try Shell.run("bash", arguments: ["-c", fullCommand], echoPattern: false, quiet: true)
            } else {
                try Shell.run("xcodebuild", arguments: args, quiet: true)
            }
        } catch Shell.ShellError.executionFailed(let status, let output, let error) {
            let elapsed = Date().timeIntervalSince(startTime)
            _ = FailureReporter.report(
                kind: "build", status: status, output: output, systemError: error,
                elapsed: elapsed, json: json
            )
            throw ExitCode.failure
        }

        let elapsed = Date().timeIntervalSince(startTime)
        if json {
            let env = FailureReporter.Envelope(
                success: true, durationSeconds: elapsed, status: 0,
                firstError: "", file: nil, line: nil, column: nil,
                category: "", hints: [], context: [], logPath: nil
            )
            if let data = try? JSONEncoder().encode(env), let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        }
        TerminalUI.printSuccess("Build Succeeded", duration: elapsed)
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
