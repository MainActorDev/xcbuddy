import ArgumentParser
import Foundation

/// Shared failure reporting for build/test commands: spotlight, hints,
/// context, raw log persistence, and a machine-readable envelope.
enum FailureReporter {

    struct Envelope: Encodable {
        let success: Bool
        let durationSeconds: Double
        let status: Int32
        let firstError: String
        let file: String?
        let line: Int?
        let column: Int?
        let category: String
        let hints: [String]
        let context: [String]
        let logPath: String?
    }

    /// Persist the raw output next to the project's caches for post-mortem.
    @discardableResult
    static func saveRawLog(_ output: String, kind: String) -> String? {
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".xcbuddy-logs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let url = dir.appendingPathComponent("\(kind)-\(stamp).log")
            try output.write(to: url, atomically: true, encoding: .utf8)
            return url.path
        } catch {
            return nil
        }
    }

    /// Print the human failure block and (optionally) the JSON envelope.
    /// Returns the envelope so callers can emit --json after the block.
    static func report(
        kind: String,
        status: Int32,
        output: String,
        systemError: String,
        elapsed: TimeInterval,
        isTestRun: Bool = false,
        json: Bool = false
    ) -> Envelope {
        let combined = output.isEmpty ? systemError : (systemError.isEmpty ? output : output + "\n" + systemError)
        let finding = BuildFailureAnalyzer.analyze(combined, isTestRun: isTestRun)
        let hints = BuildFailureAnalyzer.hints(for: finding)
        let logPath = saveRawLog(combined, kind: kind)

        TerminalUI.printError("\(kind.capitalized) Failed (Status \(status)) after \(TerminalUI.formatDuration(elapsed))")

        print("\n🚨 ====== FAILURE SPOTLIGHT ======")
        print("  ▸ \(finding.message)")
        if let file = finding.file {
            print("  ▸ at \(file):\(finding.line ?? 0):\(finding.column ?? 0)")
        }
        print("  ▸ category: \(finding.category.rawValue)")

        print("\n💡 ====== NEXT STEPS ======")
        for (i, hint) in hints.enumerated() {
            print("  \(i + 1). \(hint)")
        }

        if !finding.context.isEmpty {
            print("\n🧾 ====== CONTEXT (error site) ======")
            for line in finding.context.prefix(10) {
                print("  | \(line)")
            }
        }

        if let logPath {
            print("\n📄 raw log saved: \(logPath)")
        }

        let envelope = Envelope(
            success: false,
            durationSeconds: elapsed,
            status: status,
            firstError: finding.message,
            file: finding.file,
            line: finding.line,
            column: finding.column,
            category: finding.category.rawValue,
            hints: hints,
            context: Array(finding.context.prefix(10)),
            logPath: logPath
        )

        if json {
            if let data = try? JSONEncoder().encode(envelope),
               let str = String(data: data, encoding: .utf8) {
                print("\n" + str)
            }
        }
        return envelope
    }
}
