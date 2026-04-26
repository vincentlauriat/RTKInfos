# RTKStats CLI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un exécutable CLI `rtk-stats` en Swift qui affiche les statistiques RTK en mode résumé (texte coloré ou tableau) et en mode TUI interactif avec refresh automatique.

**Architecture:** Extraire `Models`, `TrackingRepository` et `DBWatcher` dans un module SPM `RTKCore` partagé entre l'app macOS (via Xcode + project.yml) et le nouvel exécutable SPM `RTKStats`. Le CLI utilise `swift-argument-parser` pour les flags et un rendu ANSI fait maison.

**Tech Stack:** Swift 5.9, swift-argument-parser 1.3+, SQLite.swift 0.16+, FSEvents (macOS), Darwin termios (TUI raw mode)

---

## Structure des fichiers

**Créer :**
- `Sources/RTKCore/Models.swift` — types partagés (déplacé)
- `Sources/RTKCore/TrackingRepository.swift` — accès SQLite (déplacé)
- `Sources/RTKCore/DBWatcher.swift` — FSEvents + polling (déplacé)
- `Sources/RTKStats/RTKStats.swift` — entry point + argument parser (nommé RTKStats.swift, pas main.swift, pour utiliser `@main`)
- `Sources/RTKStats/StatsLoader.swift` — charge StatsSnapshot sans Combine
- `Sources/RTKStats/SummaryCommand.swift` — rendu résumé texte/tableau
- `Sources/RTKStats/ANSIRenderer.swift` — helpers ANSI + Painter
- `Sources/RTKStats/TUICommand.swift` — TUI interactif

**Modifier :**
- `Package.swift` — ajouter RTKCore, RTKStats, swift-argument-parser
- `project.yml` — ajouter `Sources/RTKCore` aux sources Xcode
- `RTKMenuBar/Core/StatsModel.swift` — ajouter `import RTKCore`
- `RTKMenuBarTests/DBWatcherTests.swift` — `import RTKCore`
- `RTKMenuBarTests/TrackingRepositoryTests.swift` — `import RTKCore`
- `RTKMenuBarTests/StatsModelTests.swift` — `import RTKCore`
- `Makefile` (créer si absent) — cible `install-cli`

**Supprimer :**
- `RTKMenuBar/Core/Models.swift`
- `RTKMenuBar/Core/TrackingRepository.swift`
- `RTKMenuBar/Core/DBWatcher.swift`

---

## Task 1 : Extraire RTKCore — déplacer les fichiers

**Files:**
- Create: `Sources/RTKCore/Models.swift`
- Create: `Sources/RTKCore/TrackingRepository.swift`
- Create: `Sources/RTKCore/DBWatcher.swift`
- Delete: `RTKMenuBar/Core/Models.swift`
- Delete: `RTKMenuBar/Core/TrackingRepository.swift`
- Delete: `RTKMenuBar/Core/DBWatcher.swift`

- [ ] **Step 1 : Créer le répertoire Sources/RTKCore**

```bash
mkdir -p Sources/RTKCore
```

- [ ] **Step 2 : Déplacer les trois fichiers**

```bash
mv RTKMenuBar/Core/Models.swift Sources/RTKCore/Models.swift
mv RTKMenuBar/Core/TrackingRepository.swift Sources/RTKCore/TrackingRepository.swift
mv RTKMenuBar/Core/DBWatcher.swift Sources/RTKCore/DBWatcher.swift
```

- [ ] **Step 3 : Vérifier qu'aucun import SwiftUI/AppKit n'est présent dans ces fichiers**

```bash
grep -n "import SwiftUI\|import AppKit" Sources/RTKCore/*.swift
```

Expected : aucune ligne. Si des imports sont présents, les supprimer.

- [ ] **Step 4 : Commit**

```bash
git add Sources/RTKCore/ RTKMenuBar/Core/
git commit -m "refactor: extract RTKCore module from RTKMenuBar"
```

---

