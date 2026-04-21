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
    
    @Flag(name: .customLong("isolated"), help: "Forces isolated caching mode for SPM and DerivedData.")
    var isolated: Bool = false
    
    func run() throws {
        let context = ProjectContext()
        guard context.isValid else {
            TerminalUI.printError("No valid Xcode project found.")
            throw ExitCode.failure
        }
        
        let buildScheme = scheme ?? context.inferredScheme
        TerminalUI.printMainStep("🚀", message: "Preparing \(buildScheme ?? "project") for execution...")
        
        // Find the simulator UDID early so we can build specifically for its architecture
        let finalDestination = SimulatorResolver.resolveDestination(from: destination)
        var simTargetUDID = "booted"
        if finalDestination.contains("id=") {
            simTargetUDID = finalDestination.components(separatedBy: "id=").last ?? "booted"
        }
        
        // 1. Build the project using our BuildCommand logic
        var buildArgs = ["build"]
        
        let isIsolated = context.isIsolatedEnvironment(explicitlyRequested: isolated)
        if isIsolated {
            buildArgs.append(contentsOf: context.xcodebuildCacheArgs)
            TerminalUI.printSubStep("✨ Auto-detected Isolated Cache Environment!")
        }
        
        buildArgs.append(contentsOf: context.xcodebuildTargetArgs)
        if let buildScheme { buildArgs.append(contentsOf: ["-scheme", buildScheme]) }
        buildArgs.append(contentsOf: ["-destination", finalDestination])
        
        TerminalUI.printSubStep("Compiling for \(finalDestination)...")
        let useBeautify = try isCommandAvailable("xcbeautify")
        if useBeautify {
            let fullCommand = "xcodebuild \(buildArgs.joined(separator: " ")) | xcbeautify"
            try Shell.run("bash", arguments: ["-c", fullCommand], echoPattern: false, quiet: true)
        } else {
            try Shell.run("xcodebuild", arguments: buildArgs, quiet: true)
        }
        TerminalUI.completeLastSubStep("Compiling for \(finalDestination)")
        
        // 2. Locate built product
        TerminalUI.printSubStep("Locating build product...")
        var settingsArgs = ["xcodebuild", "-showBuildSettings"]
        if isIsolated { settingsArgs.append(contentsOf: context.xcodebuildCacheArgs) }
        settingsArgs.append(contentsOf: context.xcodebuildTargetArgs)
        if let buildScheme { settingsArgs.append(contentsOf: ["-scheme", buildScheme]) }
        settingsArgs.append(contentsOf: ["-destination", finalDestination])
        
        let settingsOutput = try Shell.capture("xcodebuild", arguments: Array(settingsArgs.dropFirst()), echoPattern: false)
        
        guard let buildDir = extractSetting(from: settingsOutput, key: "TARGET_BUILD_DIR"),
              let productName = extractSetting(from: settingsOutput, key: "FULL_PRODUCT_NAME"),
              let bundleIdentifier = extractSetting(from: settingsOutput, key: "PRODUCT_BUNDLE_IDENTIFIER") else {
            TerminalUI.printError("Could not determine built app path or bundle identifier.\n💡 This usually happens if you are trying to 'run' a framework or library package instead of an application target (e.g. running from the root instead of the Demo/ folder).")
            throw ExitCode.failure
        }
        
        let appPath = URL(fileURLWithPath: buildDir).appendingPathComponent(productName).path
        TerminalUI.completeLastSubStep("Located build product (\(productName))")
        
        // Ensure simulator is booted (ignore error if it's already booted)
        _ = try? Shell.run("xcrun", arguments: ["simctl", "boot", simTargetUDID], echoPattern: false, quiet: true)
        
        TerminalUI.printMainStep("📦", message: "Preparing to launch \(productName) on Simulator...")
        
        // Open Simulator app *before* installing/launching so the UI workspace is ready
        TerminalUI.printSubStep("Waking Simulator UI...")
        _ = try Shell.run("open", arguments: ["-a", "Simulator"], echoPattern: false, quiet: true)
        
        // Give the simulator app time to register the device if it just booted
        Thread.sleep(forTimeInterval: 5.0)
        TerminalUI.completeLastSubStep("Simulator UI ready")
        
        // Embed dynamic SPM frameworks into the app bundle before installing.
        // When launching via simctl (instead of Xcode), the simulator runtime sandboxes
        // DYLD_FRAMEWORK_SEARCH_PATHS, so absolute paths to DerivedData don't resolve.
        // The .debug.dylib already has @executable_path/Frameworks in its rpath,
        // so copying the frameworks there makes them discoverable at runtime.
        TerminalUI.printSubStep("Embedding dynamic frameworks...")
        let appURL = URL(fileURLWithPath: appPath)
        let appFrameworksDir = appURL.appendingPathComponent("Frameworks")
        let buildDirURL = URL(fileURLWithPath: buildDir)
        let fm = FileManager.default
        
        try? fm.createDirectory(at: appFrameworksDir, withIntermediateDirectories: true)
        
        // Scan the build products directory for .framework bundles that are dynamically linked
        if let contents = try? fm.contentsOfDirectory(atPath: buildDir) {
            for item in contents where item.hasSuffix(".framework") {
                let srcFramework = buildDirURL.appendingPathComponent(item)
                let dstFramework = appFrameworksDir.appendingPathComponent(item)
                
                // Check if the binary inside the framework exists
                let binaryName = (item as NSString).deletingPathExtension
                let binaryPath = srcFramework.appendingPathComponent(binaryName).path
                guard fm.fileExists(atPath: binaryPath) else { continue }
                
                // Only embed dynamic frameworks (dylib), not static archives.
                // Static archives will cause simctl install to fail.
                let fileOutput = (try? Shell.capture("file", arguments: [binaryPath], echoPattern: false)) ?? ""
                guard fileOutput.contains("dynamically linked") else { continue }
                
                // Skip if already embedded
                if fm.fileExists(atPath: dstFramework.path) { continue }
                
                try? fm.copyItem(at: srcFramework, to: dstFramework)
            }
        }
        
        // Re-sign the app bundle after embedding (ad-hoc signing for simulator)
        _ = try? Shell.run("codesign", arguments: ["--force", "--sign", "-", "--deep", appPath], echoPattern: false, quiet: true)
        TerminalUI.completeLastSubStep("Embedded dynamic frameworks")
        
        TerminalUI.printSubStep("Installing app to \(simTargetUDID)...")
        _ = try Shell.run("xcrun", arguments: ["simctl", "install", simTargetUDID, appPath], echoPattern: false, quiet: true)
        TerminalUI.completeLastSubStep("App installed")
        
        TerminalUI.printSubStep("Launching \(bundleIdentifier)...")
        _ = try Shell.run("xcrun", arguments: ["simctl", "launch", simTargetUDID, bundleIdentifier], echoPattern: false, quiet: true)
        TerminalUI.completeLastSubStep("App launched")
        
        TerminalUI.printSuccess("App Launched Successfully")
        
        // Open Simulator app
        _ = try Shell.run("open", arguments: ["-a", "Simulator"], echoPattern: false, quiet: true)
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
