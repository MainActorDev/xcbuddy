import Foundation

/// Parses xcodebuild failure output into a rich, actionable summary.
///
/// Extracts the FIRST compiler error (file:line:col), classifies the failure,
/// and produces actionable hints — so agents and humans see "what broke and
/// what to do" instead of a 400-line raw dump.
enum BuildFailureAnalyzer {

    struct Finding: CustomStringConvertible {
        let message: String          // one-line, de-noised
        let file: String?            // file path as printed by xcodebuild
        let line: Int?
        let column: Int?
        let category: Category
        let context: [String]        // surrounding lines from the error site

        enum Category: String {
            case compileSwift
            case compileOther        // ObjC / C / headers
            case linkError
            case codeSign
            case packageResolution   // SPM resolve / pinning
            case destination         // no matching simulator / device
            case scheme              // scheme/workspace/project errors
            case testFailure
            case unknown
        }

        var description: String { message }
    }

    // MARK: - Public API

    /// Analyze raw xcodebuild output (stdout, possibly xcbeautify-formatted).
    static func analyze(_ rawOutput: String, isTestRun: Bool = false) -> Finding {
        let lines = rawOutput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        // 1) Destination errors are printed BEFORE any compile output — check first.
        if let f = matchDestinationError(lines) { return f }

        // 2) Package resolution failures (hang, resolve, pinned-version mismatches)
        if let f = matchPackageErrors(lines) { return f }

        // 3) Scheme / project loading errors
        if let f = matchSchemeErrors(lines) { return f }

        // 4) The first "error:" line wins — xcodebuild aborts compile there.
        if let f = firstErrorLine(lines, isTestRun: isTestRun) { return f }

        // 5) Linker failures ("Undefined symbols") — no "error:" prefix line
        if let f = matchLinkerError(lines) { return f }

        // 6) Code signing
        if let f = matchCodeSignError(lines) { return f }

        return Finding(
            message: firstMeaningfulLine(lines) ?? "Unknown failure — see raw log",
            file: nil, line: nil, column: nil,
            category: .unknown,
            context: Array(lines.suffix(12))
        )
    }

    /// Actionable next-step hints for a finding.
    static func hints(for finding: Finding) -> [String] {
        switch finding.category {
        case .compileSwift:
            var h = ["Open \(finding.file ?? "the file") at line \(finding.line ?? 0) — fix the compile error, rebuild."]
            if finding.message.contains("cannot find") {
                h.append("Symbol not found: check spelling, import, and target membership (is the file registered in the correct target?)")
            }
            if finding.message.contains("has no member") || finding.message.contains("value of type") {
                h.append("API mismatch: check the type's actual declaration (grep the repo) — stale build caches can also surface phantom members; if symbols were JUST added, clean once.")
            }
            return h
        case .compileOther:
            return ["Header/ObjC issue at \(finding.file ?? "?"):\(finding.line ?? 0) — check imports and bridging headers."]
        case .linkError:
            var h = ["Undefined symbol — verify the defining target/framework is linked and the symbol is not stripped (OTHER_LDFLAGS, exclusions)."]
            if finding.message.contains("type metadata") || finding.message.contains("conformance") {
                h.append("Swift runtime metadata error often means a protocol conformance is @objc-only or a generic specialization crossed a framework boundary — add the conformance to the framework, not the app.")
            }
            return h
        case .codeSign:
            return ["Signing failed — check signing identity/provisioning; for local sim builds, signing is usually not required: disable or set automatic signing."]
        case .packageResolution:
            return ["SPM resolution failed — run `xcbuddy spm resolve` (or `xcodebuild -resolvePackageDependencies`) once, then retry; if pinned versions conflict, update Package.resolved deliberately, never mid-build."]
        case .destination:
            return ["No matching destination — list simulators (`xcrun simctl list devices available`) and pass an existing name via --destination."]
        case .scheme:
            return ["Scheme/workspace error — verify -workspace/-project flags and scheme name (`xcodebuild -list` shows valid ones)."]
        case .testFailure:
            return ["Test failure at \(finding.file ?? "?"):\(finding.line ?? 0) — open the xcresult bundle or rerun with filtering (`xcbuddy test --filter <name>`) to isolate."]
        case .unknown:
            return ["No structured error found — inspect the raw log tail below."]
        }
    }

    // MARK: - Matchers

    private static let fileLinePrefix = try! NSRegularExpression(
        pattern: #"^(/[^:]+|\S+\.(?:swift|m|mm|c|cpp|h|hpp)):(\d+):(\d+):?\s*(?:fatal\s+)?error:\s*(.+)$"#
    )

    /// A line is an ERROR line only when "error:" is a structural token:
    ///   - `error:` / `fatal error:` appears AFTER a file:line:col prefix, OR
    ///   - the line STARTS with "error:" (xcodebuild's own diagnostics)
    /// Substring matches inside diagnostics (e.g. deprecation warnings whose
    /// message contains "...error:" or "Error:") must NOT count — warnings can
    /// never satisfy either shape.
    private static func isErrorMessage(_ message: String) -> Bool {
        return message.hasPrefix("error:") || message.hasPrefix("error ")
    }

