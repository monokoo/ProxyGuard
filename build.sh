#!/bin/bash
set -e

APP_NAME="ProxyGuard"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "Building ${APP_NAME} (release)..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"
cp "Sources/ProxyGuard/Resources/Info.plist" "${CONTENTS}/Info.plist"

# Copy SPM resource bundle if exists
if [ -d "${BUILD_DIR}/ProxyGuard_ProxyGuard.bundle" ]; then
    cp -r "${BUILD_DIR}/ProxyGuard_ProxyGuard.bundle" "${RESOURCES}/"
fi

# Copy app icon
if [ -f "Sources/ProxyGuard/Resources/AppIcon.icns" ]; then
    cp "Sources/ProxyGuard/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"
fi

echo "App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "To run:"
echo "  open ${APP_BUNDLE}"
