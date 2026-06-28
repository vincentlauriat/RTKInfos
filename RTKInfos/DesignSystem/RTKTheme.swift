import SwiftUI
import AppKit
import CoreText

// MARK: - Font registration

/// Registers the embedded Geist / Geist Mono variable fonts with the process
/// font manager. Called once at launch (before any view renders) so that
/// `Font.custom("Geist", …)` resolves. Falls back silently to system fonts if
/// a file is missing.
enum RTKFonts {
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true
        for name in ["Geist", "GeistMono"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Color tokens

extension Color {
    /// Builds an appearance-adaptive color from two sRGB hex values.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    /// Primary text, large numbers.
    static let rtkInk     = adaptive(light: 0x16191D, dark: 0xECEFF2)
    /// Secondary text, labels.
    static let rtkSlate   = adaptive(light: 0x5B6470, dark: 0x9AA3AE)
    /// Tertiary text, neutral / low-signal state.
    static let rtkMist    = adaptive(light: 0x9AA3AE, dark: 0x5B6470)
    /// The single accent — the "killed" tokens. Never paired with red/orange.
    static let rtkEmerald = adaptive(light: 0x12B886, dark: 0x1FD79B)
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: Double((hex >> 16) & 0xFF) / 255,
            green:   Double((hex >> 8) & 0xFF) / 255,
            blue:    Double(hex & 0xFF) / 255,
            alpha:   1
        )
    }
}

// MARK: - Typography

extension Font {
    /// Display face — large numbers. Geist, tabular figures applied at call site.
    static func rtkDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Geist", size: size).weight(weight)
    }
    /// Utility label — UPPERCASE with tracking applied at call site.
    static func rtkLabel(_ size: CGFloat = 11, weight: Font.Weight = .medium) -> Font {
        .custom("Geist", size: size).weight(weight)
    }
    /// Data face — values, command table, live trace.
    static func rtkData(_ size: CGFloat = 12) -> Font {
        .custom("Geist Mono", size: size)
    }
}

// MARK: - Savings intensity (replaces the tricolor colorForPct)

/// Maps a savings percentage to an emerald *intensity*. Low-signal commands
/// (passthrough, < 35 %) read as neutral mist — never judged — while real
/// savings ramp up the emerald. No red, no orange, ever.
func rtkIntensity(_ pct: Double) -> Color {
    let t = min(1, max(0, pct / 100))
    if t < 0.35 { return .rtkMist }
    return Color.rtkEmerald.opacity(0.55 + (t - 0.35) / 0.65 * 0.45)
}

// MARK: - Shared formatting

/// Compact token count: 1_234_567 → "1.2M", 12_345 → "12.3k".
func rtkFormatTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.1fk", Double(n) / 1_000) }
    return "\(n)"
}