    private static func firstErrorLine(_ lines: [String], isTestRun: Bool) -> Finding? {
        for (idx, line) in lines.enumerated() {
            // Strip xcbeautify decorations (icons, "❌", timing prefixes)
            let cleaned = line
                .replacingOccurrences(of: "❌ ", with: "")
                .trimmingCharacters(in: .whitespaces)

            // Shape 1: file:line:col: error: msg — the structural prefix match
            if let f = matchFileLine(cleaned, fallbackIndex: idx, isTestRun: isTestRun, all: lines) {
                return f
            }

            // Shape 2: line starts with "error:" — xcodebuild/tool diagnostics
            // (e.g. "error: the dependencies were not resolved..."). Note the
            // message-body check must not substring-match.
            if isErrorMessage(cleaned.lowercased()) {
                return Finding(
                    message: cleaned,
                    file: nil, line: nil, column: nil,
                    category: .unknown,
                    context: Array(lines.dropFirst(idx).prefix(8))
                )
            }
        }
        return nil
    }

    private static func matchFileLine(_ cleaned: String, fallbackIndex idx: Int, isTestRun: Bool, all lines: [String]) -> Finding? {
        let ns = cleaned as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = fileLinePrefix.firstMatch(in: cleaned, options: [], range: range) else { return nil }

        let file = ns.substring(with: m.range(at: 1))
        let lineNo = Int(ns.substring(with: m.range(at: 2)))
        let col = Int(ns.substring(with: m.range(at: 3)))
        let msg = ns.substring(with: m.range(at: 4))

        // test failures report as "error: -[Class test] failed" or XCTest failure blocks
        let category: Finding.Category = {
            if isTestRun && (msg.contains("failed") || file.hasSuffix("swift")) && msg.contains("XCT") {
                return .testFailure
            }
            if file.hasSuffix(".swift") { return .compileSwift }
            return .compileOther
        }()

        // context: a few lines around the error site (notes, caret diagnostics)
        let contextStart = max(0, idx - 1)
        let contextEnd = min(lines.count, idx + 7)
        var ctx = Array(lines[contextStart..<contextEnd])
        // Prefer the xcodebuild caret/notes block when present (subsequent "^~~~" lines)
        if !ctx.contains(where: { $0.contains("^") }) {
            let lookahead = lines.dropFirst(idx + 1).prefix(6).filter { $0.contains("^") || $0.contains("note:") }
            if !lookahead.isEmpty { ctx += lookahead }
        }

        return Finding(message: msg, file: file, line: lineNo, column: col, category: category, context: ctx)
    }

    private static func matchLinkerError(_ lines: [String]) -> Finding? {
        guard let idx = lines.firstIndex(where: { $0.contains("Undefined symbols") || $0.contains("ld: error") || $0.contains("Undefined symbol") }) else { return nil }
        return Finding(
            message: lines[idx],
            file: nil, line: nil, column: nil,
            category: .linkError,
            context: Array(lines.dropFirst(idx).prefix(10))
        )
    }

    private static func matchCodeSignError(_ lines: [String]) -> Finding? {
        guard let idx = lines.firstIndex(where: {
            $0.contains("CodeSign") && ($0.contains("error") || $0.contains("failed"))
                || $0.contains("errSecInternalComponent")
                || $0.contains("No signing certificate")
                || $0.contains("requires a provisioning profile")
        }) else { return nil }
        return Finding(
            message: lines[idx].trimmingCharacters(in: .whitespaces),
            file: nil, line: nil, column: nil,
            category: .codeSign,
            context: Array(lines.dropFirst(idx).prefix(6))
        )
    }

    private static func matchPackageErrors(_ lines: [String]) -> Finding? {
        let triggers = [
            "because they are required to be pinned",
            "dependencies were not resolved",
            "resolvePackageDependencies",
            "wait for remote source packages",
            "requested dependency contains an unsupported version",
        ]
        guard let idx = lines.firstIndex(where: { l in triggers.contains(where: { l.contains($0) }) }) else { return nil }
        return Finding(
            message: lines[idx].trimmingCharacters(in: .whitespaces),
            file: nil, line: nil, column: nil,
            category: .packageResolution,
            context: Array(lines.dropFirst(idx).prefix(6))
        )
        }

    private static func matchDestinationError(_ lines: [String]) -> Finding? {
        let triggers = [
            "Unable to find a destination",
            "no destination matching",
            "Ineligible destinations",
            "Available destinations",
        ]
        guard let idx = lines.firstIndex(where: { l in triggers.contains(where: { l.contains($0) }) }) else { return nil }
        return Finding(
            message: lines[idx].trimmingCharacters(in: .whitespaces),
            file: nil, line: nil, column: nil,
            category: .destination,
            context: Array(lines.dropFirst(idx).prefix(10))
        )
    }

    private static func matchSchemeErrors(_ lines: [String]) -> Finding? {
        let triggers = [
            "does not contain a scheme named",
            "no scheme matching",
            "workspace does not contain",
            "Requested schemes do not exist",
        ]
        guard let idx = lines.firstIndex(where: { l in triggers.contains(where: { l.contains($0) }) }) else { return nil }
        return Finding(
            message: lines[idx].trimmingCharacters(in: .whitespaces),
            file: nil, line: nil, column: nil,
            category: .scheme,
            context: Array(lines.dropFirst(idx).prefix(6))
        )
    }

    private static func firstMeaningfulLine(_ lines: [String]) -> String? {
        lines.reversed()
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("**") }
    }
}
