import SwiftUI
import ChessCore

struct PuzzleView: View {
    @ObservedObject var session: PuzzleSession
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: Stats
    @ObservedObject var engine: EngineService
    var onClose: () -> Void
    var onSettings: () -> Void

    private let boardSize: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(Ink.eyebrow)
                    .tracking(1.4)
                    .foregroundStyle(Ink.accent)
                Text(title)
                    .font(Ink.title(32))
                    .foregroundStyle(Ink.text)
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
        case .info: return session.state == .opponentMoving ? "Get ready" : "Your move"
        case .thinking: return "Checking"
        case .ok: return "OK"
        case .notOK: return "Not OK"
        case .solved: return "Solved"
        case .failed: return "Solution"
        }
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
