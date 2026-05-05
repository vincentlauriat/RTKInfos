# RTKInfos

A native macOS app that visualizes token savings from [rtk](https://github.com/rtk-ai/rtk) — a CLI proxy that reduces Claude API token consumption by 60–90%.

## Features

- **Real-time monitoring** — watches `history.db` via FSEvents with polling fallback
- **Daily KPIs** — tokens saved, command count, average savings %, raw token usage
- **7-day chart** — bar + point chart of daily savings percentage
- **Recent history** — last 5 commands with savings % and relative timestamp
- **Status alerts** — detects missing rtk install or inactivity > 7 days
- **Preferences** — launch at login, polling interval, custom DB path

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
    ├── DashboardView  ←── StatsModel.snapshot
    └── SettingsView   ←── @AppStorage (UserDefaults)
```

| Component | Role |
|-----------|------|
| `AppDelegate` | App lifecycle, initializes `StatsModel` from `UserDefaults` |
| `StatsModel` | Observable source of truth, drives all UI updates |
| `DBWatcher` | Watches `history.db` via FSEvents + polling fallback, emits `AsyncStream<Void>` |
| `TrackingRepository` | Read-only SQLite access to rtk's database |
| `DashboardView` | Main window: KPIs, 7-day chart, recent command history |
| `SettingsView` | Preferences: launch at login, polling interval, DB path |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for a detailed breakdown.

## Distribution

See [docs/RELEASE.md](docs/RELEASE.md) for the full release and notarization process.

## License

[MIT](LICENSE)
