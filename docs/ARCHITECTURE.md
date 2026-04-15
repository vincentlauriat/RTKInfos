# Architecture

RTKMenuBar is a native macOS application built with SwiftUI that reads from rtk's SQLite tracking database and displays token savings statistics in a persistent window.

## Overview

```
┌─────────────────────────────────────────────────────────┐
│  RTKMenuBarApp (@main)                                   │
│  └── AppDelegate (NSApplicationDelegate)                 │
│       └── StatsModel (@Observable, @MainActor)          │
│            ├── DBWatcher                                 │
│            │    ├── FSEventStream  ──┐                   │
│            │    └── Timer (fallback) ├──► AsyncStream    │
│            │                        │                    │
│            └── TrackingRepository ◄─┘                    │
│                 └── SQLite (read-only)                   │
│                      └── history.db (rtk)            │
│                                                          │
│  SwiftUI Scene                                           │
│  ├── DashboardView  ←── @Environment(StatsModel)         │
│  └── SettingsView   ←── @AppStorage (UserDefaults)       │
└─────────────────────────────────────────────────────────┘
```

## Components

### `RTKMenuBarApp` + `AppDelegate`

**File**: `RTKMenuBar/App/RTKMenuBarApp.swift`

The SwiftUI entry point uses `@NSApplicationDelegateAdaptor` to bridge to `AppDelegate`. This is necessary because:

- `StatsModel` must be initialized **before** SwiftUI renders any view (to avoid a nil environment object crash).
- `AppDelegate.init()` reads `UserDefaults` for `dbPath` and `pollingInterval`, constructs `StatsModel`, then calls `model.start()` in `applicationDidFinishLaunching`.

Key behaviors:
- `applicationShouldTerminateAfterLastWindowClosed` returns `false` — the app stays alive when all windows are closed (standard menu bar app pattern).
- `applicationShouldHandleReopen` shows the main window when the user clicks the Dock icon with no visible windows.
- Activation policy is `.regular` (app appears in the Dock and can have a main window).

---

### `StatsModel`

**File**: `RTKMenuBar/Core/StatsModel.swift`

The single source of truth for all UI state.

```
@Observable @MainActor
class StatsModel {
    var snapshot: StatsSnapshot   // ← only published property
}
```

**Data flow**:
1. `start()` creates a `DBWatcher` for the directory containing `history.db`.
2. A `Task` consumes `watcher.events` (an `AsyncStream<Void>`).
3. Each event triggers `refresh()`, which reads the database via `TrackingRepository` and updates `snapshot`.
4. SwiftUI views observing `snapshot` re-render automatically.

**DB path resolution** (`defaultDBPath`):
Checks two locations in priority order:
1. `~/Library/Application Support/rtk/history.db`
2. `~/.local/share/rtk/history.db`

Returns the first path that exists, falling back to the last candidate.

**Error handling**:
- DB missing → `snapshot.isDBMissing = true`, UI shows setup banner.
- Schema mismatch → degraded mode (no stats, no error thrown).
- Query error → previous snapshot is preserved, error is logged.

---

### `DBWatcher`

**File**: `RTKMenuBar/Core/DBWatcher.swift`

Monitors the rtk data directory and emits `AsyncStream<Void>` events when `history.db` changes.

**Two-layer detection**:

| Layer | Mechanism | Latency | Notes |
|-------|-----------|---------|-------|
| Primary | `FSEventStream` (kernel-level) | ~500ms | Filters for `history.db` path suffix |
| Fallback | `Timer` (polling) | Configurable (5s / 30s / 60s) | Fires regardless of FS activity |

**Memory management**:
FSEvents requires a C-style callback, which cannot capture Swift objects directly. The pattern used:
```swift
let selfPtr = Unmanaged.passRetained(self).toOpaque()  // +1 retain
// ... passed to FSEventStreamContext.info ...
// In callback:
let watcher = Unmanaged<DBWatcher>.fromOpaque(info).takeUnretainedValue()
// In stop():
Unmanaged<DBWatcher>.fromOpaque(ptr).release()          // -1 retain
```

**`AsyncStream` initialization**:
The stream and its continuation are created synchronously in `init()` to eliminate a race condition where `start()` could be called before the stream property is accessed.

---

### `TrackingRepository`

**File**: `RTKMenuBar/Core/TrackingRepository.swift`

