# Release Process

RTKInfos is distributed as a notarized `.dmg` outside the Mac App Store.

## Prerequisites

- Apple Developer account (99 $/year)
- **Developer ID Application** certificate installed in Keychain
- Xcode command-line tools: `xcode-select --install`
- `create-dmg`: `brew install create-dmg`
- Notarization credentials stored:

```bash
xcrun notarytool store-credentials AC_PASSWORD \
  --apple-id your@email.com \
  --team-id XXXXXXXXXX
```

## Automated release

```bash
./scripts/build-release.sh 1.2.0
```

The script performs these steps:

1. **Generate Xcode project** via `xcodegen generate`
2. **Archive** in Xcode: Product → Archive → Distribute App → Direct Distribution
3. **Notarize**: submits the app to Apple's notarization service and waits for approval
4. **Staple**: runs `xcrun stapler staple` to attach the notarization ticket
5. **Package**: wraps the `.app` in a `.dmg` via `create-dmg`
6. **Tag**: creates a git tag `v1.2.0`

## Manual steps (if script fails)

### 1. Generate project and archive

```bash
xcodegen generate
```

Then in Xcode: **Product → Archive**.

### 2. Export for Direct Distribution

In the Organizer window: select the archive → **Distribute App** → **Direct Distribution** → export the `.app`.

### 3. Notarize

```bash
xcrun notarytool submit RTKInfos.zip \
  --keychain-profile AC_PASSWORD \
  --wait
```

### 4. Staple

```bash
xcrun stapler staple RTKInfos.app
```

### 5. Create DMG

```bash
create-dmg \
  --volname "RTKInfos" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "RTKInfos.app" 175 190 \
  --app-drop-link 425 190 \
  "RTKInfos-1.2.0.dmg" \
  "RTKInfos.app"
```

### 6. Tag and push

```bash
git tag v1.2.0
git push origin v1.2.0
```

## Pre-release checklist

- [ ] `swift test` passes (11/11)
- [ ] App launches and detects rtk database
- [ ] Dashboard displays correct KPIs
- [ ] Chart renders 7-day data
- [ ] Refresh button updates stats
- [ ] Settings: launch at login toggles correctly
- [ ] Settings: DB path reset works
- [ ] App survives window close and reopens from Dock
- [ ] Notarization ticket is stapled (Gatekeeper passes)
- [ ] DMG mounts and drag-to-Applications works

## Versioning

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: breaking changes to the rtk database schema compatibility
- **MINOR**: new features (new metrics, chart types, settings)
- **PATCH**: bug fixes, UI tweaks, performance improvements

Update `CFBundleShortVersionString` in `Info.plist` before archiving.
