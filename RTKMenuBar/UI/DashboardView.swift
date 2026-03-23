import SwiftUI
import Charts

struct DashboardView: View {

    @Environment(StatsModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusBanners
                    if !model.snapshot.isDBMissing {
                        kpisSection
                        chartSection
                        historySection
                    }
                }
                .padding(24)
            }
        }
        .background(.windowBackground)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
                .font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text("RTK Token Savings")
                    .font(.headline)
                Text(model.snapshot.isDBMissing ? "macrtk non détecté" : "Aujourd'hui · \(formattedDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Actualiser")

            Button("Préférences") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Bannières d'état

    @ViewBuilder
    private var statusBanners: some View {
        if model.snapshot.isDBMissing {
            StatusBanner(
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                message: "macrtk introuvable — installez macrtk et exécutez des commandes pour commencer"
            )
        } else if model.snapshot.isInactive {
            let days = daysSinceLastActivity
            StatusBanner(
                icon: "clock.fill",
                color: .secondary,
                message: "Aucune activité depuis \(days) jour\(days > 1 ? "s" : "")"
            )
        }
    }

    // MARK: - KPIs

    private var kpisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Aujourd'hui")
            HStack(spacing: 12) {
                KPICard(
                    value: model.snapshot.todayStats.map { formatTokens($0.savedTokens) } ?? "—",
                    label: "Tokens économisés",
                    icon: "arrow.down.circle.fill",
                    color: .green
                )
                KPICard(
                    value: model.snapshot.todayStats.map { "\($0.totalCommands)" } ?? "—",
                    label: "Commandes",
                    icon: "terminal.fill",
                    color: .blue
                )
                KPICard(
                    value: model.snapshot.todayStats.map { "\(Int($0.savingsPct))%" } ?? "—",
                    label: "Savings moy.",
                    icon: "percent",
                    color: savingsColor
                )
                KPICard(
                    value: model.snapshot.todayStats.map { formatTokens($0.inputTokens) } ?? "—",
                    label: "Tokens bruts",
                    icon: "doc.text.fill",
                    color: .secondary
                )
            }
        }
    }

    // MARK: - Chart 7 jours

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("7 derniers jours")
            if model.snapshot.weekStats.isEmpty {
                Text("Pas de données")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(model.snapshot.weekStats, id: \.date) { stat in
                    BarMark(
                        x: .value("Jour", stat.date, unit: .day),
                        y: .value("Savings %", stat.savingsPct)
                    )
                    .foregroundStyle(barColor(for: stat.savingsPct))
                    .cornerRadius(4)
                    PointMark(
                        x: .value("Jour", stat.date, unit: .day),
                        y: .value("Savings %", stat.savingsPct)
                    )
                    .foregroundStyle(barColor(for: stat.savingsPct))
                    .annotation(position: .top) {
                        Text("\(Int(stat.savingsPct))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%").font(.caption2) }
                        AxisGridLine(stroke: StrokeStyle(dash: [3, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(Locale(identifier: "fr_FR")))
                        AxisGridLine()
                    }
                }
                .frame(height: 160)
            }
        }
    }

    // MARK: - Historique récent

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Historique récent")
            if model.snapshot.recentCommands.isEmpty {
                Text("Aucune commande récente")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.snapshot.recentCommands, id: \.timestamp) { cmd in
                        HStack(spacing: 12) {
                            Text(cmd.originalCmd)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 6) {
                                Text("\(Int(cmd.savingsPct))%")
                                    .font(.caption.bold())
                                    .foregroundStyle(colorForPct(cmd.savingsPct))
                                    .frame(width: 36, alignment: .trailing)
                                Text(cmd.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundStyle(.primary)
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.locale = Locale(identifier: "fr_FR")
        return fmt.string(from: Date())
    }

    private var daysSinceLastActivity: Int {
        guard let last = model.snapshot.lastActivityDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
    }

    private var savingsColor: Color {
        guard let pct = model.snapshot.todaySavingsPct else { return .secondary }
        return colorForPct(pct)
    }

    private func colorForPct(_ pct: Double) -> Color {
        switch pct {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }

    private func barColor(for pct: Double) -> Color {
        colorForPct(pct).opacity(0.8)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - KPICard

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
