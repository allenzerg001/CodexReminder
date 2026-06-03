#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP_BUNDLE="${1:-"$ROOT_DIR/build/CodexReminder.app"}"
PROJECT_FILE="$ROOT_DIR/CodexReminder.xcodeproj/project.pbxproj"
SCHEME_FILE="$ROOT_DIR/CodexReminder.xcodeproj/xcshareddata/xcschemes/CodexReminder.xcscheme"
SOURCE_PLIST="$ROOT_DIR/Resources/Info.plist"
SOURCE_ICON="$ROOT_DIR/Resources/CodexReminder.icns"
APP_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_ICON="$APP_BUNDLE/Contents/Resources/CodexReminder.icns"
SYSTEM_APP_BUNDLE="/Applications/CodexReminder.app"

fail() {
    printf 'Packaging verification failed: %s\n' "$1" >&2
    exit 1
}

verify_icns() {
    path="$1"
    [ -f "$path" ] || fail "$path is missing"
    file "$path" | grep -q 'Mac OS X icon' || fail "$path is not a valid .icns file"
}

[ -f "$PROJECT_FILE" ] || fail "CodexReminder.xcodeproj/project.pbxproj is missing"
plutil -lint "$PROJECT_FILE" >/dev/null || fail "CodexReminder.xcodeproj/project.pbxproj is not a valid plist"
grep -q 'isa = PBXNativeTarget;' "$PROJECT_FILE" || fail "CodexReminder.xcodeproj does not contain a native Xcode target"
grep -q 'productType = "com.apple.product-type.application";' "$PROJECT_FILE" || fail "CodexReminder.xcodeproj does not contain a macOS application target"

[ -f "$SCHEME_FILE" ] || fail "CodexReminder scheme is missing"
xmllint --noout "$SCHEME_FILE" || fail "CodexReminder scheme is not valid XML"
grep -q 'title = "Install to Applications"' "$SCHEME_FILE" || fail "CodexReminder scheme does not install the app after Xcode build/run"
grep -q '/Applications/${FULL_PRODUCT_NAME}' "$SCHEME_FILE" || fail "CodexReminder scheme does not install into /Applications"
grep -q '<BuildableProductRunnable' "$SCHEME_FILE" || fail "CodexReminder scheme does not run the macOS app target"

source_icon_name="$(plutil -extract CFBundleIconFile raw -o - "$SOURCE_PLIST" 2>/dev/null || true)"
[ "$source_icon_name" = "CodexReminder" ] || fail "Resources/Info.plist does not declare CFBundleIconFile=CodexReminder"

verify_icns "$SOURCE_ICON"

[ -d "$APP_BUNDLE" ] || fail "$APP_BUNDLE is missing"
[ -f "$APP_PLIST" ] || fail "$APP_PLIST is missing"
app_icon_name="$(plutil -extract CFBundleIconFile raw -o - "$APP_PLIST" 2>/dev/null || true)"
[ "$app_icon_name" = "CodexReminder" ] || fail "$APP_PLIST does not declare CFBundleIconFile=CodexReminder"
verify_icns "$APP_ICON"

if [ "$APP_BUNDLE" = "$SYSTEM_APP_BUNDLE" ]; then
    [ -x "$APP_BUNDLE/Contents/MacOS/CodexReminder" ] || fail "$APP_BUNDLE/Contents/MacOS/CodexReminder is not executable"
    [ -x "$APP_BUNDLE/Contents/MacOS/CodexReminderHook" ] || fail "$APP_BUNDLE/Contents/MacOS/CodexReminderHook is not executable"
fi

printf 'Packaging verification passed for %s\n' "$APP_BUNDLE"
