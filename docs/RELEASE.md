# Release Process

RTKInfos is distributed as a notarized `.dmg` outside the Mac App Store, with
in-app updates delivered through Sparkle.

## Prerequisites (already set up on this machine)

- **Developer ID Application** certificate in the Keychain:
  `Developer ID Application: Vincent LAURIAT (KFLACS69T9)`
- **Notarization profile** `AppliMacVincentGithub` in the Keychain (shared with
  the MarkdownViewer project). To recreate it:
  ```bash
  xcrun notarytool store-credentials "AppliMacVincentGithub" \
    --apple-id "vincent@lauriat.fr" --team-id "KFLACS69T9"
  ```
- **Sparkle EdDSA signing key** — RTKInfos reuses the MarkdownViewer key
  (Keychain account `MarkdownViewer`; its public half
  `9PD2SBwLL4XoycyAGzaE+gO7ctuxSfuFMMajiZdXhXQ=` is in `Info.plist > SUPublicEDKey`).
  **Never regenerate it** — doing so breaks auto-update for every installed client.
- `xcodegen`: `brew install xcodegen`

## Release steps

1. **Bump the version** in `project.yml`:
   - `MARKETING_VERSION` (e.g. `1.1.0`)
   - `CURRENT_PROJECT_VERSION` — must increase monotonically (integer). Sparkle
     compares this as `sparkle:version`; a non-increasing value silently skips updates.

2. **Update `CHANGES.md`** with the new version section.

3. **Commit, then tag:**
   ```bash
   git add project.yml CHANGES.md
   git commit -m "release: prepare vX.Y.Z"
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push && git push origin vX.Y.Z
   ```

4. **Build, sign, notarize, package** — produces `RTKInfos-X.Y.Z.dmg` and rewrites
   `appcast.xml`:
   ```bash
   SIGNING_IDENTITY="Developer ID Application: Vincent LAURIAT (KFLACS69T9)" \
     ./scripts/build-release.sh X.Y.Z
   ```
   The script cleans `build/`, builds Release (`xcodegen` + `xcodebuild`), stages to
   a clean dir (strips `com.apple.provenance` xattrs), codesigns the Sparkle
   framework + app with Hardened Runtime, builds the DMG via `hdiutil`, notarizes
   through `AppliMacVincentGithub`, staples, and EdDSA-signs the DMG.

5. **Publish the GitHub release:**
   ```bash
   gh release create vX.Y.Z ./RTKInfos-X.Y.Z.dmg --title "vX.Y.Z" --notes "…"
   ```

6. **Commit the refreshed appcast:**
   ```bash
   git add appcast.xml
   git commit -m "release: appcast for vX.Y.Z"
   git push
   ```
   Existing Sparkle clients pick up the update on their next check.

## Notes

- `sparkle:version` in `appcast.xml` is `CFBundleVersion` (a monotonic integer),
  **not** the marketing version.
- The macOS Sequoia `com.apple.provenance` xattr breaks `codesign --force`; the
  script works around it with `CODE_SIGNING_ALLOWED=NO` plus a `ditto` scrub.
- If `notarytool store-credentials` returns HTTP 401 "account does not exist",
  the Apple ID is `vincent@lauriat.fr` (not the gmail address) and the team is
  `KFLACS69T9`.

## Pre-release checklist

- [ ] `swift test` passes
- [ ] `make run-debug` launches; the dashboard shows correct figures
- [ ] Compression gauge, 7-day chart, By Command, Live Trace all render
- [ ] DMG mounts, Gatekeeper passes (stapled), drag-to-Applications works

## Versioning (SemVer)

- **MAJOR** — breaking rtk database schema compatibility
- **MINOR** — new features
- **PATCH** — bug fixes, UI tweaks, performance

Bump both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`
(`Info.plist` references them as `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`).
