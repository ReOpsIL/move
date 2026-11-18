import Foundation

public enum PieceColor: Int, Sendable, Hashable {
    case white = 0, black = 1
    public var opposite: PieceColor { self == .white ? .black : .white }
    public var name: String { self == .white ? "White" : "Black" }
}

public enum PieceKind: Int, CaseIterable, Sendable, Hashable {
    case pawn, knight, bishop, rook, queen, king

    public var sanLetter: String { ["", "N", "B", "R", "Q", "K"][rawValue] }
    public var fenLetter: Character { ["p", "n", "b", "r", "q", "k"][rawValue] }

    public init?(letter: Character) {
        switch letter.lowercased() {
        case "p": self = .pawn
        case "n": self = .knight
        case "b": self = .bishop
        case "r": self = .rook
        case "q": self = .queen
        case "k": self = .king
        default: return nil
        }
    }
}

public struct Piece: Hashable, Sendable {
    public let kind: PieceKind
    public let color: PieceColor
    public init(_ kind: PieceKind, _ color: PieceColor) {
        self.kind = kind
        self.color = color
    }

    public init?(fenChar: Character) {
        guard let k = PieceKind(letter: fenChar) else { return nil }
        self.init(k, fenChar.isUppercase ? .white : .black)
    }

    public var fenChar: Character {
        color == .white ? Character(String(kind.fenLetter).uppercased()) : kind.fenLetter
    }
}

/// Squares are 0...63 with a1 = 0, b1 = 1, ..., h8 = 63.
public enum Square {
    public static func file(_ s: Int) -> Int { s & 7 }
    public static func rank(_ s: Int) -> Int { s >> 3 }
    public static func make(file: Int, rank: Int) -> Int? {
        (0..<8).contains(file) && (0..<8).contains(rank) ? rank * 8 + file : nil
    }
    public static func name(_ s: Int) -> String {
        let files = Array("abcdefgh")
        return "\(files[file(s)])\(rank(s) + 1)"
    }
    public static func parse<S: StringProtocol>(_ str: S) -> Int? {
        let c = Array(str)
        guard c.count == 2,
              let f = "abcdefgh".firstIndex(of: c[0]).map({ "abcdefgh".distance(from: "abcdefgh".startIndex, to: $0) }),
              let r = c[1].wholeNumberValue, (1...8).contains(r) else { return nil }
        return (r - 1) * 8 + f
    }
}

public struct Move: Hashable, Sendable, CustomStringConvertible {
    public let from: Int
    public let to: Int
    public let promotion: PieceKind?

    public init(from: Int, to: Int, promotion: PieceKind? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }

    public init?(uci: String) {
        let s = Array(uci)
        guard s.count == 4 || s.count == 5,
              let f = Square.parse(String(s[0...1])),
              let t = Square.parse(String(s[2...3])) else { return nil }
        var promo: PieceKind? = nil
        if s.count == 5 {
            guard let p = PieceKind(letter: s[4]), p != .pawn, p != .king else { return nil }
            promo = p
        }
        self.init(from: f, to: t, promotion: promo)
    }

    public var uci: String {
        Square.name(from) + Square.name(to) + (promotion.map { String($0.fenLetter) } ?? "")
    }

    public var description: String { uci }
}

public struct CastlingRights: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let whiteKing = CastlingRights(rawValue: 1)
    public static let whiteQueen = CastlingRights(rawValue: 2)
    public static let blackKing = CastlingRights(rawValue: 4)
    public static let blackQueen = CastlingRights(rawValue: 8)
}
