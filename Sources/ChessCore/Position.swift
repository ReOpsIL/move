import Foundation

/// A full chess position with legal move generation, move application, FEN and SAN support.
public struct Position: Sendable, Hashable {
    public var board: [Piece?]
    public var sideToMove: PieceColor
    public var castling: CastlingRights
    public var epSquare: Int?
    public var halfmoveClock: Int
    public var fullmoveNumber: Int

    public static let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    public static let start = Position(fen: startFEN)!

    // MARK: FEN

    public init?(fen: String) {
        let parts = fen.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }
        var board = [Piece?](repeating: nil, count: 64)
        let rows = parts[0].split(separator: "/", omittingEmptySubsequences: false)
        guard rows.count == 8 else { return nil }
        for (i, row) in rows.enumerated() {
            let rank = 7 - i
            var file = 0
            for ch in row {
                if let n = ch.wholeNumberValue {
                    file += n
                } else {
                    guard let p = Piece(fenChar: ch), file < 8 else { return nil }
                    board[rank * 8 + file] = p
                    file += 1
                }
            }
            guard file == 8 else { return nil }
        }
        self.board = board
        switch parts[1] {
        case "w": sideToMove = .white
        case "b": sideToMove = .black
        default: return nil
        }
        var rights = CastlingRights()
        if parts.count > 2 {
            for ch in parts[2] {
                switch ch {
                case "K": rights.insert(.whiteKing)
                case "Q": rights.insert(.whiteQueen)
                case "k": rights.insert(.blackKing)
                case "q": rights.insert(.blackQueen)
                default: break
                }
            }
        }
        castling = rights
        epSquare = parts.count > 3 ? Square.parse(parts[3]) : nil
        halfmoveClock = parts.count > 4 ? Int(parts[4]) ?? 0 : 0
        fullmoveNumber = parts.count > 5 ? Int(parts[5]) ?? 1 : 1
    }

    public var fen: String {
        var rows: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = ""
            var empty = 0
            for file in 0..<8 {
                if let p = board[rank * 8 + file] {
                    if empty > 0 { row += String(empty); empty = 0 }
                    row.append(p.fenChar)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += String(empty) }
            rows.append(row)
        }
        var c = ""
        if castling.contains(.whiteKing) { c += "K" }
        if castling.contains(.whiteQueen) { c += "Q" }
        if castling.contains(.blackKing) { c += "k" }
        if castling.contains(.blackQueen) { c += "q" }
        if c.isEmpty { c = "-" }
        let ep = epSquare.map(Square.name) ?? "-"
        return "\(rows.joined(separator: "/")) \(sideToMove == .white ? "w" : "b") \(c) \(ep) \(halfmoveClock) \(fullmoveNumber)"
    }

    // MARK: Attacks

    private static let knightSteps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let kingSteps = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    private static let rookDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let bishopDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

    public func kingSquare(_ color: PieceColor) -> Int? {
        board.firstIndex { $0 == Piece(.king, color) }
    }

    /// Whether `sq` is attacked by any piece of color `by`.
    public func isAttacked(_ sq: Int, by: PieceColor) -> Bool {
        let f = Square.file(sq), r = Square.rank(sq)
        // Pawns
        let pr = by == .white ? r - 1 : r + 1
        for df in [-1, 1] {
            if let s = Square.make(file: f + df, rank: pr), board[s] == Piece(.pawn, by) { return true }
        }
        for (df, dr) in Self.knightSteps {
            if let s = Square.make(file: f + df, rank: r + dr), board[s] == Piece(.knight, by) { return true }
        }
        for (df, dr) in Self.kingSteps {
            if let s = Square.make(file: f + df, rank: r + dr), board[s] == Piece(.king, by) { return true }
        }
        for (dirs, kinds) in [(Self.rookDirs, [PieceKind.rook, .queen]), (Self.bishopDirs, [PieceKind.bishop, .queen])] {
            for (df, dr) in dirs {
                var cf = f + df, cr = r + dr
                while let s = Square.make(file: cf, rank: cr) {
                    if let p = board[s] {
                        if p.color == by && kinds.contains(p.kind) { return true }
                        break
                    }
                    cf += df; cr += dr
                }
            }
        }
        return false
    }

    public var inCheck: Bool {
        guard let k = kingSquare(sideToMove) else { return false }
        return isAttacked(k, by: sideToMove.opposite)
    }

    // MARK: Move generation

    public func pseudoLegalMoves() -> [Move] {
        var moves: [Move] = []
        moves.reserveCapacity(48)
        let us = sideToMove, them = us.opposite
        for from in 0..<64 {
            guard let p = board[from], p.color == us else { continue }
            let f = Square.file(from), r = Square.rank(from)
            switch p.kind {
            case .pawn:
                let dir = us == .white ? 1 : -1
                let startRank = us == .white ? 1 : 6
                let promoRank = us == .white ? 7 : 0
                func add(_ to: Int) {
                    if Square.rank(to) == promoRank {
                        for k in [PieceKind.queen, .rook, .bishop, .knight] { moves.append(Move(from: from, to: to, promotion: k)) }
                    } else {
                        moves.append(Move(from: from, to: to))
                    }
                }
                if let one = Square.make(file: f, rank: r + dir), board[one] == nil {
                    add(one)
                    if r == startRank, let two = Square.make(file: f, rank: r + 2 * dir), board[two] == nil {
                        moves.append(Move(from: from, to: two))
                    }
                }
                for df in [-1, 1] {
                    guard let to = Square.make(file: f + df, rank: r + dir) else { continue }
                    if let t = board[to], t.color == them { add(to) }
                    else if to == epSquare { moves.append(Move(from: from, to: to)) }
                }
            case .knight, .king:
                for (df, dr) in (p.kind == .knight ? Self.knightSteps : Self.kingSteps) {
                    guard let to = Square.make(file: f + df, rank: r + dr) else { continue }
                    if board[to]?.color != us { moves.append(Move(from: from, to: to)) }
                }
                if p.kind == .king { addCastling(from: from, into: &moves) }
            case .bishop, .rook, .queen:
                let dirs: [(Int, Int)] = p.kind == .bishop ? Self.bishopDirs : p.kind == .rook ? Self.rookDirs : Self.rookDirs + Self.bishopDirs
                for (df, dr) in dirs {
                    var cf = f + df, cr = r + dr
                    while let to = Square.make(file: cf, rank: cr) {
                        if let t = board[to] {
                            if t.color == them { moves.append(Move(from: from, to: to)) }
                            break
                        }
                        moves.append(Move(from: from, to: to))
                        cf += df; cr += dr
                    }
                }
            }
        }
        return moves
    }

    private func addCastling(from: Int, into moves: inout [Move]) {
        let us = sideToMove, them = us.opposite
        let base = us == .white ? 0 : 56
        guard from == base + 4 else { return }
        let kingSide: CastlingRights = us == .white ? .whiteKing : .blackKing
        let queenSide: CastlingRights = us == .white ? .whiteQueen : .blackQueen
        if castling.contains(kingSide), board[base + 7] == Piece(.rook, us),
           board[base + 5] == nil, board[base + 6] == nil,
           !isAttacked(base + 4, by: them), !isAttacked(base + 5, by: them), !isAttacked(base + 6, by: them) {
            moves.append(Move(from: from, to: base + 6))
        }
        if castling.contains(queenSide), board[base] == Piece(.rook, us),
           board[base + 1] == nil, board[base + 2] == nil, board[base + 3] == nil,
           !isAttacked(base + 4, by: them), !isAttacked(base + 3, by: them), !isAttacked(base + 2, by: them) {
            moves.append(Move(from: from, to: base + 2))
        }
    }

    public func legalMoves() -> [Move] {
        let us = sideToMove
        return pseudoLegalMoves().filter { m in
            let next = applying(m)
            guard let k = next.kingSquare(us) else { return true }
            return !next.isAttacked(k, by: us.opposite)
        }
    }

    public func legalMoves(from sq: Int) -> [Move] {
        legalMoves().filter { $0.from == sq }
    }

    public func isLegal(_ m: Move) -> Bool { legalMoves().contains(m) }

    public var isCheckmate: Bool { inCheck && legalMoves().isEmpty }
    public var isStalemate: Bool { !inCheck && legalMoves().isEmpty }

    public func isCastling(_ m: Move) -> Bool {
        board[m.from]?.kind == .king && abs(m.to - m.from) == 2
    }

    public func isEnPassant(_ m: Move) -> Bool {
        board[m.from]?.kind == .pawn && m.to == epSquare && Square.file(m.from) != Square.file(m.to) && board[m.to] == nil
    }

    public func isCapture(_ m: Move) -> Bool {
        board[m.to] != nil || isEnPassant(m)
    }

    // MARK: Making moves

    /// Applies a move (assumed pseudo-legal) and returns the resulting position.
    public func applying(_ m: Move) -> Position {
        var p = self
        guard let piece = board[m.from] else { return p }
        let us = piece.color
        let captured = board[m.to]
        let ep = isEnPassant(m)
        p.board[m.from] = nil
        if ep {
            p.board[m.to + (us == .white ? -8 : 8)] = nil
        }
        p.board[m.to] = m.promotion.map { Piece($0, us) } ?? piece
        if piece.kind == .king && abs(m.to - m.from) == 2 {
            if m.to > m.from {
                p.board[m.from + 1] = p.board[m.from + 3]
                p.board[m.from + 3] = nil
            } else {
                p.board[m.from - 1] = p.board[m.from - 4]
                p.board[m.from - 4] = nil
            }
        }
        for sq in [m.from, m.to] {
            switch sq {
            case 0: p.castling.remove(.whiteQueen)
            case 7: p.castling.remove(.whiteKing)
            case 4: p.castling.subtract([.whiteKing, .whiteQueen])
            case 56: p.castling.remove(.blackQueen)
            case 63: p.castling.remove(.blackKing)
            case 60: p.castling.subtract([.blackKing, .blackQueen])
            default: break
            }
        }
        if piece.kind == .pawn && abs(m.to - m.from) == 16 {
            p.epSquare = (m.from + m.to) / 2
        } else {
            p.epSquare = nil
        }
        p.halfmoveClock = (piece.kind == .pawn || captured != nil || ep) ? 0 : halfmoveClock + 1
        if us == .black { p.fullmoveNumber += 1 }
        p.sideToMove = us.opposite
        return p
    }

    // MARK: SAN

    public func san(_ m: Move) -> String {
        guard let piece = board[m.from] else { return m.uci }
        var s = ""
        if isCastling(m) {
            s = m.to > m.from ? "O-O" : "O-O-O"
        } else if piece.kind == .pawn {
            if isCapture(m) { s += String("abcdefgh"[String.Index(utf16Offset: Square.file(m.from), in: "abcdefgh")]) + "x" }
            s += Square.name(m.to)
            if let promo = m.promotion { s += "=" + promo.sanLetter }
        } else {
            s += piece.kind.sanLetter
            let others = legalMoves().filter { $0.to == m.to && $0.from != m.from && board[$0.from] == piece }
            if !others.isEmpty {
                let sameFile = others.contains { Square.file($0.from) == Square.file(m.from) }
                let sameRank = others.contains { Square.rank($0.from) == Square.rank(m.from) }
                let name = Square.name(m.from)
                if !sameFile { s += String(name.prefix(1)) }
                else if !sameRank { s += String(name.suffix(1)) }
                else { s += name }
            }
            if isCapture(m) { s += "x" }
            s += Square.name(m.to)
        }
        let next = applying(m)
        if next.inCheck { s += next.legalMoves().isEmpty ? "#" : "+" }
        return s
    }

    /// SAN for a sequence of moves starting from this position, with move numbers.
    public func sanLine(_ moves: [Move]) -> String {
        var pos = self
        var out: [String] = []
        for (i, m) in moves.enumerated() {
            let san = pos.san(m)
            if pos.sideToMove == .white {
                out.append("\(pos.fullmoveNumber). \(san)")
            } else if i == 0 {
                out.append("\(pos.fullmoveNumber)… \(san)")
            } else {
                out.append(san)
            }
            pos = pos.applying(m)
        }
        return out.joined(separator: " ")
    }

    // MARK: Perft (for testing)

    public func perft(_ depth: Int) -> Int {
        if depth == 0 { return 1 }
        let moves = legalMoves()
        if depth == 1 { return moves.count }
        return moves.reduce(0) { $0 + applying($1).perft(depth - 1) }
    }
}
