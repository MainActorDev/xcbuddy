import ArgumentParser
import Foundation

struct CreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Creates a new Swift project."
    )
    
    @Argument(help: "The name of the new project.")
    var name: String
    
    @Option(name: .shortAndLong, help: "The type of project (executable, library). Defaults to executable.")
    var type: String = "executable"
    
    func run() throws {
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        let projectPath = URL(fileURLWithPath: currentPath).appendingPathComponent(name).path
        
        if fileManager.fileExists(atPath: projectPath) {
            TerminalUI.printError("Directory '\(name)' already exists.")
            throw ExitCode.failure
        }
        
        TerminalUI.printMainStep("📁", message: "Creating project directory: \(name)...")
        try fileManager.createDirectory(atPath: projectPath, withIntermediateDirectories: true, attributes: nil)
        
        fileManager.changeCurrentDirectoryPath(projectPath)
        
        TerminalUI.printSubStep("Initializing Swift \(type)...")
        _ = try Shell.run("swift", arguments: ["package", "init", "--type", type, "--name", name], echoPattern: false)
        TerminalUI.completeLastSubStep("Initialized Swift \(type)")
        
        TerminalUI.printSuccess("Project '\(name)' created successfully at \(projectPath)")
        TerminalUI.printSubStep("cd \(name) && xcbuddy build\n")
    }
}
