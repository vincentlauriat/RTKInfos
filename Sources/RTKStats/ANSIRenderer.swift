import Foundation

enum ANSI {
    static let clearScreen = "\u{1B}[2J\u{1B}[H"
    static let hideCursor  = "\u{1B}[?25l"
    static let showCursor  = "\u{1B}[?25h"

    static func bold(_ s: String)   -> String { "\u{1B}[1m\(s)\u{1B}[0m" }
    static func dim(_ s: String)    -> String { "\u{1B}[2m\(s)\u{1B}[0m" }
    static func red(_ s: String)    -> String { "\u{1B}[31m\(s)\u{1B}[0m" }
    static func green(_ s: String)  -> String { "\u{1B}[32m\(s)\u{1B}[0m" }
    static func yellow(_ s: String) -> String { "\u{1B}[33m\(s)\u{1B}[0m" }
    static func cyan(_ s: String)   -> String { "\u{1B}[36m\(s)\u{1B}[0m" }
}

struct Painter {
    let plain: Bool

    func bold(_ s: String)   -> String { plain ? s : ANSI.bold(s) }
    func dim(_ s: String)    -> String { plain ? s : ANSI.dim(s) }
    func red(_ s: String)    -> String { plain ? s : ANSI.red(s) }
    func green(_ s: String)  -> String { plain ? s : ANSI.green(s) }
    func yellow(_ s: String) -> String { plain ? s : ANSI.yellow(s) }
    func cyan(_ s: String)   -> String { plain ? s : ANSI.cyan(s) }
}

func formatTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.1fk", Double(n) / 1_000) }
    return String(n)
}

func weekBar(pcts: [Double], plain: Bool) -> String {
    let blocks = ["░", "▒", "▓", "█"]
    return pcts.map { pct in
        let idx = min(3, Int(pct / 25.0))
        let ch = blocks[idx]
        return plain ? ch : ANSI.green(ch)
    }.joined()
}

extension String {
    func padded(to width: Int) -> String {
        if count >= width { return String(prefix(width)) }
        return self + String(repeating: " ", count: width - count)
    }
}
