import SwiftUI
import ChessCore

struct BoardView: View {
    @ObservedObject var session: PuzzleSession
    @ObservedObject var settings: AppSettings

    @State private var dragFrom: Int?
    @State private var dragPoint: CGPoint?
    @State private var gestureActive = false
    @State private var wasSelected = false
    @State private var hintPulse = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let sq = side / 8
            ZStack(alignment: .topLeading) {
                squares(sq)
                if settings.showCoordinates { coordinates(sq) }
                moveDots(sq)
                pieces(sq)
                if let arrow = session.arrow { ArrowShape(from: center(arrow.from, sq), to: center(arrow.to, sq), width: sq * 0.17)
                    .fill(Color.orange.opacity(0.85))
                    .allowsHitTesting(false)
                }
                if session.pendingPromotion != nil { promotionPicker(sq) }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(dragGesture(sq))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { hintPulse = true } }
    }

    // MARK: Geometry

    private func cell(_ square: Int) -> (col: Int, row: Int) {
        let f = Square.file(square), r = Square.rank(square)
        return session.orientation == .white ? (f, 7 - r) : (7 - f, r)
    }

    private func center(_ square: Int, _ sq: CGFloat) -> CGPoint {
        let c = cell(square)
        return CGPoint(x: (CGFloat(c.col) + 0.5) * sq, y: (CGFloat(c.row) + 0.5) * sq)
    }

    private func square(at p: CGPoint, _ sq: CGFloat) -> Int? {
        let col = Int(floor(p.x / sq)), row = Int(floor(p.y / sq))
        guard (0..<8).contains(col), (0..<8).contains(row) else { return nil }
        return session.orientation == .white ? (7 - row) * 8 + col : row * 8 + (7 - col)
    }

    // MARK: Layers

    private func squares(_ sq: CGFloat) -> some View {
        let theme = settings.theme
        let checkSquare = session.position.inCheck ? session.position.kingSquare(session.position.sideToMove) : nil
        return ForEach(0..<64, id: \.self) { s in
            let c = cell(s)
            let light = (Square.file(s) + Square.rank(s)) % 2 == 1
            ZStack {
                Rectangle().fill(light ? theme.light : theme.dark)
                if let lm = session.lastMove, lm.from == s || lm.to == s {
                    Rectangle().fill(Color.yellow.opacity(0.38))
                }
                if session.selected == s || dragFrom == s {
                    Rectangle().fill(Color(red: 0.08, green: 0.47, blue: 0.2).opacity(0.45))
                }
                if session.hintSquare == s {
                    Rectangle().strokeBorder(Color.blue, lineWidth: sq * 0.08)
                        .background(Color.blue.opacity(hintPulse ? 0.35 : 0.12))
                }
                if checkSquare == s {
                    RadialGradient(colors: [Color.red.opacity(0.9), Color.red.opacity(0)], center: .center, startRadius: 0, endRadius: sq * 0.62)
                }
                if let f = session.flash, f.square == s {
                    Rectangle().fill((f.good ? Color.green : Color.red).opacity(0.5))
                }
            }
            .frame(width: sq, height: sq)
            .position(x: (CGFloat(c.col) + 0.5) * sq, y: (CGFloat(c.row) + 0.5) * sq)
        }
    }

    private func coordinates(_ sq: CGFloat) -> some View {
        let theme = settings.theme
        let files = Array("abcdefgh")
        return ZStack(alignment: .topLeading) {
            ForEach(0..<8, id: \.self) { i in
                // file letters on bottom row, rank numbers on left column (display coordinates)
                let fileIndex = session.orientation == .white ? i : 7 - i
                let rankIndex = session.orientation == .white ? 7 - i : i
                Text(String(files[fileIndex]))
                    .font(.system(size: sq * 0.2, weight: .semibold))
                    .foregroundColor((i % 2 == 0) ? theme.light : theme.dark)
                    .position(x: CGFloat(i) * sq + sq * 0.88, y: 8 * sq - sq * 0.14)
                Text("\(rankIndex + 1)")
                    .font(.system(size: sq * 0.2, weight: .semibold))
                    .foregroundColor((i % 2 == 0) ? theme.dark : theme.light)
                    .position(x: sq * 0.12, y: CGFloat(i) * sq + sq * 0.16)
            }
        }
        .allowsHitTesting(false)
    }

    private func moveDots(_ sq: CGFloat) -> some View {
        let from = dragFrom ?? session.selected
        let moves = (from != nil && session.canInteract) ? session.position.legalMoves(from: from!) : []
        let targets = Array(Set(moves.map(\.to)))
        return ForEach(targets, id: \.self) { t in
            Group {
                if session.position.board[t] != nil {
                    Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: sq * 0.09)
                } else {
                    Circle().fill(Color.black.opacity(0.22)).frame(width: sq * 0.32, height: sq * 0.32)
                }
            }
            .frame(width: sq, height: sq)
            .position(center(t, sq))
            .allowsHitTesting(false)
        }
    }

    private func pieces(_ sq: CGFloat) -> some View {
        ForEach(session.pieces) { bp in
            let dragging = bp.square == dragFrom && dragPoint != nil
            Image(nsImage: PieceImages.image(for: bp.piece))
                .resizable()
                .interpolation(.high)
                .frame(width: sq * (dragging ? 1.1 : 1), height: sq * (dragging ? 1.1 : 1))
                .shadow(color: .black.opacity(dragging ? 0.35 : 0.12), radius: dragging ? 4 : 1, y: dragging ? 3 : 1)
                .position(dragging ? dragPoint! : center(bp.square, sq))
                .zIndex(dragging ? 10 : 1)
                .allowsHitTesting(false)
        }
    }

    private func promotionPicker(_ sq: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 10) {
                Text("Promote to").font(.headline).foregroundColor(.white)
                HStack(spacing: 8) {
                    ForEach([PieceKind.queen, .rook, .bishop, .knight], id: \.self) { k in
                        Button { session.completePromotion(k) } label: {
                            Image(nsImage: PieceImages.image(for: Piece(k, session.userColor)))
                                .resizable().frame(width: sq * 1.1, height: sq * 1.1)
                                .background(RoundedRectangle(cornerRadius: 8).fill(settings.theme.light))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Cancel") { session.completePromotion(nil) }
            }
        }
        .frame(width: sq * 8, height: sq * 8)
    }

    // MARK: Input

    private func dragGesture(_ sq: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                guard session.canInteract, session.pendingPromotion == nil else { return }
                if !gestureActive {
                    gestureActive = true
                    if let s = square(at: v.startLocation, sq), let p = session.position.board[s], p.color == session.userColor {
                        wasSelected = session.selected == s
                        dragFrom = s
                        session.selected = s
                    }
                }
                if dragFrom != nil, hypot(v.translation.width, v.translation.height) > 3 {
                    dragPoint = v.location
                }
            }
            .onEnded { v in
                defer {
                    gestureActive = false
                    dragFrom = nil
                    dragPoint = nil
                }
                guard session.canInteract, session.pendingPromotion == nil else { return }
                let target = square(at: v.location, sq)
                if let from = dragFrom {
                    if let t = target, t != from {
                        session.attempt(from: from, to: t)
                    } else if wasSelected && dragPoint == nil {
                        session.selected = nil
                    }
                } else if let sel = session.selected, let t = target {
                    session.attempt(from: sel, to: t)
                } else {
                    session.selected = nil
                }
            }
    }
}

/// A filled arrow from one point to another.
struct ArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = max(hypot(dx, dy), 1)
        let ux = dx / len, uy = dy / len
        let px = -uy, py = ux
        let headLen = width * 2.4, headWidth = width * 1.6
        let start = CGPoint(x: from.x + ux * width * 1.2, y: from.y + uy * width * 1.2)
        let tip = CGPoint(x: to.x - ux * width * 0.6, y: to.y - uy * width * 0.6)
        let base = CGPoint(x: tip.x - ux * headLen, y: tip.y - uy * headLen)
        var p = Path()
        p.move(to: CGPoint(x: start.x + px * width / 2, y: start.y + py * width / 2))
        p.addLine(to: CGPoint(x: base.x + px * width / 2, y: base.y + py * width / 2))
        p.addLine(to: CGPoint(x: base.x + px * headWidth, y: base.y + py * headWidth))
        p.addLine(to: tip)
        p.addLine(to: CGPoint(x: base.x - px * headWidth, y: base.y - py * headWidth))
        p.addLine(to: CGPoint(x: base.x - px * width / 2, y: base.y - py * width / 2))
        p.addLine(to: CGPoint(x: start.x - px * width / 2, y: start.y - py * width / 2))
        p.closeSubpath()
        return p
    }
}
