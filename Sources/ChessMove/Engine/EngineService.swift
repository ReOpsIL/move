import Foundation
import ChessCore

/// Main-actor facade over the UCI engine: lifecycle + status for the UI.
@MainActor
final class EngineService: ObservableObject {
    @Published private(set) var status = "Starting engine…"
    @Published private(set) var isAvailable = false
    private var engine: UCIEngine?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        engine?.stop()
        engine = nil
        isAvailable = false
        guard let path = UCIEngine.locate(customPath: settings.customEnginePath) else {
            status = "Stockfish not found — only exact solutions are accepted"
            return
        }
        status = "Starting engine…"
        let threads = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount / 2))
        Task.detached(priority: .userInitiated) {
            do {
                let e = try UCIEngine(path: path, threads: threads, hashMB: 64)
                await MainActor.run {
                    self.engine = e
                    self.isAvailable = true
                    self.status = e.name
                }
            } catch {
                await MainActor.run { self.status = "Engine failed: \(error.localizedDescription)" }
            }
        }
    }

    func shutdown() { engine?.stop() }

    func search(_ position: Position, only moves: [Move] = [], movetimeMs: Int? = nil) async -> EngineResult? {
        guard let engine else { return nil }
        if !engine.isAlive {
            start()
            return nil
        }
        return await engine.search(fen: position.fen, movetimeMs: movetimeMs ?? settings.strength.movetimeMs, searchMoves: moves)
    }

    func bestMove(_ position: Position) async -> Move? {
        guard let m = await search(position)?.bestMove, position.isLegal(m) else { return nil }
        return m
    }
}
