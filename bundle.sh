#!/bin/bash
set -e

echo "Building Tabby (Release)..."
swift build -c release

APP_NAME="Tabby"
TEMP_BUNDLE=".build/$APP_NAME.app"
DEST_APP="/Applications/$APP_NAME.app"
MACOS_DIR="$TEMP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$TEMP_BUNDLE/Contents/Resources"

echo "Assembling $APP_NAME.app..."
rm -rf "$TEMP_BUNDLE" "$APP_NAME.app"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

cat <<EOF > "$TEMP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.dinhbinh.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development:" | head -n 1 | awk -F '"' '{print $2}')
if [ -n "$IDENTITY" ]; then
    echo "Signing with Apple Developer certificate: $IDENTITY..."
    codesign --force --deep --sign "$IDENTITY" "$TEMP_BUNDLE"
else
    echo "Signing with ad-hoc signature..."
    codesign --force --deep --sign - --identifier "com.dinhbinh.$APP_NAME" "$TEMP_BUNDLE"
fi

echo "Installing to $DEST_APP..."
killall "$APP_NAME" 2>/dev/null || true
sleep 0.3
rm -rf "$DEST_APP"
cp -R "$TEMP_BUNDLE" "$DEST_APP"

echo "Installed successfully to $DEST_APP"
open "$DEST_APP"
