#!/bin/bash
set -e

VERSION="1.0.4"
APP_NAME="Tabby"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
BUILD_DIR=".build"
RELEASE_DIR="releases"
DMG_STAGING="/tmp/${APP_NAME}_dmg_staging"

echo "Building ${APP_NAME} Release..."
./bundle.sh

echo "Creating Release DMG staging area..."
rm -rf "${DMG_STAGING}" "${RELEASE_DIR}/${DMG_NAME}"
mkdir -p "${DMG_STAGING}" "${RELEASE_DIR}"

cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DMG_STAGING}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING}/Applications"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${DMG_STAGING}/.VolumeIcon.icns"
fi

echo "Packaging DMG with hdiutil..."
TMP_DMG="/tmp/${APP_NAME}_uncompressed.dmg"
rm -f "${TMP_DMG}"

hdiutil create -ov -fs HFS+ -format UDRW -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" "${TMP_DMG}"

echo "Setting DMG folder view layout..."
MOUNT_DIR="/Volumes/${APP_NAME}"
hdiutil attach "${TMP_DMG}" -mountpoint "${MOUNT_DIR}" -nobrowse -quiet || true

osascript <<EOF || true
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 940, 560}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 128
        set arrangement of viewOptions to not arranged
        set position of item "${APP_NAME}.app" of container window to {140, 180}
        set position of item "Applications" of container window to {400, 180}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

hdiutil detach "${MOUNT_DIR}" -quiet || true

echo "Compressing final DMG..."
hdiutil convert "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${RELEASE_DIR}/${DMG_NAME}"
rm -f "${TMP_DMG}"
rm -rf "${DMG_STAGING}"

echo "DMG Created successfully at: ${RELEASE_DIR}/${DMG_NAME}"
ls -lh "${RELEASE_DIR}/${DMG_NAME}"
