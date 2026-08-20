import XCTest
@testable import xcbuddy

final class BuildFailureAnalyzerTests: XCTestCase {

    func testSwiftCompileErrorWithFileLine() {
        let raw = """
        SwiftCompile normal arm64 /Users/x/Dev/App/Sources/Foo.swift
        /Users/x/Dev/App/Sources/Foo.swift:42:9: error: cannot find 'withdrawals' in scope
        note: did you mean 'withdrawal'?
        """
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertEqual(f.category, .compileSwift)
        XCTAssertEqual(f.file, "/Users/x/Dev/App/Sources/Foo.swift")
        XCTAssertEqual(f.line, 42)
        XCTAssertEqual(f.column, 9)
        XCTAssertTrue(f.message.contains("cannot find"))
    }

    func testXcbeautifyDecoratedError() {
        let raw = "❌ /Users/x/Dev/App/Src/Bar.swift:10:3: error: value of type 'WithdrawalViewModel' has no member 'isLoadded'"
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertEqual(f.category, .compileSwift)
        XCTAssertEqual(f.line, 10)
        XCTAssertFalse(f.message.contains("❌"))
    }

    func testPackageResolutionPinned() {
        let raw = """
        error: the dependencies were not resolved because they are required to be pinned
        because the project has an exact-version requirement
        """
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertEqual(f.category, .packageResolution)
    }

    func testDestinationError() {
        let raw = """
        === TARGETS ===
        Unable to find a destination matching the provided destination specifier
        Available destinations:
          { platform:iOS Simulator, id:... }
        """
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertEqual(f.category, .destination)
    }

    func testLinkerUndefinedSymbols() {
        let raw = """
        ld: warning: ignoring duplicate functions
        Undefined symbols for architecture arm64:
          "_swift_slowAlloc", referenced from: ...
        """
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertEqual(f.category, .linkError)
    }

    func testSchemeError() {
        let raw = "xcodebuild: error: .../App.xcworkspace does not contain a scheme named 'Prod'"
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertEqual(f.category, .scheme)
    }

    func testWarningsWithErrorMessageAreNotErrors() {
        // Real shape from ios-consumer build: Pods deprecation warning whose
        // message contains "error:" inside the suggestion text.
        let raw = """
        /path/Pods/Motion/Sources/Extensions/Motion+UIKit.swift:34:30: warning: 'unarchiveObject(with:)' was deprecated in iOS 12.0: Use +unarchivedObjectOfClass:fromData:error: instead
        /path/Sources/App/Screen.swift:39:32: error: cannot find 'undefinedSymbolHere' in scope
        """
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertEqual(f.category, .compileSwift)
        XCTAssertEqual(f.file, "/path/Sources/App/Screen.swift")
        XCTAssertEqual(f.line, 39)
        XCTAssertTrue(f.message.contains("undefinedSymbolHere"))
    }

    func testXcodebuildDiagnosticErrorLine() {
        let raw = """
        note: Building targets in dependency order
        error: the dependencies were not resolved because they are required to be pinned
        """
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertTrue(f.message.hasPrefix("error: the dependencies"))
    }

    func testHintsAreActionable() {
        let raw = "/a/b.swift:1:1: error: cannot find 'Thing' in scope"
        let f = BuildFailureAnalyzer.analyze(raw)
        let h = BuildFailureAnalyzer.hints(for: f)
        XCTAssertTrue(h.contains { $0.contains("target membership") })
    }

    func testUnknownFallbackContext() {
        let raw = "some random crash\n** BUILD FAILED **"
        let f = BuildFailureAnalyzer.analyze(raw)
        XCTAssertEqual(f.category, .unknown)
        XCTAssertFalse(f.context.isEmpty)
    }
}
