import Foundation
import SwiftUI
import AppKit
import ChessCore

struct BoardPiece: Identifiable, Equatable {
    let id: Int
    var piece: Piece
    var square: Int
}

struct SquareFlash: Equatable {
    let square: Int
    let good: Bool
}

enum Feedback: Equatable {
    case none
    case info(String)
    case thinking(String)
    case ok(String)
    case notOK(String)
    case solved(String)
    case failed(String)
}

/// Drives a single puzzle: set-up move, judging the user's moves (book + engine), hints, answer, skip.
@MainActor
final class PuzzleSession: ObservableObject {
    enum State: Equatable { case idle, opponentMoving, awaitingUser, checking, finished(success: Bool) }

    @Published private(set) var puzzle: Puzzle?
    @Published private(set) var position = Position.start
    @Published private(set) var pieces: [BoardPiece] = []
    @Published private(set) var orientation: PieceColor = .white
    @Published private(set) var lastMove: Move?
    @Published var selected: Int?
    @Published private(set) var hintSquare: Int?
    @Published private(set) var arrow: Move?
    @Published private(set) var flash: SquareFlash?
    @Published private(set) var feedback: Feedback = .none
    @Published private(set) var state: State = .idle
    @Published private(set) var solutionLine: String?
    @Published var pendingPromotion: Move?

    let settings: AppSettings
    let engine: EngineService
    let store: PuzzleStore
    let stats: Stats

    private var setupPosition: Position?
    private var played: [Move] = []
    private var index = 0          // next book move index in puzzle.moves
    private var offBook = false    // user found an engine-approved alternative; engine now plays the opponent
    private var userMovesLeft = 0
    private var hadMistake = false
    private var usedHelp = false
    private var resultRecorded = false
    private var hintLevel = 0
    private var nextPieceID = 0
    private var generation = 0

    init(settings: AppSettings, engine: EngineService, store: PuzzleStore, stats: Stats) {
        self.settings = settings
        self.engine = engine
        self.store = store
        self.stats = stats
    }

    var userColor: PieceColor { orientation }
    var isFinished: Bool { if case .finished = state { return true }; return false }
    var isInProgress: Bool { puzzle != nil && !isFinished }
    var canInteract: Bool { state == .awaitingUser }

    // MARK: Loading

    func loadNext() {
        guard let p = store.random(in: settings.puzzleLevel.range, excluding: stats.seen) else {
            feedback = .info("No puzzles available for this level.")
            return
        }
        load(p)
    }

