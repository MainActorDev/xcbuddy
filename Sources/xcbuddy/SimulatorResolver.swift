import Foundation

public enum SimulatorResolver {
    public static func getSimulatorUDID(matching query: String) throws -> String? {
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
    
    public static func getFirstBootedSimulatorUDID() throws -> String? {
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
    
    public static func resolveDestination(from destination: String?) -> String {
        var finalDestination = "generic/platform=iOS Simulator"
        if let destName = destination {
             if destName.contains("=") {
                 finalDestination = destName
             } else if let udid = try? getSimulatorUDID(matching: destName) {
                 finalDestination = "platform=iOS Simulator,id=\(udid)"
             } else {
                 finalDestination = "platform=iOS Simulator,name=\(destName)"
             }
        } else {
             if let bootedUDID = try? getFirstBootedSimulatorUDID() {
                 finalDestination = "platform=iOS Simulator,id=\(bootedUDID)"
             }
        }
        return finalDestination
    }
}
