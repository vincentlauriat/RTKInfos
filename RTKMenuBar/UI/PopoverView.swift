import SwiftUI
import Charts

struct PopoverView: View {

    @Environment(StatsModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusBanners
                    if !model.snapshot.isDBMissing {
                        kpisSection
                        chartSection
                        historySection
                    }
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
            Text("RTK Token Savings")
                .font(.headline)
            Spacer()
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Bannières d'état

    @ViewBuilder
    private var statusBanners: some View {
        if model.snapshot.isDBMissing {
            StatusBanner(
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                message: "macrtk introuvable — installez macrtk pour commencer"
            )
        } else if model.snapshot.isInactive {
            let days = daysSinceLastActivity
            StatusBanner(
                icon: "clock.fill",
                color: .gray,
                message: "Aucune activité depuis \(days) jour\(days > 1 ? "s" : "")"
            )
        }
    }

    private var daysSinceLastActivity: Int {
        guard let last = model.snapshot.lastActivityDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
    }

    // MARK: - KPIs

    private var kpisSection: some View {
        HStack(spacing: 12) {
            KPICard(
                value: model.snapshot.todayStats.map { formatTokens($0.savedTokens) } ?? "—",
                label: "Tokens économisés",
                color: .green
            )
            KPICard(
                value: model.snapshot.todayStats.map { "\($0.totalCommands)" } ?? "—",
                label: "Commandes",
                color: .blue
            )
            KPICard(
                value: model.snapshot.todayStats.map { "\(Int($0.savingsPct))%" } ?? "—",
                label: "Savings",
                color: savingsColor
            )
        }
    }

    private var savingsColor: Color {
        guard let pct = model.snapshot.todaySavingsPct else { return .secondary }
        switch pct {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }

    // MARK: - Chart 7 jours

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7 derniers jours")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if model.snapshot.weekStats.isEmpty {
                Text("Pas de données")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart(model.snapshot.weekStats, id: \.date) { stat in
                    BarMark(
                        x: .value("Jour", stat.date, unit: .day),
                        y: .value("Savings %", stat.savingsPct)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .frame(height: 100)
            }
        }
    }

    // MARK: - Historique récent

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Historique récent")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if model.snapshot.recentCommands.isEmpty {
                Text("Aucune commande récente")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(model.snapshot.recentCommands, id: \.timestamp) { cmd in
                    HStack {
                        Text(cmd.originalCmd)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(Int(cmd.savingsPct))% saved")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Préférences") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Composants réutilisables

private struct KPICard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatusBanner: View {
    let icon: String
    let color: Color
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