    func load(_ p: Puzzle) {
        generation += 1
        let gen = generation
        guard let pos = Position(fen: p.fen) else { return }
        stats.markSeen(p.id)
        puzzle = p
        position = pos
        orientation = pos.sideToMove.opposite
        resetPieces(from: pos)
        lastMove = nil
        selected = nil
        hintSquare = nil
        arrow = nil
        flash = nil
        pendingPromotion = nil
        solutionLine = nil
        played = []
        index = 0
        offBook = false
        userMovesLeft = p.moves.count / 2
        hadMistake = false
        usedHelp = false
        resultRecorded = false
        hintLevel = 0
        state = .opponentMoving
        feedback = .info("\(orientation.name) to play. Watch the opponent's move…")

        Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard gen == generation else { return }
            apply(p.moves[0], sound: true)
            setupPosition = position
            index = 1
            beginUserTurn(message: "\(orientation.name) to move — find the best move.")
        }
    }

    private func resetPieces(from pos: Position) {
        pieces = pos.board.enumerated().compactMap { sq, p in
            guard let p else { return nil }
            nextPieceID += 1
            return BoardPiece(id: nextPieceID, piece: p, square: sq)
        }
    }

    private func beginUserTurn(message: String?) {
        state = .awaitingUser
        hintLevel = 0
        hintSquare = nil
        arrow = nil
        if let message { feedback = .info(message) }
    }

    // MARK: Moves

    private func apply(_ m: Move, sound: Bool) {
        let before = position
        guard let mover = before.board[m.from] else { return }
        var pcs = pieces
        if before.isEnPassant(m) {
            let capSq = m.to + (mover.color == .white ? -8 : 8)
            pcs.removeAll { $0.square == capSq }
        }
        pcs.removeAll { $0.square == m.to }
        if before.isCastling(m) {
            let (rf, rt) = m.to > m.from ? (m.from + 3, m.from + 1) : (m.from - 4, m.from - 1)
            if let i = pcs.firstIndex(where: { $0.square == rf }) { pcs[i].square = rt }
        }
        if let i = pcs.firstIndex(where: { $0.square == m.from }) {
            pcs[i].square = m.to
            if let promo = m.promotion { pcs[i].piece = Piece(promo, mover.color) }
        }
        let capture = before.isCapture(m)
        withAnimation(.easeInOut(duration: 0.22)) {
            pieces = pcs
            position = before.applying(m)
            lastMove = m
        }
        played.append(m)
        if sound { play(capture ? "Pop" : "Tink") }
    }

    /// Called by the board when the user drops/clicks a piece onto a square.
    func attempt(from: Int, to: Int) {
        guard canInteract else { return }
        let candidates = position.legalMoves().filter { $0.from == from && $0.to == to }
        guard !candidates.isEmpty else { selected = nil; return }
        if candidates.count > 1 { // promotion choices
            pendingPromotion = Move(from: from, to: to)
            return
        }
        userMove(candidates[0])
    }

    func completePromotion(_ kind: PieceKind?) {
        guard let p = pendingPromotion else { return }
        pendingPromotion = nil
        guard let kind else { selected = nil; return }
        userMove(Move(from: p.from, to: p.to, promotion: kind))
    }

    private func userMove(_ m: Move) {
        guard canInteract, let puzzle, position.isLegal(m) else { return }
        let gen = generation
        let before = position
        let snapshot = (pieces, lastMove, played)
        selected = nil
        hintSquare = nil
        arrow = nil
        apply(m, sound: true)

        if position.isCheckmate { return accept(m, alternative: false) }
        if !offBook, index < puzzle.moves.count, m == puzzle.moves[index] { return accept(m, alternative: false) }

        guard engine.isAvailable, settings.acceptEngineAlternatives || offBook else {
            return reject(m, before: before, snapshot: snapshot, reason: "that's not the solution.")
        }
        state = .checking
        feedback = .thinking("Checking \(before.san(m)) with the engine…")
        let expected: Move? = offBook ? nil : puzzle.moves[index]
        Task {
            let verdict = await judge(before: before, user: m, expected: expected)
            guard gen == generation else { return }
            if verdict.ok {
                accept(m, alternative: expected != nil && m != expected)
            } else {
                reject(m, before: before, snapshot: snapshot, reason: verdict.reason)
            }
        }
    }

    private func judge(before: Position, user: Move, expected: Move?) async -> (ok: Bool, reason: String) {
        let san = before.san(user)
        let best: EngineResult?
        if let expected {
            best = await engine.search(before, only: [expected])
        } else {
            best = await engine.search(before)
            if best?.bestMove == user { return (true, "") }
        }
        let mine = await engine.search(before, only: [user])
        guard let b = best?.score, let u = mine?.score else { return (false, "that's not the solution.") }
        if Self.acceptable(user: u, best: b) { return (true, "") }
        let reason: String
        switch u {
        case .mate(let n) where n < 0:
            reason = "after \(san) you get mated in \(-n)."
        case .mate:
            reason = "\(san) mates, but there's a much faster win."
        case .cp(let c):
            let ev = String(format: "%+.1f", Double(c) / 100)
            if c < -150 { reason = "\(san) loses (engine: \(ev))." }
            else if c < 150 { reason = "after \(san) the position is roughly equal (\(ev)). There's more!" }
            else { reason = "\(san) is OK (\(ev)) but there's a much stronger move." }
        }
        return (false, reason)
    }

    /// Accepts an alternative move when it is (nearly) as good as the best line.
    static func acceptable(user u: EngineScore, best b: EngineScore) -> Bool {
        if case .mate(let n) = b, n > 0 {
            if case .mate(let k) = u, k > 0, k <= n + 1 { return true }
            return false
        }
        if u.isWinningMate { return true }
        let bv = b.value, uv = u.value
        let tolerance = max(80, bv / 4)
        return uv >= bv - tolerance
    }

    private func accept(_ m: Move, alternative: Bool) {
        let gen = generation
        if alternative { offBook = true }
        if !offBook { index += 1 }
        userMovesLeft -= 1
        flash = SquareFlash(square: m.to, good: true)
        play("Glass")

        let gameOver = position.legalMoves().isEmpty
        if userMovesLeft <= 0 || gameOver || (!offBook && index >= (puzzle?.moves.count ?? 0)) {
            return finish(success: !hadMistake && !usedHelp)
        }
        feedback = .ok(alternative ? "✓ OK — that works too! Keep going…" : "✓ OK — keep going…")
        state = .opponentMoving
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            guard gen == generation, let reply = await opponentReply(), gen == generation else {
                if gen == generation { finish(success: !hadMistake && !usedHelp) }
                return
            }
            flash = nil
            apply(reply, sound: true)
            if !offBook { index += 1 }
            beginUserTurn(message: nil)
            feedback = .ok("✓ OK — now find the next move.")
        }
    }

    private func opponentReply() async -> Move? {
        if offBook { return await engine.bestMove(position) }
        guard let puzzle, index < puzzle.moves.count else { return nil }
        return puzzle.moves[index]
    }

    private func reject(_ m: Move, before: Position, snapshot: ([BoardPiece], Move?, [Move]), reason: String) {
        let gen = generation
        if !hadMistake {
            hadMistake = true
            if !resultRecorded { stats.recordFailed(); resultRecorded = true }
        }
        flash = SquareFlash(square: m.to, good: false)
        feedback = .notOK("✗ Not OK — \(reason)")
        play("Basso")
        state = .checking
        Task {
            try? await Task.sleep(for: .milliseconds(1000))
            guard gen == generation else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                pieces = snapshot.0
                lastMove = snapshot.1
                position = before
            }
            played = snapshot.2
            flash = nil
            state = .awaitingUser
        }
    }

    private func finish(success: Bool, revealed: Bool = false) {
        state = .finished(success: success)
        hintSquare = nil
        if !resultRecorded {
            success ? stats.recordSolved() : stats.recordFailed()
            resultRecorded = true
        }
        if let setupPosition {
            solutionLine = setupPosition.sanLine(Array(played.dropFirst()))
        }
        if revealed {
            feedback = .failed("Here's the solution.")
        } else if success {
            feedback = .solved("Puzzle solved! 🎉")
            play("Hero")
        } else {
            feedback = .solved("Solved — with a little help.")
        }
    }

    // MARK: Help

    private func expectedMove() async -> Move? {
        if offBook { return await engine.bestMove(position) }
        guard let puzzle, index < puzzle.moves.count else { return nil }
        return puzzle.moves[index]
    }

    func hint() {
        guard canInteract else { return }
        let gen = generation
        usedHelp = true
        state = .checking
        Task {
            let m = await expectedMove()
            guard gen == generation else { return }
            state = .awaitingUser
            guard let m, let piece = position.board[m.from] else { return }
            if hintLevel == 0 {
                hintLevel = 1
                hintSquare = m.from
                let names = ["pawn", "knight", "bishop", "rook", "queen", "king"]
                var text = "Hint: use your \(names[piece.kind.rawValue]) on \(Square.name(m.from))."
                if let theme = puzzle?.themeLabels.first(where: { !["Opening", "Middlegame", "Endgame"].contains($0) }) {
                    text += " Theme: \(theme)."
                }
                feedback = .info(text)
            } else {
                hintLevel = 2
                hintSquare = m.from
                arrow = m
                feedback = .info("Hint: play the arrow move.")
            }
        }
    }

    func showAnswer() {
        guard canInteract, puzzle != nil else { return }
        generation += 1
        let gen = generation
        usedHelp = true
        if !resultRecorded { stats.recordFailed(); resultRecorded = true }
        state = .opponentMoving
        selected = nil
        hintSquare = nil
        feedback = .info("Showing the solution…")
        Task {
            // If a wrong move is still on the board, let the take-back finish first.
            while userMovesLeft > 0 {
                guard let m = await expectedMove(), gen == generation else { break }
                withAnimation { arrow = m }
                try? await Task.sleep(for: .milliseconds(650))
                guard gen == generation else { return }
                arrow = nil
                apply(m, sound: true)
                if !offBook { index += 1 }
                userMovesLeft -= 1
                if userMovesLeft <= 0 || position.legalMoves().isEmpty { break }
                try? await Task.sleep(for: .milliseconds(550))
                guard gen == generation, let reply = await opponentReply(), gen == generation else { break }
                apply(reply, sound: true)
                if !offBook { index += 1 }
                try? await Task.sleep(for: .milliseconds(450))
            }
            guard gen == generation else { return }
            finish(success: false, revealed: true)
        }
    }

    func skip() {
        if isInProgress && !resultRecorded { stats.recordSkipped() }
        loadNext()
    }

    // MARK: Sound

    private func play(_ name: String) {
        guard settings.sounds else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
