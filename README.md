# RTKInfos

A native macOS app that visualizes token savings from [rtk](https://github.com/rtk-ai/rtk) — a CLI proxy that reduces Claude API token consumption by 60–90%.

## Features

- **Compression gauge** — the signature view: raw `input` compressed down to `output`, with the reclaimed ("killed") tokens highlighted in emerald
- **Volume-weighted savings rate** — accurate all-time and per-period efficiency (`SUM(saved) / SUM(input)`), not a misleading average of percentages
- **Real-time monitoring** — watches `history.db` via FSEvents with polling fallback
- **Live Trace** — streaming side panel of the latest commands, newest first
- **7-day chart** — daily savings, color-encoded by intensity (no traffic-light coloring)
- **By Command** — top commands ranked by tokens saved, with native impact bars
- **Status alerts** — detects missing rtk install or inactivity > 7 days
- **Preferences** — launch at login, polling interval, custom DB path
- **Auto-update** — Sparkle background updates, prompts before installing

## Requirements

- macOS 14+ (Sonoma)
- [rtk](https://github.com/rtk-ai/rtk) installed and configured

## Installation

Download the latest `.dmg` from [Releases](../../releases), mount it, and drag **RTKInfos.app** to `/Applications`.

> The app must be installed in `/Applications` to enable the "Launch at Login" feature.

## Development

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the full development guide.

### Quick start

```bash
# Resolve Swift Package Manager dependencies
swift package resolve

# Generate the Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Or build directly with SPM
swift build
```

> **Note**: `.xcodeproj` is not committed to version control. Regenerate it locally with
> `xcodegen generate` after each clone. `project.yml` is the source of truth for Xcode
> configuration.

### Running tests

```bash
swift test
```

## Architecture

```
AppDelegate
    └── StatsModel (@Observable, @MainActor)
            ├── DBWatcher  ──── FSEvents + Timer ──── history.db
            └── TrackingRepository ─────────────────── history.db (read-only)

SwiftUI Views
    ├── DashboardView     ←── StatsModel.snapshot
    │     ├── CompressionGauge   (signature element)
    │     └── CommandTraceView   (Live Trace panel)
    ├── SettingsView      ←── @AppStorage (UserDefaults)
    └── DesignSystem/RTKTheme   (color tokens, Geist fonts, intensity scale)
```

| Component | Role |
|-----------|------|
| `AppDelegate` | App lifecycle, initializes `StatsModel` from `UserDefaults`, registers fonts |
| `StatsModel` | Observable source of truth, drives all UI updates |
| `DBWatcher` | Watches `history.db` via FSEvents + polling fallback, emits `AsyncStream<Void>` |
| `TrackingRepository` | Read-only SQLite access to rtk's database (volume-weighted aggregates) |
| `DashboardView` | Main window: compression gauge, saved hero, 7-day chart, By Command |
| `CompressionGauge` | Signature view — animated input→output compression bar |
| `CommandTraceView` | Live Trace side panel — streaming recent commands |
| `RTKTheme` | Design system: emerald color tokens, Geist fonts, intensity scale |
| `SettingsView` | Preferences: launch at login, polling interval, DB path |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for a detailed breakdown.

## Distribution

See [docs/RELEASE.md](docs/RELEASE.md) for the full release and notarization process.

## License

[MIT](LICENSE)
