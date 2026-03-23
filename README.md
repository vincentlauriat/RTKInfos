# RTKMenuBar

macOS menu bar app for [macrtk](https://github.com/rtk-ai/macrtk) token savings.

## Requirements

- macOS 14+ (Sonoma)
- macrtk installed and configured

## Development

```bash
# Résoudre les dépendances
swift package resolve

# Générer le projet Xcode (nécessite xcodegen)
brew install xcodegen
xcodegen generate

# Ou builder directement avec SPM
swift build
```

## Architecture

- `DBWatcher` : surveille `~/.local/share/macrtk/tracking.db` via FSEvents
- `TrackingRepository` : lecture SQLite read-only
- `StatsModel` : @Observable source de vérité
- `PopoverView` : dashboard KPIs + chart 7j + historique
- `SettingsView` : login item, polling interval, DB path
