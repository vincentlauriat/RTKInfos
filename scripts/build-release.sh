#!/bin/bash
set -e

# RTKInfos - Build Release Script
# Usage: ./scripts/build-release.sh [VERSION]

VERSION="${1:-1.0.0}"
APP_NAME="RTKInfos"
BUNDLE_ID="app.rtk-ai.RTKInfos"

echo "=== RTKInfos v$VERSION Release Build ==="
echo ""
echo "Prerequisites:"
echo "  1. Xcode installed with a Developer ID account"
echo "  2. xcrun notarytool store-credentials configured (see README)"
echo "  3. create-dmg installed: brew install create-dmg"
echo ""

if command -v xcodegen &> /dev/null; then
    echo "[1/4] Generating Xcode project..."
    xcodegen generate
else
    echo "Error: xcodegen not found. Install with: brew install xcodegen"
    exit 1
fi

echo ""
echo "[2/4] Build Archive..."
echo "  In Xcode: Product → Archive → Distribute App → Direct Distribution → Export"
echo "  Or: xcodebuild archive -scheme RTKInfos -archivePath RTKInfos.xcarchive"
echo ""

echo "[3/4] Notarize and staple..."
echo "  xcrun notarytool submit RTKInfos.dmg --keychain-profile AC_PASSWORD --wait"
echo "  xcrun stapler staple RTKInfos.app"
echo ""

echo "[4/4] Tag release..."
echo "  git tag v$VERSION && git push origin main --tags"
echo ""

echo "=== Steps 2-4 require Apple Developer credentials. ==="
