# Agentic Coding with xcbuddy

If you are using AI coding assistants (like Antigravity, Cursor, Windsurf, or GitHub Copilot), this file provides the necessary context and rules for using `xcbuddy` effectively.

## Core Rule
When asked to build, run, test, clean an Xcode project, or manage iOS simulators, you MUST use the `xcbuddy` CLI tool instead of raw `xcodebuild` or `xcrun simctl`.

## Recommended Development Flow
When actively developing and testing, the `xcbuddy interactive` command is the preferred mode. It launches a beautiful, boxed UI terminal dashboard with keyboard shortcuts for common tasks, keeping the main terminal output clean.

## Available Commands

1. **interactive**: `xcbuddy i` or `xcbuddy interactive` (Launches the visually stunning visual REPL dashboard).
2. **open**: `xcbuddy open` (opens project in Xcode) or `xcbuddy open --derived-data` (opens DerivedData in Finder).
3. **build**: `xcbuddy build` (uses default scheme) or `xcbuddy build -d "16 Pro"`
4. **run**: `xcbuddy run` (builds and launches app on booted simulator) or `xcbuddy run -d "15 Pro Max"`.
5. **test**: `xcbuddy test`, `xcbuddy test --only "MyAppTests/LoginTests"`, or `xcbuddy test --coverage` (generates coverage report).
6. **clean**: `xcbuddy clean` (standard clean) or `xcbuddy clean --deep` (automatically finds and deletes the specific derived data folder hash for the project).
7. **sim list**: `xcbuddy sim list` (formatted list of available simulators).
8. **sim boot**: `xcbuddy sim boot "14"` (fuzzy matches and boots a simulator).
9. **logs**: `xcbuddy logs` (streams console output from the booted OS).
10. **info**: `xcbuddy info` (displays project targets, schemes, and configurations).
11. **lint/format**: `xcbuddy lint` or `xcbuddy format` (wrappers for formatting Swift code).
12. **spm**: `xcbuddy spm update`, `xcbuddy spm resolve`, `xcbuddy spm clean` (Swift Package Manager integrations).

## Important Implementation Notes
- **Auto-detection**: DO NOT use `-workspace` or `-project` arguments. `xcbuddy` automatically detects `.xcworkspace`, `.xcodeproj`, and `Package.swift`.
- **Fuzzy Matching**: DO NOT use long destinations like `-destination "platform=iOS Simulator,name=iPhone 16 Pro"`. Use the `-d` or `--destination` flag with simple names (e.g., `-d "16 Pro"`).
