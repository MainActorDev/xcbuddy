import ArgumentParser
import Foundation

struct InfoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Displays project targets, schemes, and configurations."
    )
    
    func run() throws {
        let context = ProjectContext()
        
        guard context.isValid else {
            TerminalUI.printError("No Xcode project, workspace, or Package.swift found in the current directory.")
            throw ExitCode.failure
        }
        
        TerminalUI.printMainStep("ℹ️", message: "GATHERING PROJECT INFO")
        
        if context.workspace != nil || context.project != nil {
            try printXcodebuildList(context: context)
        } else if context.package != nil {
            try printSwiftPackageDescribe()
        }
    }
    
    private func printXcodebuildList(context: ProjectContext) throws {
        var args = ["-list"]
        args.append(contentsOf: context.xcodebuildTargetArgs)
        
        let output: String
        do {
            output = try Shell.capture("xcodebuild", arguments: args, echoPattern: false)
        } catch {
            TerminalUI.printError("Failed to run 'xcodebuild -list'.")
            throw ExitCode.failure
        }
        
        // xcodebuild -list output varies, but generally sections are indented.
        // We'll just echo it out nicely formatted.
        // To be cleaner, we can print it without the noisy "Information about project..." line
        let lines = output.components(separatedBy: .newlines)
        var filteredLines = [String]()
        
        for line in lines {
            if line.contains("Information about") || line.trimmingCharacters(in: .whitespaces).isEmpty {
                // start capturing after the header
                if !filteredLines.isEmpty || line.trimmingCharacters(in: .whitespaces).isEmpty {
                    filteredLines.append(line)
                }
                continue
            }
            filteredLines.append(line)
        }
        
        // Remove trailing empty lines
        while filteredLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            filteredLines.removeLast()
        }
        
        print("\n" + filteredLines.joined(separator: "\n") + "\n")
    }
    
    private func printSwiftPackageDescribe() throws {
        let output: String
        do {
            output = try Shell.capture("swift", arguments: ["package", "describe"], echoPattern: false)
        } catch {
            TerminalUI.printError("Failed to run 'swift package describe'.")
            throw ExitCode.failure
        }
        
        print("\n" + output + "\n")
    }
}
