# CodexReminder

CodexReminder is a macOS menu bar app that watches local AI coding tools and alerts you when they need attention. It detects waiting states for Codex, Claude Code, and Qoder, then surfaces the active item from the menu bar with optional notifications and quick action choices.

## Features

- Menu bar status for AI tool sessions that are waiting for input or approval.
- Support for Codex, Claude Code, and Qoder processes.
- Hook helper for permission request events.
- Provider icons and compact menu row details, including working directory context.
- Swift Package and Xcode project support for local development.

## Requirements

- macOS 13 or newer
- Swift 5.9 or newer
- Xcode for app lifecycle, signing, and scheme-based development

## Build and Test

Build all targets:

```sh
swift build
```

Run tests:

```sh
swift test
```

Build specific products:

```sh
swift build --product CodexReminder
swift build --product CodexReminderHook
```

Package an app bundle:

```sh
Scripts/package_app.sh
```

Package a release build:

```sh
CONFIGURATION=release Scripts/package_app.sh
```

Verify the packaged app:

```sh
Scripts/verify_packaging.sh build/CodexReminder.app
```

## Project Layout

- `Sources/CodexReminder/` - macOS app, menu bar UI, monitors, utilities, and Touch Bar support.
- `Sources/CodexReminderCore/` - shared parsing, state, hook, and tool model logic.
- `Sources/CodexReminderHook/` - hook executable entry point.
- `Tests/CodexReminderTests/` - XCTest coverage for core logic and hook behavior.
- `Resources/` - app plist, entitlements, icons, and provider assets.
- `Scripts/` - packaging, verification, demo, and mock helper scripts.

## Development Notes

Open `CodexReminder.xcodeproj` and use the shared `CodexReminder` scheme when testing the full macOS app. Use SwiftPM commands for fast core and hook iteration.

The app installs hooks for supported tools during launch unless `CODEX_REMINDER_SKIP_HOOK_INSTALL=1` is set.

## License

This project is released under the MIT License. You may use it for personal, open source, and commercial purposes. See [LICENSE](LICENSE) for details.
