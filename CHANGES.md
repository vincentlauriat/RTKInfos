# Changelog

## Unreleased

### Changed
- **Dashboard visual pass — "All time" & "By Command" less flat.** Made the lower
  dashboard as engaging as the hero/chart, keeping the single-emerald design
  language (no red/orange):
  - **Hero `%`** promoted from `rtkData(15)` to a bold `rtkDisplay(20)` in an
    emerald pill — no longer dwarfed by the 44 pt saved total.
  - **All time** rebuilt from a flat grey text list into tiles: an emerald
    "Tokens saved" highlight card (big mono value + `%` + input→output) above a
    2-column grid of neutral metric tiles (icon + mono value + label).
  - **By Command** given relief: emerald rank chips for the top 3, the "Saved"
    column in emerald, thicker impact bars, roomier rows.

### Added
- **Accessibility pass (behavioral).** All animations now honor Reduce Motion
  (panel toggles, trace auto-scroll, panel transition). VoiceOver labels/values
  added to toolbar buttons, the "By Command" rows, the Live Trace rows, and the
  Compression Gauge. Decorative elements (◆ glyph, pulsing dot) are hidden from
  assistive tech.
- **AA contrast** — functional text (table headers, TODAY, INPUT/OUTPUT
  captions, trace timestamps, command count) moved from `rtkMist` to `rtkSlate`
  (~6.5:1, AA-compliant). `rtkMist` stays for low-signal decorative states.

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