## Task 2 : Mettre à jour Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1 : Remplacer le contenu de Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RTKMenuBar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.16.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Module partagé entre l'app Xcode et le CLI
        .target(
            name: "RTKCore",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "Sources/RTKCore"
        ),
        // Exécutable CLI
        .executableTarget(
            name: "RTKStats",
            dependencies: [
                "RTKCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/RTKStats"
        ),
        // Tests unitaires (RTKCore + StatsModel)
        .testTarget(
            name: "RTKMenuBarTests",
            dependencies: [
                "RTKCore",
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "RTKMenuBarTests"
        ),
    ]
)
```

- [ ] **Step 2 : Résoudre les dépendances**

```bash
swift package resolve
```

Expected : résolution sans erreur, `Package.resolved` mis à jour.

- [ ] **Step 3 : Commit**

```bash
git add Package.swift Package.resolved
git commit -m "build: add RTKCore library and RTKStats CLI targets"
```

---

## Task 3 : Mettre à jour project.yml et régénérer le projet Xcode

**Files:**
- Modify: `project.yml`

- [ ] **Step 1 : Ajouter Sources/RTKCore aux sources du target RTKMenuBar dans project.yml**

Localiser la section `sources` du target `RTKMenuBar` et ajouter `Sources/RTKCore` :

```yaml
targets:
  RTKMenuBar:
    type: application
    platform: macOS
    sources:
      - RTKMenuBar
      - Sources/RTKCore   # ← ajouter cette ligne
    ...
```

- [ ] **Step 2 : Régénérer le projet Xcode**

```bash
xcodegen generate
```

Expected : `RTKMenuBar.xcodeproj` régénéré sans erreur.

- [ ] **Step 3 : Vérifier que le build Xcode compile toujours**

```bash
xcodebuild -project RTKMenuBar.xcodeproj -scheme RTKMenuBar -configuration Debug build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
```

Expected : `BUILD SUCCEEDED`

- [ ] **Step 4 : Commit**

```bash
git add project.yml RTKMenuBar.xcodeproj
git commit -m "build: add Sources/RTKCore to Xcode target via project.yml"
```

---

## Task 4 : Mettre à jour StatsModel et les tests

**Files:**
- Modify: `RTKMenuBar/Core/StatsModel.swift`
- Modify: `RTKMenuBarTests/DBWatcherTests.swift`
- Modify: `RTKMenuBarTests/TrackingRepositoryTests.swift`
- Modify: `RTKMenuBarTests/StatsModelTests.swift`

- [ ] **Step 1 : Ajouter `import RTKCore` dans StatsModel.swift**

En tête du fichier, après `import Foundation` et `import Combine` :

```swift
import Foundation
import Combine
import RTKCore
```

- [ ] **Step 2 : Mettre à jour les imports dans DBWatcherTests.swift**

Remplacer :
```swift
@testable import RTKMenuBar
```
Par :
```swift
import RTKCore
```

- [ ] **Step 3 : Mettre à jour les imports dans TrackingRepositoryTests.swift**

Remplacer :
```swift
@testable import RTKMenuBar
```
Par :
```swift
import RTKCore
```

- [ ] **Step 4 : Mettre à jour les imports dans StatsModelTests.swift**

Remplacer :
```swift
@testable import RTKMenuBar
```
Par :
```swift
import RTKCore
```

- [ ] **Step 5 : Lancer les tests via SPM**

```bash
swift test 2>&1 | grep -E "PASS|FAIL|error:|Test Suite"
```

Expected : tous les tests passent (DBWatcherTests, TrackingRepositoryTests).

Note : StatsModelTests ne compilera pas via SPM car StatsModel dépend de SwiftUI/Combine — c'est attendu. Ces tests sont uniquement pour Xcode.

- [ ] **Step 6 : Vérifier le build Xcode avec tests**

```bash
xcodebuild test -project RTKMenuBar.xcodeproj -scheme RTKMenuBar -destination 'platform=macOS' 2>&1 | grep -E "Test Suite|PASSED|FAILED|error:"
```

Expected : tous les tests passent.

- [ ] **Step 7 : Commit**

```bash
git add RTKMenuBar/Core/StatsModel.swift RTKMenuBarTests/
git commit -m "refactor: update imports to use RTKCore module"
```

---

## Task 5 : Créer ANSIRenderer.swift

**Files:**
- Create: `Sources/RTKStats/ANSIRenderer.swift`
- Test: (pas de tests unitaires pour ANSI — sortie visuelle vérifiée manuellement à Task 7)

- [ ] **Step 1 : Créer Sources/RTKStats/**

```bash
mkdir -p Sources/RTKStats
```

- [ ] **Step 2 : Créer Sources/RTKStats/ANSIRenderer.swift**

```swift
import Foundation

