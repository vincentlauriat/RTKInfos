#!/bin/bash
set -e

# RTKMenuBar - Build Release Script
# Usage: ./scripts/build-release.sh [VERSION]

VERSION="${1:-1.0.0}"
APP_NAME="RTKMenuBar"
BUNDLE_ID="app.rtk-ai.RTKMenuBar"

echo "=== RTKMenuBar v$VERSION Release Build ==="
echo ""
echo "Prérequis :"
echo "  1. Xcode installé avec compte Developer ID"
echo "  2. xcrun notarytool store-credentials configuré (voir README)"
echo "  3. create-dmg installé (brew install create-dmg)"
echo ""

# Générer le projet Xcode
if command -v xcodegen &> /dev/null; then
    echo "[1/5] Génération du projet Xcode..."
    xcodegen generate
else
    echo "⚠️  xcodegen non trouvé. Installer: brew install xcodegen"
    exit 1
fi

echo ""
echo "[2/5] Build Archive..."
echo "→ Ouvre Xcode, Product → Archive → Distribute App → Direct Distribution → Export"
echo "  OU utilise : xcodebuild archive -scheme RTKMenuBar -archivePath RTKMenuBar.xcarchive"
echo ""

echo "[3/5] Notarisation..."
echo "→ xcrun notarytool submit RTKMenuBar.dmg --keychain-profile AC_PASSWORD --wait"
echo "→ xcrun stapler staple RTKMenuBar.dmg"
echo ""

echo "[4/5] Tag release..."
echo "→ git tag v$VERSION && git push origin main --tags"
echo ""

echo "=== Build script terminé ==="
echo "⚠️  Les étapes 2-4 nécessitent des credentials Apple Developer."
