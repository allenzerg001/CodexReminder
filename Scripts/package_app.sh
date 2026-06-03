#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_BUNDLE="${1:-"$ROOT_DIR/build/CodexReminder.app"}"

case "$CONFIGURATION" in
    Debug|debug)
        SWIFT_CONFIGURATION="debug"
        ;;
    Release|release)
        SWIFT_CONFIGURATION="release"
        ;;
    *)
        SWIFT_CONFIGURATION="debug"
        ;;
esac

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
export SWIFTPM_CACHE_PATH="$ROOT_DIR/.build/swiftpm-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_CACHE_PATH"

if [ "$SWIFT_CONFIGURATION" = "release" ]; then
    swift build --package-path "$ROOT_DIR" -c release --product CodexReminder
    swift build --package-path "$ROOT_DIR" -c release --product CodexReminderHook
else
    swift build --package-path "$ROOT_DIR" --product CodexReminder
    swift build --package-path "$ROOT_DIR" --product CodexReminderHook
fi

BIN_DIR="$ROOT_DIR/.build/$SWIFT_CONFIGURATION"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

case "$APP_BUNDLE" in
    *.app)
        ;;
    *)
        printf 'Refusing to package into non-.app path: %s\n' "$APP_BUNDLE" >&2
        exit 1
        ;;
esac

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/CodexReminder" "$MACOS_DIR/CodexReminder"
cp "$BIN_DIR/CodexReminderHook" "$MACOS_DIR/CodexReminderHook"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/CodexReminder.icns" "$RESOURCES_DIR/CodexReminder.icns"
cp "$ROOT_DIR/Resources/touch_bar.png" "$RESOURCES_DIR/touch_bar.png"
cp -R "$ROOT_DIR/Resources/ProviderIcons" "$RESOURCES_DIR/ProviderIcons"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

printf 'Packaged %s\n' "$APP_BUNDLE"
