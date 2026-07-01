import SwiftUI
import Charts

/// The main application window.
///
/// Displays today's token savings KPIs, a 7-day savings percentage chart,
/// and a recent command history list. Conditionally shows status banners
/// when rtk is not installed or has been inactive for more than 7 days.
///
/// Receives `StatsModel` via `@Environment` and re-renders automatically
/// whenever `snapshot` changes.
struct DashboardView: View {

    @EnvironmentObject private var model: StatsModel
    @Environment(\.openSettings) private var openSettings
    /// Local copy of the snapshot kept in sync via `.onReceive`.
    /// Direct `@EnvironmentObject` observation is unreliable on macOS 26 beta;
    /// subscribing explicitly to `model.$snapshot` guarantees re-renders.
    @State private var snapshot: StatsSnapshot = .empty
    @State private var showLiveTrace = true
    @State private var showByCommand = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HSplitView {
            // Left: dashboard
            VStack(spacing: 0) {
                toolbar
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        statusBanners
                        if !snapshot.isDBMissing {
                            heroSection
                            chartSection
                            globalStatsSection
                            if showByCommand { topCommandsSection }
                        }
                    }
                    .padding(24)
                }
            }
            .background(.windowBackground)
            .frame(minWidth: 400)

            // Right: live trace panel (togglable)
            if showLiveTrace {
                CommandTraceView()
                    .frame(minWidth: 280)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            }
        }
        .task {
            await model.refresh()
        }
        .onReceive(model.$snapshot) { newSnapshot in
            snapshot = newSnapshot
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "diamond.fill")
                .foregroundStyle(Color.rtkEmerald)
                .font(.system(size: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("RTK Token Savings")
                    .font(.rtkDisplay(15, weight: .semibold))
                    .foregroundStyle(Color.rtkInk)
                Text(snapshot.isDBMissing ? "rtk not detected" : "Today · \(formattedDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { @MainActor in await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")
            .accessibilityLabel("Refresh stats")

            Divider().frame(height: 14)

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showByCommand.toggle() }
            } label: {
                Image(systemName: showByCommand ? "tablecells.fill" : "tablecells")
            }
            .buttonStyle(.plain)
            .opacity(showByCommand ? 1 : 0.4)
            .help(showByCommand ? "Hide By Command" : "Show By Command")
            .accessibilityLabel("By Command panel")
            .accessibilityValue(showByCommand ? "shown" : "hidden")

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showLiveTrace.toggle() }
            } label: {
                Image(systemName: showLiveTrace ? "terminal.fill" : "terminal")
            }
            .buttonStyle(.plain)
            .opacity(showLiveTrace ? 1 : 0.4)
            .help(showLiveTrace ? "Hide Live Trace" : "Show Live Trace")
            .accessibilityLabel("Live Trace panel")
            .accessibilityValue(showLiveTrace ? "shown" : "hidden")

            Divider().frame(height: 14)

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Bannières d'état

    @ViewBuilder
    private var statusBanners: some View {
        if snapshot.isDBMissing {
            StatusBanner(
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                message: "rtk not found — install rtk and run some commands to get started"
            )
        } else if snapshot.isInactive {
            let days = daysSinceLastActivity
            StatusBanner(
                icon: "clock.fill",
                color: .secondary,
                message: "No activity for \(days) day\(days > 1 ? "s" : "")"
            )
        }
    }

    // MARK: - Hero (signature: compression gauge + saved total)

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let g = snapshot.globalStats {
                CompressionGauge(input: g.totalInputTokens, output: g.totalOutputTokens)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(rtkFormatTokens(g.totalSavedTokens))
                            .font(.rtkDisplay(44, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.rtkInk)
                        Text("\(Int(g.avgSavingsPct))%")
                            .font(.rtkDisplay(20, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.rtkEmerald)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.rtkEmerald.opacity(0.12), in: Capsule())
                    }
                    Text("TOKENS SAVED · ALL TIME")
                        .font(.rtkLabel())
                        .tracking(1.4)
                        .foregroundStyle(Color.rtkSlate)
                }

                if let t = snapshot.todayStats {
                    HStack(spacing: 8) {
                        Text("TODAY")
                            .font(.rtkLabel(9))
                            .tracking(1.4)
                            .foregroundStyle(Color.rtkSlate)
                        Text("\(rtkFormatTokens(t.savedTokens)) saved  ·  \(t.totalCommands) cmds  ·  \(Int(t.savingsPct))%")
                            .font(.rtkData(11))
                            .foregroundStyle(Color.rtkSlate)
                    }
                }
            }
        }
    }

    // MARK: - Chart 7 jours

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Last 7 days")
                Spacer()
                if let last = snapshot.weekStats.last {
                    Text("\(Int(last.savingsPct))%")
                        .font(.rtkData(13))
                        .monospacedDigit()
                        .foregroundStyle(Color.rtkEmerald)
                }
            }
            if snapshot.weekStats.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                Chart {
                    ForEach(snapshot.weekStats, id: \.date) { stat in
                        AreaMark(
                            x: .value("Day", stat.date, unit: .day),
                            y: .value("Savings %", stat.savingsPct)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.rtkEmerald.opacity(0.2), Color.rtkEmerald.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Day", stat.date, unit: .day),
                            y: .value("Savings %", stat.savingsPct)
                        )
                        .foregroundStyle(Color.rtkEmerald)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    if let last = snapshot.weekStats.last {
                        PointMark(
                            x: .value("Day", last.date, unit: .day),
                            y: .value("Savings %", last.savingsPct)
                        )
                        .foregroundStyle(Color.rtkEmerald)
                        .symbolSize(36)
                    }
                }
                .chartYScale(domain: weekChartDomain)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow).locale(Locale(identifier: "en_US")))
                            .font(.caption2)
                            .foregroundStyle(Color.rtkMist)
                    }
                }
                .frame(height: 64)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Last 7 days savings trend")
                .accessibilityValue(weekAccessibilitySummary)
            }
        }
    }

    /// Padded min/max of the week's savings % so the sparkline shows the
    /// actual trend instead of flattening near the top of a fixed 0–100 scale.
    private var weekChartDomain: ClosedRange<Double> {
        let values = snapshot.weekStats.map(\.savingsPct)
        let lo = max(0, (values.min() ?? 0) - 5)
        let hi = min(100, (values.max() ?? 100) + 5)
        return lo < hi ? lo...hi : 0...100
    }

    private var weekAccessibilitySummary: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        fmt.locale = Locale(identifier: "en_US")
        return snapshot.weekStats
            .map { "\(fmt.string(from: $0.date)) \(Int($0.savingsPct))%" }
            .joined(separator: ", ")
    }

    // MARK: - Global stats

    private var globalStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("All time")
            if let g = snapshot.globalStats {
                VStack(spacing: 10) {
                    savedHighlightTile(
                        saved: g.totalSavedTokens,
                        pct: g.avgSavingsPct,
                        input: g.totalInputTokens,
                        output: g.totalOutputTokens
                    )
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        statTile(icon: "number", label: "Commands", value: "\(g.totalCommands)")
                        statTile(icon: "clock", label: "Exec time", value: formatDuration(g.totalExecTimeMs))
                        statTile(icon: "arrow.down.to.line.compact", label: "Input", value: formatTokens(g.totalInputTokens))
                        statTile(icon: "arrow.up.right", label: "Output", value: formatTokens(g.totalOutputTokens))
                    }
                }
            }
        }
    }

    /// The hero of the "All time" block: the saved total, emerald-emphasised,
    /// echoing the top-left signature so the section no longer reads as filler.
    private func savedHighlightTile(saved: Int, pct: Double, input: Int, output: Int) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOKENS SAVED")
                    .font(.rtkLabel(9)).tracking(1.4)
                    .foregroundStyle(Color.rtkEmerald)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formatTokens(saved))
                        .font(.rtkDisplay(26, weight: .bold)).monospacedDigit()
                        .foregroundStyle(Color.rtkInk)
                    Text("\(Int(pct))%")
                        .font(.rtkData(13))
                        .foregroundStyle(Color.rtkEmerald)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formatTokens(input)) → \(formatTokens(output))")
                    .font(.rtkData(12))
                    .foregroundStyle(Color.rtkSlate)
                Text("INPUT · OUTPUT")
                    .font(.rtkLabel(8)).tracking(1.2)
                    .foregroundStyle(Color.rtkMist)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.rtkEmerald.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.rtkEmerald.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tokens saved")
        .accessibilityValue("\(formatTokens(saved)), \(Int(pct)) percent, from \(formatTokens(input)) input to \(formatTokens(output)) output")
    }

    /// A neutral metric tile — icon + big mono value + label. No judgement
    /// colour (mist icon), reserving emerald for the savings story.
    private func statTile(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.rtkMist)
                .frame(width: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.rtkData(15)).monospacedDigit()
                    .foregroundStyle(Color.rtkInk)
                Text(label.uppercased())
                    .font(.rtkLabel(9)).tracking(1)
                    .foregroundStyle(Color.rtkSlate)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: - Top commands

    private var topCommandsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("By Command")
            if snapshot.topCommands.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("#").frame(width: 20, alignment: .leading)
                        Text("Command").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Count").frame(width: 42, alignment: .trailing)
                        Text("Saved").frame(width: 52, alignment: .trailing)
                        Text("Avg%").frame(width: 40, alignment: .trailing)
                        Text("Impact").frame(width: 72, alignment: .trailing)
                    }
                    .font(.rtkLabel(10))
                    .tracking(0.4)
                    .foregroundStyle(Color.rtkSlate)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)

                    ForEach(Array(snapshot.topCommands.enumerated()), id: \.offset) { idx, cmd in
                        HStack(spacing: 0) {
                            rankBadge(idx + 1)
                                .frame(width: 20, alignment: .leading)
                            Text(cmd.command)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(Color.rtkInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(cmd.count)")
                                .frame(width: 42, alignment: .trailing)
                                .foregroundStyle(Color.rtkSlate)
                            Text(formatTokens(cmd.totalSaved))
                                .frame(width: 52, alignment: .trailing)
                                .foregroundStyle(Color.rtkEmerald)
                            Text("\(Int(cmd.avgPct))%")
                                .frame(width: 40, alignment: .trailing)
                                .foregroundStyle(colorForPct(cmd.avgPct))
                            impactBar(cmd.impactRatio)
                                .frame(width: 72, alignment: .trailing)
                        }
                        .font(.rtkData(11))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(idx % 2 == 0 ? Color.primary.opacity(0.02) : Color.clear)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(cmd.command)
                        .accessibilityValue("\(cmd.count) runs, \(formatTokens(cmd.totalSaved)) saved, \(Int(cmd.avgPct))% average, impact \(Int(cmd.impactRatio * 100))%")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    /// Rank chip — the top three get an emerald halo, the rest stay neutral mist.
    private func rankBadge(_ n: Int) -> some View {
        Text("\(n)")
            .font(.rtkData(10))
            .foregroundStyle(n <= 3 ? Color.rtkEmerald : Color.rtkMist)
            .frame(width: 17, height: 17)
            .background(
                Circle().fill(n <= 3 ? Color.rtkEmerald.opacity(0.14) : Color.primary.opacity(0.04))
            )
    }

    private func impactBar(_ ratio: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.rtkEmerald.opacity(0.12))
                Capsule()
                    .fill(Color.rtkEmerald.opacity(0.55 + ratio * 0.45))
                    .frame(width: max(3, geo.size.width * ratio))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.rtkLabel(11))
            .tracking(1.6)
            .foregroundStyle(Color.rtkSlate)
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: Date())
    }

    private var daysSinceLastActivity: Int {
        guard let last = snapshot.lastActivityDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
    }

    private var savingsColor: Color {
        guard let pct = snapshot.todaySavingsPct else { return .secondary }
        return colorForPct(pct)
    }

    private func colorForPct(_ pct: Double) -> Color {
        rtkIntensity(pct)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }

    private func formatDuration(_ ms: Int) -> String {
        let totalSec = ms / 1000
        let minutes = totalSec / 60
        let seconds = totalSec % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}

// MARK: - KPICard

/// A metric display card showing a single KPI value with an icon and label.
///
/// The background and value color are tinted with `color` at reduced opacity
/// to create a cohesive, accessible appearance without overwhelming the layout.
private struct KPICard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - StatusBanner

/// A full-width alert banner for non-critical status messages.
///
/// Used for two states:
/// - **DB missing**: rtk is not installed or the database path is wrong.
/// - **Inactive**: no command has been recorded in the last 7 days.
private struct StatusBanner: View {
    let icon: String
    let color: Color
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
