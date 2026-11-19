import AppKit
import ChessCore

/// Renders crisp piece images from the Apple Symbols chess glyphs (no external artwork needed).
@MainActor
enum PieceImages {
    private static var cache: [Piece: NSImage] = [:]
    private static let solid: [PieceKind: String] = [.king: "♚", .queen: "♛", .rook: "♜", .bishop: "♝", .knight: "♞", .pawn: "♟\u{FE0E}"]
    private static let outline: [PieceKind: String] = [.king: "♔", .queen: "♕", .rook: "♖", .bishop: "♗", .knight: "♘", .pawn: "♙"]

    static func image(for piece: Piece) -> NSImage {
        if let img = cache[piece] { return img }
        let size: CGFloat = 128
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let font = NSFont(name: "Apple Symbols", size: size * 0.95) ?? NSFont.systemFont(ofSize: size * 0.8)
            func draw(_ s: String, _ attrs: [NSAttributedString.Key: Any]) {
                var all = attrs
                all[.font] = font
                let a = NSAttributedString(string: s, attributes: all)
                let b = a.size()
                a.draw(at: NSPoint(x: (size - b.width) / 2, y: (size - b.height) / 2 + size * 0.03))
            }
            let s = solid[piece.kind]!, o = outline[piece.kind]!
            if piece.color == .white {
                draw(s, [.foregroundColor: NSColor.white])
                draw(o, [.foregroundColor: NSColor(white: 0.05, alpha: 1)])
            } else {
                let ink = NSColor(white: 0.1, alpha: 1)
                draw(s, [.foregroundColor: ink])
                draw(o, [.foregroundColor: NSColor(white: 0.45, alpha: 1)])
                draw(s, [.foregroundColor: NSColor.clear, .strokeColor: ink, .strokeWidth: 3])
            }
            return true
        }
        cache[piece] = img
        return img
    }

    /// Template image of a knight for the menu bar.
    static func menuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            let font = NSFont(name: "Apple Symbols", size: 19) ?? NSFont.systemFont(ofSize: 16)
            let a = NSAttributedString(string: "♞", attributes: [.font: font, .foregroundColor: NSColor.black])
            let b = a.size()
            a.draw(at: NSPoint(x: (size.width - b.width) / 2, y: (size.height - b.height) / 2 + 1))
            return true
        }
        img.isTemplate = true
        return img
    }
}
