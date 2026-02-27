import ArgumentParser
import Foundation

struct InteractiveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "interactive",
        abstract: "Starts the xcbuddy interactive dashboard (REPL)."
    )
    
    func run() throws {
        // Clear screen and print persistent header
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        
        let context = ProjectContext()
        TerminalUI.printHeader(project: context)
        
        // Disable terminal line buffering so we can read single keystrokes
        var termios = termios()
        tcgetattr(STDIN_FILENO, &termios)
        var oldTermios = termios
        
        termios.c_lflag &= ~(UInt(ICANON) | UInt(ECHO))
        tcsetattr(STDIN_FILENO, TCSANOW, &termios)
        
        // Ensure we restore terminal state on exit
        defer {
            tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios)
            print("\n")
        }
        
        var isRunning = true
        while isRunning {
            TerminalUI.printPrompt()
            
            var buffer = [UInt8](repeating: 0, count: 1)
            let bytesRead = read(STDIN_FILENO, &buffer, 1)
            
            guard bytesRead > 0 else {
                break
            }
            
            let charSequence = String(bytes: buffer, encoding: .utf8) ?? ""
            print(charSequence) // Echo character back
            
            // Restore terminal state before running subcommands
            tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios)
            
            switch charSequence.lowercased() {
            case "r":
                do {
                    TerminalUI.printMainStep("▶️", message: "RUNNING \(context.inferredScheme ?? "Project")")
                    let runCommand = try RunCommand.parse([])
                    try runCommand.run()
                    print("\n")
                } catch {
                    TerminalUI.printError("Run failed.")
                }
            case "b":
                do {
                    TerminalUI.printMainStep("🛠️", message: "BUILDING \(context.inferredScheme ?? "Project")")
                    let buildCommand = try BuildCommand.parse([])
                    try buildCommand.run()
                    print("\n")
                } catch {
                    TerminalUI.printError("Build failed.")
                }
            case "t":
                do {
                    TerminalUI.printMainStep("🧪", message: "TESTING \(context.inferredScheme ?? "Project")")
                    let testCommand = try TestCommand.parse([])
                    try testCommand.run()
                    print("\n")
                } catch {
                    TerminalUI.printError("Test failed.")
                }
            case "l":
                do {
                    TerminalUI.printMainStep("📝", message: "STREAMING LOGS")
                    let logsCommand = try LogCommand.parse([])
                    try logsCommand.run()
                    print("\n")
                } catch {
                    TerminalUI.printError("Logs failed.")
                }
            case "h":
                print("\n\(TerminalUI.textBold("xcbuddy shortcuts:"))")
                print("  r : Run app on simulator")
                print("  b : Build project")
                print("  t : Run tests")
                print("  l : Stream simulator logs")
                print("  c : Clean project (standard)")
                print("  q : Quit interactive mode\n")
            case "c":
                 do {
                     TerminalUI.printMainStep("🧹", message: "CLEANING \(context.inferredScheme ?? "Project")")
                     let cleanCommand = try CleanCommand.parse([])
                     try cleanCommand.run()
                     print("\n")
                 } catch {
                     TerminalUI.printError("Clean failed.")
                 }
            case "q":
                isRunning = false
            case "\n", "\r":
                // Ignore empty returns
                break
            default:
                print("Unknown command. Press 'h' for help.\n")
            }
            
            // Re-disable canonical mode and echo for the next input
            if isRunning {
                tcsetattr(STDIN_FILENO, TCSANOW, &termios)
            }
        }
    }
}
