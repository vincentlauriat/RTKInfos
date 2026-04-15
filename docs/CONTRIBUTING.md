# Contributing

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Xcode | 15+ | App Store |
| Swift | 5.9+ | Bundled with Xcode |
| xcodegen | any | `brew install xcodegen` |

macOS 14 (Sonoma) or later is required to build and run the app.

## Getting started

```bash
git clone https://github.com/your-org/RTKMenuBar.git
cd RTKMenuBar

# Resolve Swift Package Manager dependencies
swift package resolve

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open RTKMenuBar.xcodeproj
```

> `.xcodeproj` is gitignored. Always regenerate it with `xcodegen generate` after pulling changes that touch `project.yml`.

## Project structure

```
RTKMenuBar/
├── RTKMenuBar/
│   ├── App/
│   │   └── RTKMenuBarApp.swift     # Entry point + AppDelegate
│   ├── Core/
│   │   ├── Models.swift            # Data structures (DayStats, CommandRecord, StatsSnapshot)
│   │   ├── StatsModel.swift        # @Observable source of truth
│   │   ├── DBWatcher.swift         # FSEvents + polling watcher
│   │   └── TrackingRepository.swift # SQLite read-only access
│   └── UI/
│       ├── DashboardView.swift     # Main window
│       └── SettingsView.swift      # Preferences
├── RTKMenuBarTests/                # XCTest suite
├── docs/                           # Documentation
├── scripts/
│   └── build-release.sh           # Notarization + DMG packaging
├── project.yml                    # XcodeGen configuration (source of truth)
├── Package.swift                  # Swift Package Manager
└── Info.plist                     # Bundle metadata
```

## Development workflow

### Building

```bash
# SPM build (fast, no Xcode required)
swift build

# Xcode build (required for running the app)
xcodebuild -project RTKMenuBar.xcodeproj -scheme RTKMenuBar build
```

### Running tests

```bash
swift test
```

All 11 tests must pass before opening a pull request.

### Testing with a real database

rtk writes to one of these locations:
- `~/Library/Application Support/rtk/history.db`
- `~/.local/share/rtk/history.db`

If you don't have rtk installed, you can create a test database manually:

```bash
mkdir -p ~/Library/Application\ Support/rtk
sqlite3 ~/Library/Application\ Support/rtk/history.db "
CREATE TABLE IF NOT EXISTS commands (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    original_cmd TEXT,
    rtk_cmd TEXT,
    input_tokens INTEGER,
    output_tokens INTEGER,
    saved_tokens INTEGER,
    savings_pct REAL
);
INSERT INTO commands VALUES
    (1, datetime('now'), 'git status', 'rtk git status', 1200, 80, 900, 75.0),
    (2, datetime('now', '-1 hour'), 'git log', 'rtk git log', 800, 60, 600, 75.0);
"
```

Then launch RTKMenuBar — it will detect the database automatically.

## Code style

- Follow the existing file structure: `App/`, `Core/`, `UI/`.
- Use `// MARK: -` sections to organize code within files.
- All UI state mutations must happen on `@MainActor`.
- Prefer `async/await` and `AsyncStream` over callbacks and `DispatchQueue`.
- Do not add error handling for cases that cannot occur — trust framework guarantees.
- Write `///` doc comments on public types and methods.

## Adding a new metric

1. Add the field to `DayStats` or `CommandRecord` in `Models.swift`.
2. Update `StatsSnapshot` if a new computed property is needed.
3. Add the SQL query in `TrackingRepository`.
4. Update `StatsModel.refresh()` to populate the new field.
5. Display it in `DashboardView`.
6. Add a test in `TrackingRepositoryTests`.

## Git workflow

- Branch from `main`.
- Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`.
- Open a pull request — do not push directly to `main`.
- The PR title should be under 70 characters.

## Pull request checklist

- [ ] `swift build` passes
- [ ] `swift test` passes (11/11)
- [ ] No new compiler warnings
- [ ] Code follows existing style
- [ ] Relevant documentation updated