// Séquences ANSI pour le rendu terminal
enum ANSI {
    static let reset    = "\u{1B}[0m"
    static let clearScreen = "\u{1B}[2J\u{1B}[H"
    static let hideCursor  = "\u{1B}[?25l"
    static let showCursor  = "\u{1B}[?25h"

    static func bold(_ s: String)   -> String { "\u{1B}[1m\(s)\u{1B}[0m" }
    static func dim(_ s: String)    -> String { "\u{1B}[2m\(s)\u{1B}[0m" }
    static func red(_ s: String)    -> String { "\u{1B}[31m\(s)\u{1B}[0m" }
    static func green(_ s: String)  -> String { "\u{1B}[32m\(s)\u{1B}[0m" }
    static func yellow(_ s: String) -> String { "\u{1B}[33m\(s)\u{1B}[0m" }
    static func cyan(_ s: String)   -> String { "\u{1B}[36m\(s)\u{1B}[0m" }
}

// Peintre conditionnel : applique les couleurs sauf si plain=true
struct Painter {
    let plain: Bool

    func bold(_ s: String)   -> String { plain ? s : ANSI.bold(s) }
    func dim(_ s: String)    -> String { plain ? s : ANSI.dim(s) }
    func red(_ s: String)    -> String { plain ? s : ANSI.red(s) }
    func green(_ s: String)  -> String { plain ? s : ANSI.green(s) }
    func yellow(_ s: String) -> String { plain ? s : ANSI.yellow(s) }
    func cyan(_ s: String)   -> String { plain ? s : ANSI.cyan(s) }
}

// Helpers partagés
func formatTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.1fk", Double(n) / 1_000) }
    return String(n)
}

func weekBar(pcts: [Double], plain: Bool) -> String {
    let blocks = ["░", "▒", "▓", "█"]
    return pcts.map { pct in
        let idx = min(3, Int(pct / 25.0))
        let ch = blocks[idx]
        return plain ? ch : ANSI.green(ch)
    }.joined()
}

extension String {
    func padded(to width: Int) -> String {
        if count >= width { return String(prefix(width)) }
        return self + String(repeating: " ", count: width - count)
    }
}
```

- [ ] **Step 3 : Commit**

```bash
git add Sources/RTKStats/ANSIRenderer.swift
git commit -m "feat(cli): add ANSI renderer and Painter helper"
```

---

## Task 6 : Créer StatsLoader.swift

**Files:**
- Create: `Sources/RTKStats/StatsLoader.swift`

- [ ] **Step 1 : Créer Sources/RTKStats/StatsLoader.swift**

```swift
import Foundation
import RTKCore

// Charge un StatsSnapshot depuis TrackingRepository (sans Combine ni ObservableObject).
struct StatsLoader {
    let dbPath: String

    func load() throws -> StatsSnapshot {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return .empty
        }
        let repo = try TrackingRepository(dbPath: dbPath)
        guard try repo.validateSchema() else {
            return StatsSnapshot(
                todayStats: nil, weekStats: [], recentCommands: [],
                globalStats: nil, topCommands: [], lastActivityDate: nil,
                isDBMissing: false
            )
        }
        return StatsSnapshot(
            todayStats:      try repo.todayStats(),
            weekStats:       try repo.weekStats(),
            recentCommands:  try repo.recentCommands(limit: 5),
            globalStats:     try repo.globalStats(),
            topCommands:     try repo.topCommands(),
            lastActivityDate: try repo.lastActivityDate(),
            isDBMissing:     false
        )
    }
}

