# Changelog

## Unreleased

### Fixed
- **Release builds shipped as v1.0 without auto-update.** The `info: { path: Info.plist }`
  section in `project.yml` made xcodegen regenerate `Info.plist` on every `generate`,
  resetting the version to 1.0/1 and dropping all Sparkle keys (`SUFeedURL`,
  `SUPublicEDKey`, …). Removed the section; `INFOPLIST_FILE` already wires the
  hand-maintained plist as a template. (PR #9)

## v1.1.0 — 2026-06-28

### Added
- **"Compression Gauge" UX redesign** — the dashboard is rebuilt around one
  signature element: a horizontal gauge showing raw `input` compressed down to
  `output`, with the reclaimed ("killed") tokens painted in emerald.
- Embedded **Geist** + **Geist Mono** fonts for a distinct, technical identity.
- Compact `Today` strip (saved · commands · rate).
- `Live Trace` emerald dot that pulses on each new command (respects Reduce Motion).
- `make build-debug` / `make run-debug` targets for launching the app locally
  (works around the macOS Sequoia codesign xattr issue).

### Changed
- Single emerald accent throughout; the old red/orange/green "traffic-light"
  coloring is gone. Low-signal commands read as neutral gray, never judged.
- Entire interface is now in **English** (labels, dates, status banners).
- `By Command` impact bars are native SwiftUI capsules (no more ASCII `█░`).
- Header glyph is a diamond ◆ (window + menu bar), replacing the yellow bolt.
- CLI labels renamed to reflect the weighted figure: "Moyenne glob." →
  "Taux global", "Moyenne" (7d) → "Taux 7j", "Moy. savings" → "Taux savings".
- Sparkle update-signing key changed. **Users on v1.0.0 must download v1.1.0
  manually once**; auto-update resumes for all later versions.

### Fixed
- Savings percentage was computed as `AVG(savings_pct)` (unweighted mean of
  per-command percentages), which understated the real figure dramatically
  (7.4% reported vs 66.2% actual on the reference DB). All aggregates
  (`todayStats`, `weekStats`, `globalStats`, `topCommands`) now use the
  volume-weighted ratio `100 * SUM(saved_tokens) / SUM(input_tokens)`.
- 7-day average in the CLI (`summary` and TUI) had the same flaw: it averaged
  the per-day percentages instead of weighting by each day's volume. Now uses
  `100 * SUM(saved) / SUM(input)` over the week.

## v1.0.0 — 2026-05-05

Initial public release.

### Features
- Real-time monitoring of rtk token savings via FSEvents + polling fallback
- Daily KPIs: tokens saved, command count, average savings %, raw usage
- 7-day bar chart of daily savings percentage
- Recent command history with per-command savings
- Status alerts for missing rtk install or inactivity > 7 days
- Preferences: launch at login, polling interval, custom DB path
- Sparkle auto-update (checks daily, prompts before installing)
- `rtk-stats` CLI companion for terminal-based stats
