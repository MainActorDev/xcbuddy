import ArgumentParser
import Foundation

struct SPMCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "spm",
        abstract: "Manage Swift Package Manager dependencies.",
        subcommands: [
            Update.self,
            Resolve.self,
            Clean.self
        ]
    )
    
    struct Update: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Updates swift package dependencies.")
        
        func run() throws {
            TerminalUI.printMainStep("📦", message: "UPDATING PACKAGES")
            _ = try Shell.run("swift", arguments: ["package", "update"], echoPattern: true)
            TerminalUI.printSuccess("Packages updated.")
        }
    }
    
    struct Resolve: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Resolves swift package dependencies.")
        
        func run() throws {
            TerminalUI.printMainStep("📦", message: "RESOLVING PACKAGES")
            _ = try Shell.run("swift", arguments: ["package", "resolve"], echoPattern: true)
            TerminalUI.printSuccess("Packages resolved.")
        }
    }
    
    struct Clean: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Cleans swift package build artifacts.")
        
        func run() throws {
            TerminalUI.printMainStep("🧹", message: "CLEANING PACKAGES")
            _ = try Shell.run("swift", arguments: ["package", "clean"], echoPattern: true)
            TerminalUI.printSuccess("Packages cleaned.")
        }
    }
}
