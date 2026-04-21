import ArgumentParser
import Foundation

struct LintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Lints Swift code using SwiftLint if installed."
    )
    
    @Argument(help: "The directory to lint. Defaults to the current directory.")
    var directory: String = "."
    
    // In order to allow parsing an empty array of arguments in the interactive repl
    init() {}
    
    func run() throws {
        TerminalUI.printMainStep("🛡️", message: "LINTING CODE")
        
        let isInstalled = checkToolInstallation("swiftlint")
        guard isInstalled else {
            TerminalUI.printError("SwiftLint is not installed.")
            print("Install it via Homebrew: brew install swiftlint")
            throw ExitCode.failure
        }
        
        do {
            _ = try Shell.run("swiftlint", arguments: [directory], echoPattern: true)
            TerminalUI.printSuccess("Linting complete.")
        } catch {
            TerminalUI.printError("SwiftLint checks failed: \(error)")
            throw ExitCode.failure
        }
    }
    
    private func checkToolInstallation(_ tool: String) -> Bool {
        let status = try? Shell.run("which", arguments: [tool], echoPattern: false, quiet: true)
        return status == 0
    }
}
