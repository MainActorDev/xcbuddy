import ArgumentParser
import Foundation

@main
struct XCBuddy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcbuddy",
        abstract: "A friendly wrapper around xcodebuild and simctl.",
        version: "1.0.0",
        subcommands: [
            BuildCommand.self,
            CleanCommand.self,
            TestCommand.self,
            SimCommand.self,
            RunCommand.self,
            CreateCommand.self,
            LogCommand.self,
            InteractiveCommand.self,
            I.self
        ]
    )
}

struct I: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "i",
        abstract: "Alias for `interactive`."
    )
    func run() throws {
        let cmd = InteractiveCommand()
        try cmd.run()
    }
}
