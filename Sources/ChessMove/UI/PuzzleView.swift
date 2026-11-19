import SwiftUI
import ChessCore

struct PuzzleView: View {
    @ObservedObject var session: PuzzleSession
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: Stats
    @ObservedObject var engine: EngineService
    var onClose: () -> Void
    var onSettings: () -> Void
    /// Window-move gestures, handled by the app delegate (which owns the panel).
    var onMove: (PanelMove) -> Void = { _ in }

    @State private var resizeStart: (mouse: CGPoint, size: Double)?
    @State private var hoveringHeader = false

    private var boardSize: CGFloat { CGFloat(settings.boardSize) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
                .padding(.top, 6)
                .contentShape(Rectangle())
                .gesture(moveGesture)
            board
            statusRow
            levelChips
            Rectangle().fill(Ink.hairline).frame(height: 1)
            footer
        }
        .padding(20)
        .frame(width: boardSize + 40)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Ink.hairline, lineWidth: 1)
        )
        .overlay(alignment: .top) { grabBar }
        .overlay(alignment: .bottomTrailing) { resizeGrip }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    // MARK: Move & resize

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { _ in onMove(.dragChanged) }
            .onEnded { _ in onMove(.dragEnded) }
    }

    /// Small handle at the top: drag to move, double-click to snap back under the menu-bar icon.
    private var grabBar: some View {
        Capsule()
            .fill(Color.white.opacity(hoveringHeader ? 0.35 : 0.16))
            .frame(width: 38, height: 4)
            .padding(.vertical, 7)
            .padding(.horizontal, 30)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onMove(.resetPosition) }
            .gesture(moveGesture)
            .onHover { inside in
                hoveringHeader = inside
                if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
            }
            .help("Drag to move · double-click to put back under the menu-bar icon")
    }

    /// Bottom-right grip: drag to scale the board (and the whole panel).
    private var resizeGrip: some View {
        Canvas { ctx, size in
            for i in 0..<3 {
                let o = CGFloat(i) * 4
                var p = Path()
                p.move(to: CGPoint(x: size.width - 2 - o, y: size.height - 2))
                p.addLine(to: CGPoint(x: size.width - 2, y: size.height - 2 - o))
                ctx.stroke(p, with: .color(Color.white.opacity(0.3)), lineWidth: 1.2)
            }
        }
        .frame(width: 14, height: 14)
        .padding(6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { _ in
                    let mouse = NSEvent.mouseLocation
                    if resizeStart == nil { resizeStart = (mouse, settings.boardSize) }
                    guard let start = resizeStart else { return }
                    // Right and down both grow the board (screen y grows upwards).
                    let delta = ((mouse.x - start.mouse.x) + (start.mouse.y - mouse.y)) / 2
                    let maxSize = min(AppSettings.boardSizeRange.upperBound,
                                      Double((NSScreen.main?.visibleFrame.height ?? 900) - 330))
                    let size = (start.size + delta).clamped(to: AppSettings.boardSizeRange.lowerBound...max(maxSize, AppSettings.boardSizeRange.lowerBound))
                    settings.boardSize = size.rounded()
                }
                .onEnded { _ in resizeStart = nil }
        )
        .onHover { inside in
            if inside { resizeCursor.push() } else { NSCursor.pop() }
        }
        .help("Drag to resize")
    }

    private var resizeCursor: NSCursor {
        if #available(macOS 15.0, *) { return NSCursor.frameResize(position: .bottomRight, directions: .all) }
        return NSCursor.crosshair
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(Ink.eyebrow)
                    .tracking(1.4)
                    .foregroundStyle(Ink.accent)
                HStack(spacing: 10) {
                    if session.puzzle != nil { sideDisc(session.userColor, size: 26) }
                    Text(title)
                        .font(Ink.title(32))
                        .foregroundStyle(Ink.text)
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Ink.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Button(action: onSettings) { Image(systemName: "gearshape") }
                    .buttonStyle(IconStyle())
                    .help("Settings")
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(IconStyle())
                    .keyboardShortcut(.cancelAction)
                    .help("Close (Esc)")
            }
        }
    }

    private var eyebrow: String {
        let level = settings.puzzleLevel.name.uppercased()
        guard let p = session.puzzle else { return "CHESS MOVE · \(level)" }
        return "PUZZLE · \(level) · \(p.rating)"
    }

    private var title: String {
        guard session.puzzle != nil else { return "Chess Move" }
        return "\(session.userColor.name) to move"
    }

    private var subtitle: String {
        guard let p = session.puzzle else { return "A fresh puzzle, whenever you like" }
        let n = p.moves.count / 2
        return "From a real game · \(n) move\(n == 1 ? "" : "s") to find"
    }

    // MARK: Board

    private var board: some View {
        BoardView(session: session, settings: settings)
            .frame(width: boardSize, height: boardSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
    }

    // MARK: Status + actions

    private var statusRow: some View {
        HStack(spacing: 14) {
            if session.isFinished {
                Button { session.loadNext() } label: { Image(systemName: "arrow.right") }
                    .buttonStyle(PrimaryCircleStyle())
                    .keyboardShortcut(.defaultAction)
                    .help("Next puzzle (Return)")
                if let p = session.puzzle {
                    Link(destination: p.lichessURL) { Image(systemName: "arrow.up.right") }
                        .buttonStyle(SecondaryCircleStyle())
                        .help("Open on Lichess")
                }
            } else {
                Button { session.hint() } label: { Image(systemName: "lightbulb.fill") }
                    .buttonStyle(PrimaryCircleStyle())
                    .keyboardShortcut("h", modifiers: [])
                    .disabled(!session.canInteract)
                    .help("Hint (H). Press twice for an arrow")
                Button { session.showAnswer() } label: { Image(systemName: "eye") }
                    .buttonStyle(SecondaryCircleStyle())
                    .keyboardShortcut("a", modifiers: [])
                    .disabled(!session.canInteract)
                    .help("Show the answer (A)")
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(statusTitle)
                        .font(Ink.title(26))
                        .foregroundStyle(statusColor)
                    if case .thinking = session.feedback {
                        ProgressView().controlSize(.small).tint(Ink.accent)
                    }
                }
                Text(statusDetail)
                    .font(.system(size: 12, design: session.isFinished ? .monospaced : .default))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(height: 54, alignment: .leading)
            .animation(.easeOut(duration: 0.15), value: session.feedback)
            Spacer(minLength: 0)
        }
    }

    private var statusTitle: String {
        switch session.feedback {
        case .none: return "Ready"
        case .info: return session.state == .opponentMoving ? "\(opponent) moves…" : "\(me)'s move"
        case .thinking: return "Checking"
        case .ok: return session.state == .opponentMoving ? "OK · \(opponent) replies" : "OK · \(me) again"
        case .notOK: return "Not OK"
        case .solved: return "Solved"
        case .failed: return "Solution"
        }
    }

    private var me: String { session.userColor.name }
    private var opponent: String { session.userColor.opposite.name }

    /// A small king in the colour of the side to move, on a light tile so black stays visible.
    private func sideDisc(_ color: PieceColor, size: CGFloat) -> some View {
        Image(nsImage: PieceImages.image(for: Piece(.king, color)))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(settings.theme.light))
            .help("\(color.name) to move")
    }

    private var statusColor: Color {
        switch session.feedback {
        case .ok, .solved: return Ink.good
        case .notOK: return Ink.bad
        case .failed: return Ink.accent
        default: return Ink.text
        }
    }

    private var statusDetail: String {
        if session.isFinished, let line = session.solutionLine { return line }
        switch session.feedback {
        case .none: return ""
        case .info(let s), .thinking(let s), .ok(let s), .notOK(let s), .solved(let s), .failed(let s): return s
        }
    }

    // MARK: Levels

    private var levelChips: some View {
        ViewThatFits(in: .horizontal) {
            chipRow
            Menu {
                ForEach(PuzzleLevel.all) { lvl in
                    Button(lvl.label) {
                        settings.level = lvl.id
                        session.loadNext()
                    }
                }
            } label: {
                Text("Level: \(settings.puzzleLevel.name)")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .buttonStyle(ChipStyle(selected: true))
        }
    }

    private var chipRow: some View {
        HStack(spacing: 6) {
            ForEach(PuzzleLevel.all) { lvl in
                Button(lvl.name) {
                    guard lvl.id != settings.level else { return }
                    settings.level = lvl.id
                    session.loadNext()
                }
                .buttonStyle(ChipStyle(selected: lvl.id == settings.level))
                .help(lvl.label)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 18) {
            if !session.isFinished {
                Button("Skip") { session.skip() }
                    .buttonStyle(LinkStyle())
                    .keyboardShortcut("s", modifiers: [])
                    .help("Skip to another puzzle (S)")
            }
            Button("Close") { onClose() }
                .buttonStyle(LinkStyle())
            Spacer()
            HStack(spacing: 12) {
                stat("checkmark", stats.solved, "Solved cleanly")
                stat("xmark", stats.failed, "Missed or needed help")
                stat("flame", stats.streak, "Streak (best \(stats.bestStreak))")
                Circle()
                    .fill(engine.isAvailable ? Ink.good : Ink.accent)
                    .frame(width: 6, height: 6)
                    .help(engine.status)
            }
        }
    }

    private func stat(_ icon: String, _ value: Int, _ help: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(verbatim: "\(value)").font(.system(size: 12, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(Ink.tertiary)
        .help(help)
    }
}


enum PanelMove {
    case dragChanged, dragEnded, resetPosition
}

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}