// Résout le chemin par défaut vers history.db (même logique que StatsModel.defaultDBPath).
func resolveDefaultDBPath() -> String {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
        appSupport?.appendingPathComponent("rtk/history.db").path,
        "\(home)/.local/share/rtk/history.db"
    ].compactMap { $0 }
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
        ?? candidates.last ?? ""
}
```

- [ ] **Step 2 : Vérifier que ça compile**

```bash
swift build --target RTKStats 2>&1 | grep -E "error:|Build complete"
```

Expected : pas d'erreur de compilation sur les fichiers existants (main.swift n'existe pas encore — c'est OK, le build échouera sur le target entier mais StatsLoader compilera si on crée un main.swift vide).

- [ ] **Step 3 : Commit**

```bash
git add Sources/RTKStats/StatsLoader.swift
git commit -m "feat(cli): add StatsLoader for DB reading without Combine"
```

---

## Task 7 : Créer SummaryCommand.swift (avec tests)

**Files:**
- Create: `Sources/RTKStats/SummaryCommand.swift`
- Test: `RTKMenuBarTests/SummaryCommandTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

Créer `RTKMenuBarTests/SummaryCommandTests.swift` :

```swift
import XCTest
import RTKCore
@testable import RTKStats   // Note: RTKStats n'est pas encore un testable module — voir ci-dessous
```

Note importante : `RTKStats` est un exécutable, pas une library — `@testable import` ne fonctionnera pas directement. Les tests de formatage seront dans le même target que les sources. On teste donc via la sortie capturée.

Créer à la place `RTKMenuBarTests/FormatterTests.swift` qui teste `formatTokens` et `weekBar` exportés depuis `ANSIRenderer.swift` en ajoutant ces fonctions à `RTKCore` ou en les extrayant dans un module testable.

Plutôt que de compliquer la structure, on garde `formatTokens` et `weekBar` dans `Sources/RTKStats/ANSIRenderer.swift` et on les teste via intégration (build + exécution). Les tests unitaires critiques portent sur `TrackingRepository` déjà couverts.

- [ ] **Step 2 : Créer Sources/RTKStats/SummaryCommand.swift**

```swift
import Foundation
import RTKCore

struct SummaryCommand {
    let snapshot: StatsSnapshot
    let table: Bool
    let plain: Bool

    func render() {
        table ? renderTable() : renderText()
    }

    // MARK: — Mode texte coloré

    private func renderText() {
        let p = Painter(plain: plain)
        print(p.bold("RTK Token Savings"))
        print("")

        if snapshot.isDBMissing {
            print(p.red("  ✗ history.db introuvable. Vérifiez que rtk est installé."))
            return
        }

        if let today = snapshot.todayStats {
            print(p.bold("  Aujourd'hui"))
            print("  Commandes     : \(p.cyan(String(today.totalCommands)))")
            print("  Tokens sauvés : \(p.green(formatTokens(today.savedTokens)))  (\(p.green(String(format: "%.1f%%", today.savingsPct))))")
        } else {
            print("  Aujourd'hui   : aucune commande enregistrée")
        }

        if !snapshot.weekStats.isEmpty {
            print("")
            print(p.bold("  7 derniers jours"))
            let pcts = snapshot.weekStats.map(\.savingsPct)
            print("  \(weekBar(pcts: pcts, plain: plain))")
            let avg = pcts.reduce(0, +) / Double(pcts.count)
            print("  Moyenne       : \(p.green(String(format: "%.1f%%", avg)))")
        }

        if let global = snapshot.globalStats {
            print("")
            print(p.bold("  Total"))
            print("  Commandes     : \(p.cyan(String(global.totalCommands)))")
            print("  Tokens sauvés : \(p.green(formatTokens(global.totalSavedTokens)))")
            print("  Moyenne glob. : \(p.green(String(format: "%.1f%%", global.avgSavingsPct)))")
        }

        if snapshot.isInactive {
            print("")
            print(p.yellow("  ⚠ Aucune activité depuis plus de 7 jours"))
        }
    }

    // MARK: — Mode tableau

    private func renderTable() {
        let p = Painter(plain: plain)
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEE dd/MM"
        dateFmt.locale = Locale(identifier: "fr_FR")

        let header = "Date".padded(to: 12) + "  " + "Cmds".padded(to: 6) + "  "
                   + "Sauvés".padded(to: 10) + "  " + "Moy%"
        print(p.bold(header))
        print(p.dim(String(repeating: "─", count: 42)))

        for day in snapshot.weekStats {
            let row = dateFmt.string(from: day.date).padded(to: 12) + "  "
                    + String(day.totalCommands).padded(to: 6) + "  "
                    + formatTokens(day.savedTokens).padded(to: 10) + "  "
                    + String(format: "%.1f%%", day.savingsPct)
            print(row)
        }

        if snapshot.weekStats.isEmpty {
            print("  (aucune donnée)")
        }
    }
}
```

