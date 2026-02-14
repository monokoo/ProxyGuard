#!/bin/bash
set -e

# Define variables
APP_NAME="ProxyGuard"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
INSTALL_DIR="/Applications"

echo "🛑 正在关闭旧版 ${APP_NAME}..."
pkill -x "${APP_NAME}" || true

echo "🔨 正在构建 Release 版本..."
swift build -c release

echo "📦 正在组装 App Bundle..."
# Clean up previous build artifact
rm -rf "${APP_BUNDLE}"

# Create Structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy Files
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Sources/${APP_NAME}/Resources/Info.plist" "${APP_BUNDLE}/Contents/"
cp "Sources/${APP_NAME}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"

echo "🚀 正在安装到 ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR:?}/${APP_BUNDLE:?}"
mv "${APP_BUNDLE}" "${INSTALL_DIR}/"

echo "✨ 正在启动 ${APP_NAME}..."
open "${INSTALL_DIR}/${APP_BUNDLE}"

echo "✅ 部署完成！"