Read-only SQLite access layer using [SQLite.swift](https://github.com/stephencelis/SQLite.swift).

**Design decisions**:
- **New connection per call**: avoids SQLite lock conflicts when rtk writes to the DB concurrently, and handles the case where rtk recreates the file.
- **Read-only flag**: `Connection(dbPath, readonly: true)` — guarantees the app never modifies rtk data.
- **Schema validation**: `validateSchema()` checks for all required columns before any query, enabling a graceful degraded mode on version mismatches.

**Expected schema** (`commands` table):

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key |
| `timestamp` | TEXT | ISO 8601 UTC |
| `original_cmd` | TEXT | Command before rtk rewrite |
| `rtk_cmd` | TEXT | Optimized command sent to Claude |
| `input_tokens` | INTEGER | Tokens in the optimized request |
| `output_tokens` | INTEGER | Tokens in the response |
| `saved_tokens` | INTEGER | `original_input - input_tokens` |
| `savings_pct` | REAL | `(saved_tokens / original_input) * 100` |

---

### `Models`

**File**: `RTKMenuBar/Core/Models.swift`

Plain value types — no logic, no side effects.

```
DayStats           — aggregated stats for one calendar day
CommandRecord      — one command execution record
StatsSnapshot      — complete UI state snapshot (immutable)
  └── isInactive   — computed: last activity > 7 days ago
```

`StatsSnapshot.empty` is the initial state: `isDBMissing = true`, all collections empty.

---

### `DashboardView`

**File**: `RTKMenuBar/UI/DashboardView.swift`

Main application window. Receives `StatsModel` via `@Environment`.

**Layout**:
```
┌─────────────────────────────────┐
│ Toolbar (title, refresh, prefs) │
├─────────────────────────────────┤
│ Status banner (if needed)       │
│ ─────────────────────────────── │
│ KPI cards (4 × tokens/cmds/%)   │
│ 7-day savings chart             │
│ Recent commands history         │
└─────────────────────────────────┘
```

**Conditional rendering**: KPI, chart, and history sections are hidden when `isDBMissing` is true — only the status banner is shown.

**Color coding** (savings %):
- ≥ 70% → green
- 40–69% → orange
- < 40% → red

**Sub-components**:
- `KPICard` — reusable metric card with icon, value, label, and tinted background.
- `StatusBanner` — alert banner for DB missing or inactivity states.

---

### `SettingsView`

**File**: `RTKMenuBar/UI/SettingsView.swift`

SwiftUI `Settings` scene (accessible via `Cmd+,` or the "Preferences" button).

**Settings stored in `UserDefaults`** via `@AppStorage`:

| Key | Type | Default | Effect |
|-----|------|---------|--------|
| `launchAtLogin` | Bool | false | Registers/unregisters `SMAppService.mainApp` |
| `pollingInterval` | Double | 30.0 | Polling fallback interval (takes effect on next launch) |
| `dbPath` | String | auto-detected | Path to `history.db` (takes effect on next launch) |

**`SMAppService` error handling**:
- Code 1 (already registered) → silently ignored (idempotent).
- Code 3 (app not in /Applications) → shows error message, reverts toggle.

## Data flow summary

```
history.db modified
        │
        ▼
  DBWatcher (FSEvents or Timer)
        │  AsyncStream<Void>.yield()
        ▼
  StatsModel.refresh()
        │  reads DB
        ▼
  TrackingRepository queries
        │  returns DayStats, [DayStats], [CommandRecord], Date?
        ▼
  StatsSnapshot updated
        │  @Observable triggers SwiftUI diff
        ▼
  DashboardView re-renders
```

## Dependency graph

```
RTKMenuBarApp
├── AppDelegate
│   └── StatsModel
│       ├── DBWatcher (CoreServices.FSEvents)
│       └── TrackingRepository
│           └── SQLite.swift (stephencelis/SQLite.swift 0.16.0+)
└── SwiftUI Scenes
    ├── DashboardView → StatsModel (via @Environment)
    └── SettingsView  → UserDefaults (via @AppStorage)
```

## Technology choices

| Choice | Rationale |
|--------|-----------|
| `@Observable` (Swift 5.9) | Fine-grained dependency tracking vs `ObservableObject` |
| `@MainActor` on `StatsModel` | UI state must be mutated on main thread; eliminates manual `DispatchQueue.main` calls |
| `AsyncStream` for watcher events | Structured concurrency integration; backpressure-free for low-frequency DB events |
| New SQLite connection per query | Avoids lock contention with rtk writer; handles file recreation transparently |
| `FSEvents` + polling dual layer | FSEvents is instant but may miss events on mounted/network volumes; polling is the safety net |
| No App Sandbox (v1) | Direct file access to `history.db` without entitlement prompts; acceptable for direct distribution |
