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
    
    @Flag(name: [.short, .customLong("coverage")], help: "Enable code coverage and print/open the report.")
    var coverage: Bool = false
    
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
        
        let resultBundlePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".xcbuddy_test_results.xcresult").path
        
        if coverage {
            args.append(contentsOf: ["-enableCodeCoverage", "YES"])
            args.append(contentsOf: ["-resultBundlePath", resultBundlePath])
            // Standard xcodebuild fails if result bundle already exists
            try? FileManager.default.removeItem(atPath: resultBundlePath)
        }
        
        TerminalUI.printMainStep("🧪", message: "Testing \(buildScheme ?? "project")...")
        
        let useBeautify = try isCommandAvailable("xcbeautify")
        if useBeautify {
            TerminalUI.printSubStep("Using xcbeautify to format output...")
            let fullCommand = "xcodebuild \(args.joined(separator: " ")) | xcbeautify"
            try Shell.run("bash", arguments: ["-c", fullCommand], echoPattern: false, quiet: true)
        } else {
            try Shell.run("xcodebuild", arguments: args, quiet: true)
        }
        
        TerminalUI.printSuccess("Testing Completed")
        
        if coverage {
            try generateCoverageReport(resultBundlePath: resultBundlePath)
        }
    }
    
    private func generateCoverageReport(resultBundlePath: String) throws {
        guard FileManager.default.fileExists(atPath: resultBundlePath) else {
            TerminalUI.printError("Coverage report bundle not found at \(resultBundlePath)")
            return
        }
        
        TerminalUI.printMainStep("📊", message: "GENERATING COVERAGE REPORT")
        
        let hasHtmlReport = try isCommandAvailable("xchtmlreport")
        if hasHtmlReport {
            TerminalUI.printSubStep("Using xchtmlreport...")
            _ = try Shell.run("xchtmlreport", arguments: ["-r", resultBundlePath], echoPattern: false)
            _ = try? Shell.run("open", arguments: ["index.html"], echoPattern: false)
        } else {
            TerminalUI.printSubStep("Printing xccov report...")
            let report = try Shell.capture("xcrun", arguments: ["xccov", "view", "--report", "--only-targets", resultBundlePath])
            
            // The first line might be blank or have header, just print it padded
            print("\n\(report)\n")
        }
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