- [ ] **Step 3 : Commit**

```bash
git add Sources/RTKStats/SummaryCommand.swift
git commit -m "feat(cli): add SummaryCommand with text and table rendering"
```

---

## Task 8 : Créer TUICommand.swift

**Files:**
- Create: `Sources/RTKStats/TUICommand.swift`

- [ ] **Step 1 : Créer Sources/RTKStats/TUICommand.swift**

```swift
import Foundation
import Darwin
import RTKCore

struct TUICommand {
    let dbPath: String
    let interval: TimeInterval

    func run() async throws {
        let oldTerm = enableRawMode()
        print(ANSI.hideCursor, terminator: "")
        fflush(stdout)

        defer {
            restoreTerminal(oldTerm)
            print(ANSI.showCursor, terminator: "")
            print("")   // retour à la ligne après le TUI
            fflush(stdout)
        }

        let loader = StatsLoader(dbPath: dbPath)
        var snapshot = (try? loader.load()) ?? .empty
        let state = TUIState()

        // Lecture clavier dans un Task détaché
        Task.detached {
            var byte: UInt8 = 0
            while !(await state.isDone) {
                withUnsafeMutablePointer(to: &byte) { ptr in _ = read(STDIN_FILENO, ptr, 1) }
                switch byte {
                case UInt8(ascii: "q"), UInt8(ascii: "Q"), 3:  // 3 = Ctrl-C
                    await state.quit()
                case UInt8(ascii: "t"), UInt8(ascii: "T"):
                    await state.toggleTop()
                case UInt8(ascii: "r"), UInt8(ascii: "R"):
                    await state.requestRefresh()
                default: break
                }
            }
        }

        // Watcher DB
        let dirPath = URL(fileURLWithPath: dbPath).deletingLastPathComponent().path
        let watcher = DBWatcher(directoryPath: dirPath, pollingInterval: interval)
        watcher.start()
        defer { watcher.stop() }

        render(snapshot: snapshot, showTop: await state.showTop)

        for await _ in watcher.events {
            if await state.isDone { break }
            snapshot = (try? loader.load()) ?? snapshot
            render(snapshot: snapshot, showTop: await state.showTop)
        }
    }

    // MARK: — Rendu TUI

    private func render(snapshot: StatsSnapshot, showTop: Bool) {
        // Remonter en haut et effacer l'écran
        print(ANSI.clearScreen, terminator: "")

        print(ANSI.bold("╔══════════════════════════════════════════════╗"))
        print(ANSI.bold("║            RTK Token Savings                 ║"))
        print(ANSI.bold("╚══════════════════════════════════════════════╝"))
        print("")

        if snapshot.isDBMissing {
            print(ANSI.red("  ✗ history.db introuvable"))
            printFooter()
            return
        }

        if !showTop {
            renderMain(snapshot: snapshot)
        } else {
            renderTop(snapshot: snapshot)
        }

        printFooter()
        fflush(stdout)
    }

    private func renderMain(snapshot: StatsSnapshot) {
        // Aujourd'hui
        if let today = snapshot.todayStats {
            print(ANSI.bold("  AUJOURD'HUI"))
            print("  Commandes     \(ANSI.cyan(String(today.totalCommands).padded(to: 8)))  Tokens sauvés  \(ANSI.green(formatTokens(today.savedTokens)))")
            print("  Moy. savings  \(ANSI.green(String(format: "%.1f%%", today.savingsPct)))")
        } else {
            print("  AUJOURD'HUI   aucune commande")
        }
        print("")

        // Graphe 7 jours
        if !snapshot.weekStats.isEmpty {
            print(ANSI.bold("  7 DERNIERS JOURS"))
            let pcts = snapshot.weekStats.map(\.savingsPct)
            print("  \(weekBar(pcts: pcts, plain: false))")
            let avg = pcts.reduce(0, +) / Double(pcts.count)
            print("  Moyenne : \(ANSI.green(String(format: "%.1f%%", avg)))")
            print("")
        }

        // Récents
        if !snapshot.recentCommands.isEmpty {
            print(ANSI.bold("  RÉCENTS"))
            let fmt = RelativeDateTimeFormatter()
            fmt.unitsStyle = .short
            for cmd in snapshot.recentCommands.prefix(5) {
                let rel = fmt.localizedString(for: cmd.timestamp, relativeTo: Date())
                let pct = String(format: "%5.1f%%", cmd.savingsPct)
                let name = String(cmd.rtkCmd.prefix(28)).padded(to: 28)
                print("  \(ANSI.dim(rel.padded(to: 8)))  \(name)  \(ANSI.green(pct))")
            }
        }

        if snapshot.isInactive {
            print("")
            print(ANSI.yellow("  ⚠ Aucune activité depuis > 7 jours"))
        }
    }

    private func renderTop(snapshot: StatsSnapshot) {
        print(ANSI.bold("  TOP COMMANDES (par tokens sauvés)"))
        print("")
        for (i, cmd) in snapshot.topCommands.prefix(10).enumerated() {
            let bar = String(repeating: "█", count: max(1, Int(cmd.impactRatio * 20)))
            let name = String(cmd.command.prefix(24)).padded(to: 24)
            print("  \(String(i + 1).padded(to: 2)). \(name)  \(ANSI.green(bar))  \(formatTokens(cmd.totalSaved))")
        }
    }

    private func printFooter() {
        print("")
        print(ANSI.dim("  [q] quitter   [r] refresh   [t] top commandes"))
    }

    // MARK: — Terminal raw mode

    private func enableRawMode() -> termios {
        var old = termios()
        tcgetattr(STDIN_FILENO, &old)
        var raw = old
        raw.c_lflag &= ~(tcflag_t(ECHO) | tcflag_t(ICANON))
        withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
            let base = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: cc_t.self)
            base[Int(VMIN)]  = 1
            base[Int(VTIME)] = 0
        }
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        return old
    }

    private func restoreTerminal(_ term: termios) {
        var t = term
        tcsetattr(STDIN_FILENO, TCSANOW, &t)
    }
}

// MARK: — État partagé TUI (actor pour thread-safety)

actor TUIState {
    private(set) var showTop = false
    private(set) var isDone  = false
    private(set) var needsRefresh = false

    func toggleTop()       { showTop.toggle() }
    func quit()            { isDone = true }
    func requestRefresh()  { needsRefresh = true }
    func clearRefresh()    { needsRefresh = false }
}

// padded(to:) est défini dans ANSIRenderer.swift (extension String non-private)
```

