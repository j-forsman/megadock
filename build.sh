#!/bin/bash
set -e

APP="MegaDock.app"

echo "→ Building release binary..."
swift build -c release

echo "→ Packaging into $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp ".build/release/MegaDock" "$APP/Contents/MacOS/"
chmod +x "$APP/Contents/MacOS/MegaDock"

cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MegaDock</string>
    <key>CFBundleIdentifier</key>
    <string>com.github.yourusername.megadock</string>
    <key>CFBundleName</key>
    <string>MegaDock</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>MegaDock reads notification badges from the system Dock.</string>
</dict>
</plist>
PLIST

echo "→ Signing..."
# C11: use env var so other machines can override; fall through gracefully if no cert found
SIGN_IDENTITY="${MEGADOCK_SIGN_IDENTITY:-638F7EE6F39DA65DC438F2B2FE2553872B189974}"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP" \
    || echo "  (warning: signing skipped — set MEGADOCK_SIGN_IDENTITY or add to Accessibility manually)"

echo "✓ Done. Run with:  open $APP"
