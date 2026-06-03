# Repository Guidelines

## Project Structure & Module Organization

CodexReminder is a macOS Swift app distributed as both a Swift Package and an Xcode project. App UI and platform integration live in `Sources/CodexReminder/`, with views, monitors, models, utilities, and Touch Bar code grouped by subdirectory. Shared domain logic lives in `Sources/CodexReminderCore/` and should stay UI-independent. The hook executable is in `Sources/CodexReminderHook/`. Tests are under `Tests/CodexReminderTests/` and focus mostly on core behavior plus hook and installation helpers. App resources live in `Resources/`, including `Info.plist`, entitlements, the app icon, and provider SVGs.

## Build, Test, and Development Commands

- `swift build` builds all SwiftPM targets.
- `swift build --product CodexReminder` builds the menu bar app executable.
- `swift build --product CodexReminderHook` builds the hook helper executable.
- `swift test` runs the XCTest suite in `Tests/CodexReminderTests/`.
- `CONFIGURATION=release Scripts/package_app.sh` creates `build/CodexReminder.app` using release binaries.
- `Scripts/verify_packaging.sh build/CodexReminder.app` validates the app bundle, scheme, plist, icon, and packaged executables.

Use Xcode with `CodexReminder.xcodeproj` and the shared `CodexReminder` scheme when testing app lifecycle, menu bar behavior, signing, or `/Applications` installation.

## Coding Style & Naming Conventions

Use Swift 5.9 conventions with 4-space indentation and clear, intention-revealing names. Types use `UpperCamelCase`; methods, properties, enum cases, and local variables use `lowerCamelCase`. Keep pure logic in `CodexReminderCore` where possible, and keep UI-specific code inside `Sources/CodexReminder/`. Prefer small structs/enums and explicit access control for public core APIs.

## Testing Guidelines

Tests use XCTest. Name test files after the unit under test, for example `StateEngineTests.swift` for `StateEngine.swift`. Name test methods with `test...` and describe the behavior being verified, such as `testSnapshotDetectsNewlyWaiting`. Add core tests for parsing, state transitions, monitor configuration, and hook behavior before changing shared logic. Run `swift test` before submitting changes; run packaging verification when resources, project files, or bundle scripts change.

## Commit & Pull Request Guidelines

The current history uses a conventional-style prefix, for example `feat: permission`. Continue with concise messages like `feat: add qoder monitor`, `fix: handle missing hook file`, or `test: cover parser edge case`. Pull requests should include a short behavior summary, test results, linked issues if available, and screenshots or screen recordings for visible menu bar, settings, notification, or Touch Bar changes.

## Security & Configuration Tips

Do not commit build output, DerivedData, user Xcode state, `.DS_Store`, or local agent data; these are already ignored. Keep entitlements and `Resources/Info.plist` changes narrow and verify packaging after any bundle, signing, or resource update.
