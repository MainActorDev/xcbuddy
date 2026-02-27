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
                print("  s : Select and boot a simulator")
                print("  c : Clean project (standard)")
                print("  q : Quit interactive mode\n")
            case "s":
                do {
                    TerminalUI.printMainStep("📱", message: "SELECTING SIMULATOR")
                    try handleSimulatorSelection()
                } catch {
                    TerminalUI.printError("Simulator selection failed: \(error)")
                }
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
    
    // MARK: - Simulator Selection Helpers
    
    private func handleSimulatorSelection() throws {
        let jsonString = try Shell.capture("xcrun", arguments: ["simctl", "list", "devices", "-j"])
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesDict = json["devices"] as? [String: [[String: Any]]] else {
            TerminalUI.printError("Failed to parse simulator JSON.")
            return
        }
        
        var availableSimulators: [(name: String, udid: String, isBooted: Bool)] = []
        
        // Flatten and filter the JSON structure
        for (_, devices) in devicesDict.sorted(by: { $0.key > $1.key }) {
            for device in devices {
                let isAvailable = (device["isAvailable"] as? Bool) == true || (device["availability"] as? String) == "(available)"
                if isAvailable,
                   let name = device["name"] as? String,
                   let udid = device["udid"] as? String {
                    let isBooted = (device["state"] as? String) == "Booted"
                    availableSimulators.append((name, udid, isBooted))
                }
            }
        }
        
        guard !availableSimulators.isEmpty else {
            TerminalUI.printError("No available simulators found.")
            return
        }
        
        print("\n\(TerminalUI.textBold("Available Simulators:"))")
        for (index, sim) in availableSimulators.enumerated() {
            let icon = sim.isBooted ? "🟢" : "⚪️"
            print("  [\(index)] \(icon) \(sim.name)")
        }
        
        print("\nEnter number to boot (or press Enter to cancel): ", terminator: "")
        
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            print("Selection cancelled.\n")
            return
        }
        
        guard let index = Int(input), index >= 0, index < availableSimulators.count else {
            TerminalUI.printError("Invalid selection.\n")
            return
        }
        
        let target = availableSimulators[index]
        if target.isBooted {
            TerminalUI.printSuccess("\(target.name) is already booted.\n")
            try SimCommand.openSimulatorApp()
            return
        }
        
        TerminalUI.printMainStep("🚀", message: "Booting \(target.name)...")
        _ = try Shell.run("xcrun", arguments: ["simctl", "boot", target.udid], echoPattern: false)
        try SimCommand.openSimulatorApp()
        print("\n")
    }
}
