---
name: xcbuddy
description: Build, test, run, and clean Xcode projects using xcbuddy CLI instead of raw xcodebuild. Use this skill whenever the user asks to compile, test, run, or manage iOS simulators.
---

# xcbuddy — The Missing CLI for Xcode

`xcbuddy` is a lightweight Swift CLI wrapper around `xcodebuild` that provides auto-detection, fuzzy simulator matching, isolated caching, and beautified output via `xcbeautify`. **Always prefer `xcbuddy` over raw `xcodebuild` or `xcrun simctl`.**

## Pre-flight Check

Before using `xcbuddy`, verify it is installed:
```bash
which xcbuddy || echo "xcbuddy not found"
```

If not found, install from source:
```bash
cd ~/xcbuddy && chmod +x install.sh && ./install.sh
```

Ensure `~/.local/bin` is in `$PATH`.

## Core Rules

1. **NEVER** use raw `xcodebuild build`, `xcodebuild test`, or `xcrun simctl` directly. Always use `xcbuddy`.
2. **NEVER** pass `-workspace`, `-project`, or `-scheme` arguments. `xcbuddy` auto-detects them.
3. **NEVER** pass long destination strings like `platform=iOS Simulator,name=iPhone 17 Pro`. Use fuzzy names like `-d "17 pro"`.
4. **NEVER** pass `-derivedDataPath`, `-clonedSourcePackagesDirPath`, or `-packageCachePath`. `xcbuddy` auto-injects them when it detects an isolated environment (`.derived-data/` or `.spm-clones/` in `$PWD`).

## Commands Reference

### Build
```bash
# Build with auto-detected scheme and default simulator
xcbuddy build

# Build targeting a specific simulator (fuzzy matched)
xcbuddy build -d "17 pro"

# Build with explicit isolated caching
xcbuddy build --isolated
```

### Test
```bash
# Run all tests
xcbuddy test -d "17 pro"

# Run a specific test class (format: TestTargetName/TestClassName)
xcbuddy test --only "MyAppTests/LoginTests" -d "17 pro"

# Run a specific test method
xcbuddy test --only "MyAppTests/LoginTests/testLoginSuccess" -d "17 pro"

# Run tests with code coverage report
xcbuddy test --coverage -d "17 pro"
```

> **CRITICAL**: The `--only` flag requires `TestTargetName/TestClassName` format — NOT file paths.
> Example: `--only "LionParcelLogisticsINTLTests/EditProfileFeatureTests"`, NOT `--only "Tests/Account/EditProfileFeatureTests.swift"`.

### Run (Build & Launch)
```bash
# Build and run on the currently booted simulator
xcbuddy run

# Build and run on a specific simulator
xcbuddy run -d "16 Pro"
```

### Clean
```bash
# Standard Xcode clean
xcbuddy clean

# Deep clean — deletes project-specific DerivedData folder
xcbuddy clean --deep

# Deep clean in isolated environment — deletes .derived-data/, .spm-clones/, .spm-cache/
xcbuddy clean --deep --isolated
```

### Simulator Management
```bash
# List available simulators
xcbuddy sim list

# Boot a simulator by fuzzy name
xcbuddy sim boot "17 Pro"
```

### Logs
```bash
# Stream all console logs from the booted simulator
xcbuddy logs

# Stream logs filtered by process name
xcbuddy logs -p "MyApp"
```

### Project Utilities
```bash
# Open project in Xcode
xcbuddy open

# Open project's DerivedData in Finder
xcbuddy open --derived-data

# Print project targets, schemes, and configurations
xcbuddy info

# SPM shortcuts
xcbuddy spm resolve
xcbuddy spm update
xcbuddy spm clean

# Lint and format
xcbuddy lint
xcbuddy format
```

### Interactive Dashboard
```bash
# Launch the terminal UI dashboard (for human developers, not agents)
xcbuddy i
```

## Isolated Caching (Auto-detected)

When `xcbuddy` detects `.derived-data/` or `.spm-clones/` directories in `$PWD`, it **automatically** injects:
- `-clonedSourcePackagesDirPath $PWD/.spm-clones`
- `-packageCachePath $PWD/.spm-cache`
- `-derivedDataPath $PWD/.derived-data`
- `-disableAutomaticPackageResolution`
- `-onlyUsePackageVersionsFromResolvedFile`
- `-skipPackageUpdates`

This keeps all caches project-local and avoids polluting the global Xcode DerivedData. You will see `✨ Auto-detected Isolated Cache Environment!` in the output when this is active.

## Error Output

On failure, `xcbuddy` prints a structured error block:
```
❌ ERROR: Testing Failed (Status 65)

🚨 ====== FAILURE DETAILS ======
<xcbeautify-filtered output showing only errors/warnings/test failures>
```

This output is already filtered by `xcbeautify --quiet` to show only actionable information. Parse it to identify the failing test name, file, and line number.
