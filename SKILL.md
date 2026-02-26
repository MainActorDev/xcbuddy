# Agentic Coding with xcbuddy

If you are using AI coding assistants (like Antigravity, Cursor, Windsurf, or GitHub Copilot), this file provides the necessary context and rules for using `xcbuddy` effectively.

## Core Rule
When asked to build, run, test, clean an Xcode project, or manage iOS simulators, you MUST use the `xcbuddy` CLI tool instead of raw `xcodebuild` or `xcrun simctl`.

## Recommended Development Flow
When actively developing and testing, the `xcbuddy interactive` command is the preferred mode. It launches a beautiful, boxed UI terminal dashboard with keyboard shortcuts for common tasks, keeping the main terminal output clean.

## Available Commands

1. **interactive**: `xcbuddy interactive` (Launches the visually stunning visual REPL dashboard).
2. **build**: `xcbuddy build` (uses default scheme) or `xcbuddy build -d "16 Pro"`
3. **run**: `xcbuddy run` (builds and launches app on booted simulator) or `xcbuddy run -d "15 Pro Max"`.
4. **test**: `xcbuddy test` or `xcbuddy test --only "MyAppTests/LoginTests"`
5. **clean**: `xcbuddy clean` (standard clean) or `xcbuddy clean --deep` (automatically finds and deletes the specific derived data folder hash for the project).
6. **sim list**: `xcbuddy sim list` (formatted list of available simulators).
7. **sim boot**: `xcbuddy sim boot "14"` (fuzzy matches and boots a simulator).
8. **logs**: `xcbuddy logs` (streams console output from the booted OS).

## Important Implementation Notes
- **Auto-detection**: DO NOT use `-workspace` or `-project` arguments. `xcbuddy` automatically detects `.xcworkspace`, `.xcodeproj`, and `Package.swift`.
- **Fuzzy Matching**: DO NOT use long destinations like `-destination "platform=iOS Simulator,name=iPhone 16 Pro"`. Use the `-d` or `--destination` flag with simple names (e.g., `-d "16 Pro"`).
