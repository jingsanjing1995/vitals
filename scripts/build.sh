#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="VITALS"
DERIVED="$ROOT/.build/xcode"
BUILT_APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
APP_BUNDLE="$ROOT/dist/$APP_NAME.app"
WIDGET_ENTITLEMENTS="$ROOT/Resources/VITALSWidget.entitlements"

cd "$ROOT"

if [[ ! -d "VITALS.xcodeproj" ]]; then
    echo "▸ Generating Xcode project…"
    xcodegen generate
fi

echo "▸ Building VITALS.app + WidgetKit extension…"
mkdir -p "$DERIVED"
xcodebuild \
    -project VITALS.xcodeproj \
    -scheme VITALS \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build > "$DERIVED/build.log" 2>&1 || {
        echo "Build failed. Last 60 lines:" >&2
        tail -60 "$DERIVED/build.log" >&2
        exit 1
    }

echo "▸ Assembling $APP_BUNDLE…"
rm -rf "$APP_BUNDLE"
mkdir -p "$ROOT/dist"
ditto "$BUILT_APP" "$APP_BUNDLE"

# Local ad-hoc signing: sign the embedded widget extension first, then the app.
codesign --force --sign - --timestamp=none \
    --entitlements "$WIDGET_ENTITLEMENTS" \
    "$APP_BUNDLE/Contents/PlugIns/VITALSWidget.appex" >/dev/null
codesign --force --sign - --timestamp=none "$APP_BUNDLE" >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"

# Make sure PlugInKit and LaunchServices know about this exact copy rather than
# an older build product or a duplicate download.
pluginkit -r "$BUILT_APP/Contents/PlugIns/VITALSWidget.appex" >/dev/null 2>&1 || true
pluginkit -a "$APP_BUNDLE/Contents/PlugIns/VITALSWidget.appex" >/dev/null 2>&1 || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -u "$BUILT_APP" >/dev/null 2>&1 || true
    "$LSREGISTER" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

echo "▸ Built $APP_BUNDLE"
echo "  Widget: com.vitals.desktop.widget"
