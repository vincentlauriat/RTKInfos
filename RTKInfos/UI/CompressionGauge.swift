import SwiftUI

/// The signature element of RTKInfos.
///
/// A single horizontal bar that tells the product's whole story: the raw `input`
/// is compressed down to `output`, and the space RTK reclaimed — the *killed*
/// tokens — is painted in emerald. On appearance the output block animates from
/// full width down to its real size, so the eye sees the compression happen.
///
/// This is the one place the design "spends its boldness"; everything around it
/// stays quiet.
struct CompressionGauge: View {

    let input: Int
    let output: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var compressed = false

    private var saved: Int { max(0, input - output) }
    private var outputRatio: Double {
        guard input > 0 else { return 0 }
        return min(1, Double(output) / Double(input))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPRESSION")
                .font(.rtkLabel())
                .tracking(1.6)
                .foregroundStyle(Color.rtkSlate)

            GeometryReader { geo in
                let w = geo.size.width
                let outWidth = compressed ? max(4, w * outputRatio) : w
                ZStack(alignment: .leading) {
                    // Full track = the raw input footprint.
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.rtkEmerald.opacity(0.14))
                    // The reclaimed span carries the count.
                    Text("\(rtkFormatTokens(saved)) killed")
                        .font(.rtkData(11))
                        .foregroundStyle(Color.rtkEmerald)
                        .frame(maxWidth: .infinity)
                        .opacity(compressed ? 1 : 0)
                    // The output block — what actually remains.
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.rtkEmerald)
                        .frame(width: outWidth)
                }
            }
            .frame(height: 30)

            HStack(spacing: 0) {
                endLabel(value: rtkFormatTokens(input), caption: "INPUT", align: .leading)
                Spacer()
                endLabel(value: rtkFormatTokens(output), caption: "OUTPUT", align: .trailing)
            }
        }
        .onAppear {
            guard !compressed else { return }
            if reduceMotion {
                compressed = true
            } else {
                withAnimation(.easeOut(duration: 0.65).delay(0.12)) { compressed = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Compression")
        .accessibilityValue("\(rtkFormatTokens(input)) input compressed to \(rtkFormatTokens(output)) output, \(rtkFormatTokens(saved)) tokens killed")
    }

    private func endLabel(value: String, caption: String, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 1) {
            Text(value)
                .font(.rtkData(13))
                .foregroundStyle(Color.rtkInk)
            Text(caption)
                .font(.rtkLabel(9))
                .tracking(1.2)
                .foregroundStyle(Color.rtkSlate)
        }
    }
}

#Preview("Compression") {
    VStack(spacing: 24) {
        CompressionGauge(input: 26_900_000, output: 9_100_000)
        CompressionGauge(input: 1000, output: 850)
    }
    .padding(24)
    .frame(width: 420)
}