- [ ] **Step 2 : Commit**

```bash
git add Sources/RTKStats/TUICommand.swift
git commit -m "feat(cli): add TUI interactive command with raw mode and DB watcher"
```

---

## Task 9 : Créer RTKStats.swift (entry point)

**Files:**
- Create: `Sources/RTKStats/RTKStats.swift`

Note : le fichier s'appelle `RTKStats.swift` (PAS `main.swift`). En Swift, un fichier nommé `main.swift` fournit le point d'entrée implicitement, ce qui entre en conflit avec `@main`. On utilise `@main` sur une struct dans un fichier au nom quelconque.

- [ ] **Step 1 : Créer Sources/RTKStats/RTKStats.swift**

```swift
import ArgumentParser
import RTKCore

@main
struct RTKStatsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "rtk-stats",
        abstract: "Affiche les statistiques de token savings RTK",
        version: "1.0.0"
    )

    @Flag(name: .long, help: "Mode TUI interactif")
    var tui = false

    @Flag(name: .long, help: "Sortie en tableau aligné")
    var table = false

    @Flag(name: .long, help: "Sortie sans couleurs ANSI (pour scripts)")
    var plain = false

    @Option(name: .long, help: "Chemin vers history.db")
    var db: String?

    @Option(name: .long, help: "Intervalle de refresh en secondes (mode TUI, défaut: 5)")
    var interval: Double = 5.0

    mutating func run() async throws {
        let dbPath = db ?? resolveDefaultDBPath()

        if tui {
            try await TUICommand(dbPath: dbPath, interval: interval).run()
        } else {
            let loader = StatsLoader(dbPath: dbPath)
            let snapshot = try loader.load()
            SummaryCommand(snapshot: snapshot, table: table, plain: plain).render()
        }
    }
}
```

