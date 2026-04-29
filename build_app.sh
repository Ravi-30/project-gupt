#!/bin/bash
set -euo pipefail

APP_NAME="GUPT"
EXECUTABLE_NAME="RemoteDesktop"
BUILD_CONFIGURATION="release"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_DIR=".build"
APP_BUNDLE="${APP_NAME}.app"

echo "🧹 Cleaning up old builds..."
rm -rf "${APP_BUNDLE}" "${BUILD_DIR}"

echo "🔨 Building ${APP_NAME} (Native ${BUILD_CONFIGURATION})..."
swift build -c "${BUILD_CONFIGURATION}"

echo "📦 Packaging into ${APP_BUNDLE}..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"

cp "${BUILD_DIR}/apple/Products/Release/${EXECUTABLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat <<EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.gupt</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>${APP_NAME} requires screen capture access to stream your desktop to clients.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>${APP_NAME} requires accessibility access to control your mouse and keyboard remotely.</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <integer>0</integer>
</dict>
</plist>
EOF

echo "🔐 Signing App Bundle with Entitlements..."
codesign --force --deep --sign - --options runtime --entitlements ./RemoteDesktop.entitlements "${APP_BUNDLE}"

echo "🧹 Resetting TCC Permissions for fresh prompt..."
tccutil reset ScreenCapture com.gupt 2>/dev/null || echo "Note: Could not reset ScreenCapture TCC automatically."
tccutil reset Accessibility com.gupt 2>/dev/null || echo "Note: Could not reset Accessibility TCC automatically."

echo "✅ App Signature Verification:"
codesign -d --entitlements - "${APP_BUNDLE}"

echo
echo "✨ Done! Your app is ready at ./${APP_BUNDLE}"
echo "⚠️ IMPORTANT: For production use, prefer a wss:// relay endpoint and verify both Screen Recording and Accessibility permissions after first launch."
