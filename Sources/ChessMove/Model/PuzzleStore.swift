import Foundation
import ChessCore

struct Puzzle: Identifiable, Hashable {
    let id: String
    let fen: String
    let moves: [Move] // moves[0] is the opponent's set-up move, then alternating solver/opponent
    let rating: Int
    let themes: [String]

    var lichessURL: URL { URL(string: "https://lichess.org/training/\(id)")! }

    /// Readable theme names (e.g. "mateIn2" -> "Mate in 2").
    var themeLabels: [String] {
        themes.compactMap { t in
            let hidden: Set = ["short", "long", "veryLong", "oneMove", "master", "masterVsMaster", "superGM", "advantage", "crushing"]
            if hidden.contains(t) { return nil }
            if t.hasPrefix("mateIn"), let n = Int(t.dropFirst(6)) { return "Mate in \(n)" }
            var out = ""
            for ch in t {
                if ch.isUppercase { out += " " + ch.lowercased() } else { out.append(ch) }
            }
            return out.prefix(1).uppercased() + out.dropFirst()
        }
    }
}

/// Bundled puzzles (subset of the CC0 Lichess puzzle database), grouped by rating.
final class PuzzleStore {
    private(set) var puzzles: [Puzzle] = []

    init() {
        guard let url = Self.dataURL(), let text = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("ChessMove: puzzles.csv not found")
            return
        }
        puzzles = text.split(separator: "\n").compactMap { line in
            let c = line.split(separator: ",", omittingEmptySubsequences: false)
            guard c.count >= 4, let rating = Int(c[3]) else { return nil }
            let moves = c[2].split(separator: " ").compactMap { Move(uci: String($0)) }
            guard moves.count >= 2 else { return nil }
            return Puzzle(id: String(c[0]), fen: String(c[1]), moves: moves, rating: rating,
                          themes: c.count > 4 ? c[4].split(separator: " ").map(String.init) : [])
        }
    }

    private static func dataURL() -> URL? {
        if let u = Bundle.main.url(forResource: "puzzles", withExtension: "csv") { return u }
        // Development fallback (swift run): <repo>/Resources/puzzles.csv
        let dev = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/puzzles.csv")
        return FileManager.default.fileExists(atPath: dev.path) ? dev : nil
    }

    func count(in range: ClosedRange<Int>) -> Int { puzzles.lazy.filter { range.contains($0.rating) }.count }

    /// A random puzzle in the rating range, preferring ones not yet seen.
    func random(in range: ClosedRange<Int>, excluding seen: Set<String>) -> Puzzle? {
        let candidates = puzzles.filter { range.contains($0.rating) }
        let fresh = candidates.filter { !seen.contains($0.id) }
        return (fresh.isEmpty ? candidates : fresh).randomElement()
    }
}
