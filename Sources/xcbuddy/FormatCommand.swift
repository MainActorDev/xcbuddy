import ArgumentParser
import Foundation

struct FormatCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "format",
        abstract: "Formats Swift code using SwiftFormat if installed."
    )
    
    @Argument(help: "The directory to format. Defaults to the current directory.")
    var directory: String = "."
    
    // In order to allow parsing an empty array of arguments in the interactive repl
    init() {}
    
    func run() throws {
        TerminalUI.printMainStep("🧹", message: "FORMATTING CODE")
        
        let isInstalled = checkToolInstallation("swiftformat")
        guard isInstalled else {
            TerminalUI.printError("SwiftFormat is not installed.")
            print("Install it via Homebrew: brew install swiftformat")
            throw ExitCode.failure
        }
        
        do {
            _ = try Shell.run("swiftformat", arguments: [directory], echoPattern: true)
            TerminalUI.printSuccess("Formatting complete.")
        } catch {
            TerminalUI.printError("SwiftFormat failed: \(error)")
            throw ExitCode.failure
        }
    }
    
    private func checkToolInstallation(_ tool: String) -> Bool {
        let status = try? Shell.run("which", arguments: [tool], echoPattern: false, quiet: true)
        return status == 0
    }
}
