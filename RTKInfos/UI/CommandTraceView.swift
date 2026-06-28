import SwiftUI

/// A live-scrolling trace panel showing the most recent rtk commands.
///
/// Displays up to 50 commands newest-first, auto-scrolling to the top
/// whenever a new command is detected by `StatsModel`.
struct CommandTraceView: View {

    @EnvironmentObject private var model: StatsModel
    @State private var snapshot: StatsSnapshot = .empty
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if snapshot.recentCommands.isEmpty {
                emptyState
            } else {
                traceList
            }
        }
        .background(.windowBackground)
        .onReceive(model.$snapshot) { newSnapshot in
            snapshot = newSnapshot
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(snapshot.isDBMissing ? Color.rtkMist : Color.rtkEmerald)
                .frame(width: 7, height: 7)
                .scaleEffect(pulse ? 1.9 : 1)
                .opacity(pulse ? 1 : 0.85)
            Text("LIVE TRACE")
                .font(.rtkLabel(11))
                .tracking(1.5)
                .foregroundStyle(Color.rtkSlate)
            Spacer()
            Text("\(snapshot.recentCommands.count) cmds")
                .font(.rtkData(10))
                .foregroundStyle(Color.rtkMist)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onChange(of: snapshot.recentCommands.count) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.easeIn(duration: 0.1)) { pulse = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { pulse = false }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text("No commands yet")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Trace list

    private var traceList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(snapshot.recentCommands, id: \.timestamp) { cmd in
                        TraceRow(cmd: cmd)
                            .id(cmd.timestamp)
                    }
                }
            }
            .onChange(of: snapshot.recentCommands.count) { _, _ in
                if let first = snapshot.recentCommands.first {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(first.timestamp, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - TraceRow

/// A single row in the trace panel showing timestamp, command, and savings %.
private struct TraceRow: View {

    let cmd: CommandRecord

    var body: some View {
        HStack(spacing: 8) {
            Text(timeString)
                .font(.rtkData(10))
                .foregroundStyle(Color.rtkMist)
                .frame(width: 54, alignment: .leading)

            Text(cmd.originalCmd)
                .font(.rtkData(11))
                .foregroundStyle(Color.rtkInk)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(Int(cmd.savingsPct))%")
                .font(.rtkData(11))
                .foregroundStyle(savingsColor)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(rowBackground)
    }

    private var savingsColor: Color {
        rtkIntensity(cmd.savingsPct)
    }

    private var rowBackground: Color {
        Color.primary.opacity(0.02)
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: cmd.timestamp)
    }
}
