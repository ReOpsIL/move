import Foundation
import ChessCore

/// Engine score from the side-to-move's point of view.
enum EngineScore: Equatable, Sendable {
    case cp(Int)
    case mate(Int) // > 0: side to move mates in n; < 0: gets mated in n

    /// A single comparable number (mates dominate centipawns).
    var value: Int {
        switch self {
        case .cp(let c): return c
        case .mate(let n): return n > 0 ? 100_000 - n : -100_000 - n
        }
    }

    var isWinningMate: Bool { if case .mate(let n) = self, n > 0 { return true }; return false }

    /// Human readable from the perspective of the side that is about to move.
    var display: String {
        switch self {
        case .cp(let c): return String(format: "%+.1f", Double(c) / 100)
        case .mate(let n): return n > 0 ? "mate in \(n)" : "gets mated in \(-n)"
        }
    }
}

struct EngineResult: Sendable {
    var bestMove: Move?
    var score: EngineScore?
    var pv: [Move]
    var depth: Int
}

/// Thin, thread-safe UCI driver around a Stockfish process. Searches are serialized.
final class UCIEngine: @unchecked Sendable {
    let path: String
    private(set) var name = "UCI engine"
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let lock = NSLock()
    private var pending = ""
    private var onLine: ((String) -> Void)?
    private let work = DispatchQueue(label: "chessmove.engine")
    private(set) var isAlive = false

    init(path: String, threads: Int, hashMB: Int) throws {
        self.path = path
        process.executableURL = URL(fileURLWithPath: path)
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard let self, !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            self.consume(s)
        }
        process.terminationHandler = { [weak self] _ in self?.isAlive = false }
        try process.run()
        isAlive = true

        var gotName: String?
        let ok = runSync(["uci"], until: "uciok", timeout: 5) { line in
            if line.hasPrefix("id name ") { gotName = String(line.dropFirst(8)) }
        }
        guard ok else { stop(); throw NSError(domain: "UCIEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Engine did not answer 'uci'"]) }
        if let gotName { name = gotName }
        _ = runSync([
            "setoption name Threads value \(threads)",
            "setoption name Hash value \(hashMB)",
            "isready",
        ], until: "readyok", timeout: 10) { _ in }
    }

    deinit { stop() }

    func stop() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            send("quit")
            process.terminate()
        }
        isAlive = false
    }

    private func consume(_ s: String) {
        lock.lock()
        pending += s
        var lines: [String] = []
        while let idx = pending.firstIndex(of: "\n") {
            lines.append(String(pending[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines))
            pending = String(pending[pending.index(after: idx)...])
        }
        let cb = onLine
        lock.unlock()
        for l in lines where !l.isEmpty { cb?(l) }
    }

    private func send(_ cmd: String) {
        guard process.isRunning, let data = (cmd + "\n").data(using: .utf8) else { return }
        try? stdinPipe.fileHandleForWriting.write(contentsOf: data)
    }

    /// Sends commands and blocks until a line starting with `until` arrives.
    private func runSync(_ commands: [String], until: String, timeout: TimeInterval, handler: @escaping (String) -> Void) -> Bool {
        let sem = DispatchSemaphore(value: 0)
        lock.lock()
        onLine = { line in
            handler(line)
            if line.hasPrefix(until) { sem.signal() }
        }
        lock.unlock()
        commands.forEach(send)
        let result = sem.wait(timeout: .now() + timeout)
        if result == .timedOut, until == "bestmove" {
            // Make sure the engine returns to idle before the next search.
            send("stop")
            _ = sem.wait(timeout: .now() + 2)
        }
        lock.lock()
        onLine = nil
        lock.unlock()
        return result == .success
    }

    /// Searches `fen` for `movetimeMs`. When `searchMoves` is given only those root moves are considered,
    /// which yields the engine's score for a specific candidate move.
    func search(fen: String, movetimeMs: Int, searchMoves: [Move] = []) async -> EngineResult? {
        await withCheckedContinuation { cont in
            work.async {
                cont.resume(returning: self.searchSync(fen: fen, movetimeMs: movetimeMs, searchMoves: searchMoves))
            }
        }
    }

    private func searchSync(fen: String, movetimeMs: Int, searchMoves: [Move]) -> EngineResult? {
        guard isAlive else { return nil }
        var result = EngineResult(bestMove: nil, score: nil, pv: [], depth: 0)
        var go = "go movetime \(movetimeMs)"
        if !searchMoves.isEmpty { go += " searchmoves " + searchMoves.map(\.uci).joined(separator: " ") }
        let ok = runSync(["position fen \(fen)", go], until: "bestmove", timeout: Double(movetimeMs) / 1000 + 10) { line in
            if line.hasPrefix("info ") {
                Self.parseInfo(line, into: &result)
            } else if line.hasPrefix("bestmove ") {
                let parts = line.split(separator: " ")
                if parts.count > 1 { result.bestMove = Move(uci: String(parts[1])) }
            }
        }
        guard ok else { return nil }
        if result.bestMove == nil { result.bestMove = result.pv.first }
        return result
    }

    private static func parseInfo(_ line: String, into r: inout EngineResult) {
        let t = line.split(separator: " ").map(String.init)
        guard let si = t.firstIndex(of: "score"), si + 2 < t.count else { return }
        if let mi = t.firstIndex(of: "multipv"), mi + 1 < t.count, t[mi + 1] != "1" { return }
        if t.contains("lowerbound") || t.contains("upperbound") { return }
        guard let v = Int(t[si + 2]) else { return }
        r.score = t[si + 1] == "mate" ? .mate(v) : .cp(v)
        if let di = t.firstIndex(of: "depth"), di + 1 < t.count, let d = Int(t[di + 1]) { r.depth = d }
        if let pi = t.firstIndex(of: "pv") {
            r.pv = t[(pi + 1)...].compactMap(Move.init(uci:))
        }
    }

    /// Locates a Stockfish binary: bundled copy first, then common install locations.
    static func locate(customPath: String?) -> String? {
        var candidates: [String] = []
        if let c = customPath, !c.isEmpty { candidates.append((c as NSString).expandingTildeInPath) }
        if let r = Bundle.main.resourceURL { candidates.append(r.appendingPathComponent("stockfish").path) }
        candidates += ["/opt/homebrew/bin/stockfish", "/usr/local/bin/stockfish", "/usr/bin/stockfish"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
