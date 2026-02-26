import Foundation

/// A utility to execute shell commands synchronously or asynchronously.
public enum Shell {
    
    public enum ShellError: Error, LocalizedError {
        case executionFailed(status: Int32, output: String, error: String)
        case executableNotFound(String)
        case decodingFailed
        
        public var errorDescription: String? {
            switch self {
            case .executionFailed(let status, _, let error):
                return "Command failed with status \(status). Error: \(error)"
            case .executableNotFound(let name):
                return "Executable '\(name)' not found."
            case .decodingFailed:
                return "Failed to decode command output."
            }
        }
    }
    
    /// Executes a command and pipes the output in real-time to standard out.
    /// Good for commands where the user wants to see the intermediate logs (like xcodebuild).
    @discardableResult
    public static func run(_ command: String, arguments: [String] = [], echoPattern: Bool = true) throws -> Int32 {
        if echoPattern {
            print("> \(command) \(arguments.joined(separator: " "))")
        }
        
        let process = Process()
        process.executableURL = Self.executableURL(for: command)
        process.arguments = arguments
        
        // Pass parent standard I/O directly to the child process
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        
        try process.run()
        process.waitUntilExit()
        
        let status = process.terminationStatus
        guard status == 0 else {
            throw ShellError.executionFailed(status: status, output: "", error: "Failed to execute. Check standard output.")
        }
        
        return status
    }
    
    /// Executes a command and captures its standard output and standard error as strings.
    /// Good for commands where the CLI tool needs to parse the output (like simctl list).
    public static func capture(_ command: String, arguments: [String] = [], echoPattern: Bool = false) throws -> String {
        if echoPattern {
            print("> \(command) \(arguments.joined(separator: " "))")
        }
        
        let process = Process()
        process.executableURL = Self.executableURL(for: command)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
        
        process.waitUntilExit()
        
        let output = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let error = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let status = process.terminationStatus
        guard status == 0 else {
            throw ShellError.executionFailed(status: status, output: output, error: error)
        }
        
        return output
    }
    
    /// Locates the absolute path of an executable.
    private static func executableURL(for command: String) -> URL {
        if command.hasPrefix("/") {
            return URL(fileURLWithPath: command)
        }
        
        // Use bash to 'which' the command, this ensures we find it in the user's PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "which \(command)"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Silence errors
        
        try? process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0,
           let data = try? pipe.fileHandleForReading.readToEnd(),
           let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        
        // Fallback: If we just pass the command name to Process() on newer macOS it often works,
        // or we can fallback to /usr/bin/env. But /usr/bin/env expects arguments passed strangely in Process().
        // For our purpose, if `which` fails, returning a naive file URL will likely throw later, which is fine.
        return URL(fileURLWithPath: "/usr/bin/\(command)") // generic fallback
    }
}
