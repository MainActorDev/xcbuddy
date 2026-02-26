import ArgumentParser
import Foundation

struct LogCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "Tail the OS log of a booted simulator."
    )
    
    @Option(name: .shortAndLong, help: "The device to stream logs from. Defaults to 'booted' simulator.")
    var destination: String?
    
    @Option(name: .shortAndLong, help: "Filter by a specific process name or bundle identifier.")
    var process: String?
    
    func run() throws {
        var simTargetUDID = "booted"
        
        if let destName = destination {
            if let udid = try? getSimulatorUDID(matching: destName) {
                simTargetUDID = udid
            } else {
                print("⚠️ Could not find specific simulator matching '\(destName)'. Falling back to 'booted'.")
            }
        } else {
            if let bootedUDID = try? getFirstBootedSimulatorUDID() {
                simTargetUDID = bootedUDID
            }
        }
        
        print("📝 Streaming logs for Simulator \(simTargetUDID)... (Press Ctrl+C to stop)")
        var args = ["simctl", "spawn", simTargetUDID, "log", "stream"]
        if let process = process {
             args.append(contentsOf: ["--predicate", "processImagePath contains \"\(process)\""])
        }
        
        _ = try Shell.run("xcrun", arguments: args, echoPattern: false)
    }
    
    private func getSimulatorUDID(matching query: String) throws -> String? {
        let jsonString = try Shell.capture("xcrun", arguments: ["simctl", "list", "devices", "-j"], echoPattern: false)
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesDict = json["devices"] as? [String: [[String: Any]]] else { return nil }
        
        let runtimes = devicesDict.keys.sorted(by: { $0 > $1 })
        for runtime in runtimes {
            guard let devices = devicesDict[runtime] else { continue }
            for device in devices {
                let isAvailable = (device["isAvailable"] as? Bool) == true || (device["availability"] as? String) == "(available)"
                guard isAvailable else { continue }
                
                let name = (device["name"] as? String ?? "").lowercased()
                if name.contains(query.lowercased()) {
                    return device["udid"] as? String
                }
            }
        }
        return nil
    }
    
    private func getFirstBootedSimulatorUDID() throws -> String? {
        let jsonString = try Shell.capture("xcrun", arguments: ["simctl", "list", "devices", "-j"], echoPattern: false)
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesDict = json["devices"] as? [String: [[String: Any]]] else { return nil }
              
        for (_, devices) in devicesDict {
            for device in devices {
                if (device["state"] as? String) == "Booted" {
                    return device["udid"] as? String
                }
            }
        }
        return nil
    }
}
