import ArgumentParser
import Foundation

struct SimCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sim",
        abstract: "Manage simulators with simplified xcrun simctl commands.",
        subcommands: [
            List.self,
            Boot.self
        ]
    )
    
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Lists available simulators nicely.")
        
        func run() throws {
            print("📱 Fetching simulator list...")
            // Run simctl list -j to get JSON
            let jsonString = try Shell.capture("xcrun", arguments: ["simctl", "list", "devices", "-j"])
            guard let data = jsonString.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let devicesDict = json["devices"] as? [String: [[String: Any]]] else {
                print("❌ Failed to parse simulator JSON.")
                return
            }
            
            var hasPrinted = false
            for (runtime, devices) in devicesDict.sorted(by: { $0.key > $1.key }) {
                // Filter out unavailable
                let availableDevices = devices.filter { ($0["isAvailable"] as? Bool) == true || ($0["availability"] as? String) == "(available)" }
                if availableDevices.isEmpty { continue }
                
                // Print Runtime
                let runtimeName = runtime.components(separatedBy: ".").last?.replacingOccurrences(of: "-", with: " ") ?? runtime
                print("\n\(runtimeName):")
                
                for device in availableDevices {
                    let name = device["name"] as? String ?? "Unknown"
                    let state = device["state"] as? String ?? "Unknown"
                    let isBooted = state == "Booted"
                    
                    let icon = isBooted ? "🟢" : "⚪️"
                    print("  \(icon) \(name)")
                }
                hasPrinted = true
            }
            
            if !hasPrinted {
                print("No available simulators found.")
            }
        }
    }
    
    struct Boot: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Fuzzy finds and boots a simulator (e.g. xcbuddy sim boot \"15 pro\").")
        
        @Argument(help: "The part of the simulator name to match (e.g., '15 pro')")
        var query: String
        
        func run() throws {
            try tryBootSimulator(query: query)
        }
    }
    
    /// A helper function to find and boot a simulator by fuzzy name
    static func tryBootSimulator(query: String) throws {
        print("🔍 Searching for simulator matching '\(query)'...")
        let jsonString = try Shell.capture("xcrun", arguments: ["simctl", "list", "devices", "-j"])
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesDict = json["devices"] as? [String: [[String: Any]]] else {
            print("❌ Failed to parse simulator JSON.")
            return
        }
        
        // Find best match
        var bestMatch: [String: Any]?
        
        // Prefer iOS runtimes
        let runtimes = devicesDict.keys.sorted(by: { $0 > $1 })
        
        outerLoop: for runtime in runtimes {
            guard let devices = devicesDict[runtime] else { continue }
            for device in devices {
                let isAvailable = (device["isAvailable"] as? Bool) == true || (device["availability"] as? String) == "(available)"
                guard isAvailable else { continue }
                
                let name = (device["name"] as? String ?? "").lowercased()
                if name.contains(query.lowercased()) {
                    bestMatch = device
                    break outerLoop // Break early on first match, since we sorted runtimes to prefer latest
                }
            }
        }
        
        guard let match = bestMatch, let udid = match["udid"] as? String, let name = match["name"] as? String else {
            print("❌ No simulator found matching '\(query)'.")
            return
        }
        
        let state = match["state"] as? String ?? "Unknown"
        if state == "Booted" {
            print("✅ \(name) is already booted.")
            try self.openSimulatorApp()
            return
        }
        
        print("📱 Booting \(name)...")
        _ = try Shell.run("xcrun", arguments: ["simctl", "boot", udid], echoPattern: false)
        try self.openSimulatorApp()
    }
    
    static func openSimulatorApp() throws {
        // Open the Simulator application to bring it to foreground
        _ = try Shell.run("open", arguments: ["-a", "Simulator"], echoPattern: false)
    }
}
