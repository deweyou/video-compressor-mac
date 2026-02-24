#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export SWIFT_MODULECACHE_PATH="$ROOT/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"

APP_NAME="VideoCompressor"
APP_BUNDLE="$ROOT/dist/${APP_NAME}.app"
DMG_ROOT="$ROOT/dist/dmg-root"
DMG_PATH="$ROOT/dist/${APP_NAME}-arm64.dmg"
PRODUCT_BIN="$ROOT/.build/arm64-apple-macosx/release/${APP_NAME}"
RESOURCE_BUNDLE="$ROOT/.build/arm64-apple-macosx/release/${APP_NAME}_${APP_NAME}.bundle"
ICON_FILE="$ROOT/VideoCompressor/Resources/AppIcon.icns"

swift build -c release --build-system native

rm -rf "$APP_BUNDLE" "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$DMG_ROOT"

cp "$PRODUCT_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>VideoCompressor</string>
  <key>CFBundleDisplayName</key>
  <string>VideoCompressor</string>
  <key>CFBundleIdentifier</key>
  <string>com.deweyou.VideoCompressor</string>
  <key>CFBundleVersion</key>
  <string>6</string>
  <key>CFBundleShortVersionString</key>
  <string>1.3.0</string>
  <key>CFBundleExecutable</key>
  <string>VideoCompressor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -sfn /Applications "$DMG_ROOT/Applications"

codesign --force --deep --sign - "$APP_BUNDLE"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"

echo "Built DMG: $DMG_PATH"
