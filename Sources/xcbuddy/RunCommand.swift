import ArgumentParser
import Foundation

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Builds and runs the app on the booted simulator."
    )
    
    @Option(name: .shortAndLong, help: "The scheme to run. Defaults to inferred scheme.")
    var scheme: String?
    
    @Option(name: .shortAndLong, help: "The device to run on. Defaults to 'booted' simulator.")
    var destination: String?
    
    func run() throws {
        let context = ProjectContext()
        guard context.isValid else {
            print("❌ No valid Xcode project found.")
            throw ExitCode.failure
        }
        
        let buildScheme = scheme ?? context.inferredScheme
        print("🚀 Preparing \(buildScheme ?? "project") for execution...")
        
        // Find the simulator UDID early so we can build specifically for its architecture
        var finalDestination = "generic/platform=iOS Simulator"
        var simTargetUDID = "booted"
        
        if let destName = destination {
             // User requested specific simulator, try to resolve its UDID
             if let udid = try? getSimulatorUDID(matching: destName) {
                 finalDestination = "platform=iOS Simulator,id=\(udid)"
                 simTargetUDID = udid
             } else {
                 print("⚠️ Could not find specific simulator matching '\(destName)'. Falling back to generic simulator.")
             }
        } else {
            // Find a currently booted simulator UDID just in case 'booted' is ambiguous
             if let bootedUDID = try? getFirstBootedSimulatorUDID() {
                 finalDestination = "platform=iOS Simulator,id=\(bootedUDID)"
                 simTargetUDID = bootedUDID
             }
        }
        
        // 1. Build the project using our BuildCommand logic
        var buildArgs = ["build"]
        buildArgs.append(contentsOf: context.xcodebuildTargetArgs)
        if let buildScheme { buildArgs.append(contentsOf: ["-scheme", buildScheme]) }
        buildArgs.append(contentsOf: ["-destination", finalDestination])
        
        print("🛠️  Compiling for \(finalDestination)...")
        let useBeautify = try isCommandAvailable("xcbeautify")
        if useBeautify {
            let fullCommand = "xcodebuild \(buildArgs.joined(separator: " ")) | xcbeautify"
            try Shell.run("bash", arguments: ["-c", fullCommand], echoPattern: false)
        } else {
            try Shell.run("xcodebuild", arguments: buildArgs)
        }
        
        // 2. Locate built product
        print("🔍 Locating build product...")
        var settingsArgs = ["xcodebuild", "-showBuildSettings"]
        settingsArgs.append(contentsOf: context.xcodebuildTargetArgs)
        if let buildScheme { settingsArgs.append(contentsOf: ["-scheme", buildScheme]) }
        settingsArgs.append(contentsOf: ["-destination", finalDestination])
        
        let settingsOutput = try Shell.capture("xcodebuild", arguments: Array(settingsArgs.dropFirst()), echoPattern: false)
        print("💡 settingsOutput character count: \(settingsOutput.count)")
        
        guard let buildDir = extractSetting(from: settingsOutput, key: "TARGET_BUILD_DIR"),
              let productName = extractSetting(from: settingsOutput, key: "FULL_PRODUCT_NAME"),
              let bundleIdentifier = extractSetting(from: settingsOutput, key: "PRODUCT_BUNDLE_IDENTIFIER") else {
            print("❌ Could not determine built app path or bundle identifier.")
            print("💡 This usually happens if you are trying to 'run' a framework or library package instead of an application target (e.g. running from the root instead of the Demo/ folder).")
            // Debug the keys 
            let dir = extractSetting(from: settingsOutput, key: "TARGET_BUILD_DIR")
            let name = extractSetting(from: settingsOutput, key: "FULL_PRODUCT_NAME")
            let id = extractSetting(from: settingsOutput, key: "PRODUCT_BUNDLE_IDENTIFIER")
            print("TARGET_BUILD_DIR: \(dir ?? "nil")")
            print("FULL_PRODUCT_NAME: \(name ?? "nil")")
            print("PRODUCT_BUNDLE_IDENTIFIER: \(id ?? "nil")")
            throw ExitCode.failure
        }
        
        let appPath = URL(fileURLWithPath: buildDir).appendingPathComponent(productName).path
        
        // Ensure simulator is booted (ignore error if it's already booted)
        _ = try? Shell.run("xcrun", arguments: ["simctl", "boot", simTargetUDID], echoPattern: false)
        
        // Open Simulator app *before* installing/launching so the UI workspace is ready
        print("🖥️  Opening Simulator...")
        _ = try Shell.run("open", arguments: ["-a", "Simulator"], echoPattern: false)
        
        // Give the simulator app time to register the device if it just booted
        Thread.sleep(forTimeInterval: 5.0)
        
        print("📦 Installing \(appPath) to simulator (\(simTargetUDID))...")
        _ = try Shell.run("xcrun", arguments: ["simctl", "install", simTargetUDID, appPath], echoPattern: false)
        
        print("🏃‍♂️ Launching \(bundleIdentifier)...")
        _ = try Shell.run("xcrun", arguments: ["simctl", "launch", simTargetUDID, bundleIdentifier], echoPattern: false)
        
        print("✅ App launched successfully!")
        
        // Open Simulator app
        _ = try Shell.run("open", arguments: ["-a", "Simulator"], echoPattern: false)
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
    
    private func isCommandAvailable(_ tool: String) throws -> Bool {
        do {
            _ = try Shell.capture("which", arguments: [tool], echoPattern: false)
            return true
        } catch {
            return false
        }
    }
    
    private func extractSetting(from output: String, key: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains(" \(key) = ") {
                let parts = line.components(separatedBy: "=")
                if parts.count == 2 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }
}