- [ ] **Step 2 : Builder le target RTKStats**

```bash
swift build --target RTKStats 2>&1 | grep -E "error:|Build complete|warning:"
```

Expected : `Build complete!` sans erreur.

- [ ] **Step 3 : Tester le mode résumé**

```bash
swift run RTKStats 2>&1
```

Expected : affichage des stats RTK en texte coloré, ou message "history.db introuvable" si rtk n'est pas configuré.

- [ ] **Step 4 : Tester le mode tableau**

```bash
swift run RTKStats -- --table 2>&1
```

Expected : tableau aligné avec colonnes Date / Cmds / Sauvés / Moy%.

- [ ] **Step 5 : Tester le mode TUI**

```bash
swift run RTKStats -- --tui
```

Expected : TUI s'affiche, `q` quitte proprement, curseur restauré.

- [ ] **Step 6 : Commit**

```bash
git add Sources/RTKStats/RTKStats.swift
git commit -m "feat(cli): add rtk-stats entry point with argument-parser"
```

---

## Task 10 : Build release et Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1 : Build release**

```bash
swift build -c release --target RTKStats 2>&1 | grep -E "error:|Build complete"
```

Expected : `Build complete!`

- [ ] **Step 2 : Vérifier le binaire**

```bash
.build/release/rtk-stats --version
.build/release/rtk-stats --help
```

Expected :
```
1.0.0
OVERVIEW: Affiche les statistiques de token savings RTK
...
```

- [ ] **Step 3 : Créer le Makefile**

```makefile
.PHONY: build-cli install-cli clean-cli

build-cli:
	swift build -c release --target RTKStats

install-cli: build-cli
	cp .build/release/rtk-stats /usr/local/bin/rtk-stats
	@echo "rtk-stats installé dans /usr/local/bin/"

clean-cli:
	swift package clean
```

- [ ] **Step 4 : Tester `make install-cli`**

```bash
make install-cli
rtk-stats --version
```

Expected : `1.0.0`

- [ ] **Step 5 : Commit final**

```bash
git add Makefile
git commit -m "build: add Makefile with install-cli target for rtk-stats"
```

---

## Checklist de vérification finale

- [ ] `swift build --target RTKStats` → Build complete sans erreur
- [ ] `swift test` → tous les tests RTKCore passent
- [ ] `xcodebuild -scheme RTKMenuBar build` → BUILD SUCCEEDED
- [ ] `.build/release/rtk-stats` → sortie résumé correcte
- [ ] `.build/release/rtk-stats --table` → tableau aligné
- [ ] `.build/release/rtk-stats --tui` → TUI interactif, `q` quitte proprement
- [ ] `make install-cli` → binaire installé dans `/usr/local/bin`
