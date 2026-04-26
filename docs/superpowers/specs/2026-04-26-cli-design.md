# RTKStats CLI — Design Spec
**Date:** 2026-04-26

## Objectif

Ajouter une version CLI à RTKMenuBar permettant d'afficher les statistiques RTK directement dans le terminal, en mode résumé rapide et en mode TUI interactif.

## Architecture

```
Package.swift
├── RTKCore (library)
│   ├── Models.swift
│   ├── TrackingRepository.swift
│   └── DBWatcher.swift
│
├── RTKMenuBar (app macOS — inchangé)
│   ├── App/RTKMenuBarApp.swift
│   ├── Core/StatsModel.swift
│   └── UI/...
│
└── RTKStats (executable CLI)
    ├── main.swift
    ├── SummaryCommand.swift
    └── TUICommand.swift
```

**Refactoring requis :** extraire `Models.swift`, `TrackingRepository.swift`, `DBWatcher.swift` dans un module `RTKCore` (retirer les imports SwiftUI/AppKit). `StatsModel` reste dans l'app macOS (dépend de Combine + @MainActor).

**Nouvelles dépendances :**
- `swift-argument-parser` — parsing des flags CLI
- Rendu ANSI fait maison pour le TUI (pas de lib externe)

## Commandes CLI

```bash
rtk-stats                    # résumé texte coloré (défaut)
rtk-stats --table            # résumé en tableau aligné
rtk-stats --plain            # texte sans couleurs (pour scripts)
rtk-stats --tui              # dashboard TUI interactif

rtk-stats --db <path>        # chemin custom vers history.db
rtk-stats --today            # stats du jour seulement
rtk-stats --week             # stats 7 jours
rtk-stats --top              # top commandes par tokens sauvés
```

## Mode résumé

Sortie texte coloré (défaut) :
```
RTK — Aujourd'hui
  Commandes     : 42
  Tokens sauvés : 18 450  (74.2%)
  7 derniers jours : ████████▓▓  68.1% moy.
```

Avec `--table` : colonnes alignées.
Avec `--plain` : pas de couleurs ANSI.

## Mode TUI interactif (`--tui`)

```
┌─ RTK Stats ──────────────────────────────┐
│  Aujourd'hui : 42 cmds · 18 450 sauvés   │
│  Moyenne     : 74.2%                      │
│                                           │
│  7 jours ▐████████▓▓░░░░░░░░░░░░░░▌      │
│           lun mar mer jeu ven sam dim     │
│                                           │
│  Récents                                  │
│  14:32  git status        59%  -120 tok   │
│  14:28  cargo build       88%  -4200 tok  │
│  14:15  pnpm install      90%  -8100 tok  │
│                                           │
│  [q] quitter  [r] refresh  [t] top cmds  │
└──────────────────────────────────────────┘
```

**Refresh :** FSEvents + polling fallback via `DBWatcher` existant, intervalle configurable `--interval <sec>` (défaut 5s).

**Rendu :** effacement ligne par ligne (`\r\033[K`) pour éviter le flickering.

**Navigation :** `q` quitter, `r` refresh manuel, `t` basculer vue "top commandes".

## Tests

- Les tests existants de `TrackingRepository` restent valides après extraction dans `RTKCore`.
- Nouveaux tests unitaires pour les formatters (texte coloré, tableau).

## Distribution

```bash
swift build -c release
cp .build/release/rtk-stats /usr/local/bin/
```

Cible Makefile : `make install-cli`.

Le binaire est autonome, distribuable séparément ou inclus dans le `.dmg` de l'app macOS.
