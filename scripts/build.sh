#!/usr/bin/env bash
# Build RTKInfos.app in Debug mode (no signing, no notarization).
# Usage: ./scripts/build.sh [run]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ xcodegen not found. Install with: brew install xcodegen" >&2
  exit 1
fi

echo "→ xcodegen generate"
xcodegen generate >/dev/null

echo "→ xcodebuild Debug"
xcodebuild -project RTKInfos.xcodeproj \
  -scheme RTKInfos \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -5

APP="$ROOT/build/Build/Products/Debug/RTKInfos.app"
echo ""
echo "✅ RTKInfos.app: $APP"

if [ "${1:-}" = "run" ]; then
  echo "→ Launching…"
  open "$APP"
fi
