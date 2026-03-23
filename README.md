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

> **Note** : Le fichier `.xcodeproj` n'est pas versionné (ignoré par `.gitignore`).
> Il doit être régénéré localement avec `xcodegen generate` après chaque clone.
> Le fichier `project.yml` est la source de vérité pour la configuration Xcode.

## Distribution

### Prérequis

- Compte Apple Developer (99 $/an) avec certificat **Developer ID Application**
- Xcode avec les outils de ligne de commande installés
- `create-dmg` : `brew install create-dmg`
- Identifiants notarytool configurés : `xcrun notarytool store-credentials AC_PASSWORD`

### Construire une release

```bash
./scripts/build-release.sh 1.0.0
```

Le script guide à travers les étapes :
1. Génération du projet Xcode via `xcodegen`
2. Archive Xcode (Product → Archive → Distribute App → Direct Distribution)
3. Soumission pour notarisation et agrafage (stapling)
4. Tag git de la version

> **Note** : Les étapes de signing et notarisation nécessitent des credentials Apple Developer
> non versionnés. Voir les instructions inline du script.

### Tests avant distribution

Consulter `INTEGRATION_TEST.md` pour le protocole de tests manuels complet
avant toute distribution publique.

## Architecture

- `DBWatcher` : surveille `~/.local/share/macrtk/tracking.db` via FSEvents
- `TrackingRepository` : lecture SQLite read-only
- `StatsModel` : @Observable source de vérité
- `PopoverView` : dashboard KPIs + chart 7j + historique
- `SettingsView` : login item, polling interval, DB path
