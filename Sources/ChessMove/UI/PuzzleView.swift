import SwiftUI
import ChessCore

struct PuzzleView: View {
    @ObservedObject var session: PuzzleSession
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: Stats
    @ObservedObject var engine: EngineService
    var onClose: () -> Void
    var onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            BoardView(session: session, settings: settings)
                .frame(width: 400, height: 400)
            feedbackBar
            controls
            if session.isFinished { solutionBox }
            footer
        }
        .padding(14)
        .frame(width: 428)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("♞").font(.custom("Apple Symbols", size: 24))
            VStack(alignment: .leading, spacing: 0) {
                Text("Chess Move").font(.headline)
                if let p = session.puzzle {
                    Text(verbatim: "\(session.userColor.name) to move · rating \(p.rating)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu {
                ForEach(PuzzleLevel.all) { lvl in
                    Button {
                        settings.level = lvl.id
                        session.loadNext()
                    } label: {
                        if lvl.id == settings.level { Label(lvl.label, systemImage: "checkmark") } else { Text(lvl.label) }
                    }
                }
            } label: {
                Text(settings.puzzleLevel.name)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Puzzle level")

            Button(action: onSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
            Button(action: onClose) { Image(systemName: "xmark.circle.fill").font(.title3) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction)
                .help("Close (Esc)")
        }
    }

    // MARK: Feedback

    private var feedbackBar: some View {
        HStack(spacing: 8) {
            switch session.feedback {
            case .none:
                Text(" ")
            case .info(let s):
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text(s)
            case .thinking(let s):
                ProgressView().controlSize(.small)
                Text(s).foregroundStyle(.secondary)
            case .ok(let s):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(s).foregroundStyle(.green).fontWeight(.semibold)
            case .notOK(let s):
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(s).foregroundStyle(.red).fontWeight(.semibold)
            case .solved(let s):
                Image(systemName: "star.circle.fill").foregroundStyle(.green)
                Text(s).foregroundStyle(.green).fontWeight(.bold)
            case .failed(let s):
                Image(systemName: "eye.circle.fill").foregroundStyle(.orange)
                Text(s).foregroundStyle(.orange).fontWeight(.semibold)
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: 36)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(feedbackBackground))
    }

    private var feedbackBackground: Color {
        switch session.feedback {
        case .ok, .solved: return Color.green.opacity(0.12)
        case .notOK: return Color.red.opacity(0.12)
        case .failed: return Color.orange.opacity(0.12)
        default: return Color.primary.opacity(0.05)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 8) {
            if session.isFinished {
                Button {
                    session.loadNext()
                } label: {
                    Label("Next puzzle", systemImage: "arrow.right.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button { session.hint() } label: { Label("Hint", systemImage: "lightbulb") .frame(maxWidth: .infinity) }
                    .keyboardShortcut("h", modifiers: [])
                    .disabled(!session.canInteract)
                    .help("Hint (H) — press twice for an arrow")
                Button { session.showAnswer() } label: { Label("Answer", systemImage: "eye").frame(maxWidth: .infinity) }
                    .keyboardShortcut("a", modifiers: [])
                    .disabled(!session.canInteract)
                    .help("Show the solution (A)")
                Button { session.skip() } label: { Label("Skip", systemImage: "forward").frame(maxWidth: .infinity) }
                    .keyboardShortcut("s", modifiers: [])
                    .help("Skip to another puzzle (S)")
            }
            Button(action: onClose) { Label("Close", systemImage: "xmark").frame(maxWidth: session.isFinished ? 90 : .infinity) }
        }
        .controlSize(.large)
    }

    private var solutionBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let line = session.solutionLine {
                Text(line).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
            }
            if let p = session.puzzle {
                HStack(spacing: 6) {
                    ForEach(p.themeLabels.prefix(4), id: \.self) { t in
                        Text(t).font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                    Spacer()
                    Link("Lichess ↗", destination: p.lichessURL).font(.caption)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Label("\(stats.solved)", systemImage: "checkmark").help("Solved cleanly")
            Label("\(stats.failed)", systemImage: "xmark").help("Missed / needed help")
            Label("\(stats.streak)", systemImage: "flame").help("Current streak (best \(stats.bestStreak))")
            Spacer()
            Circle().fill(engine.isAvailable ? Color.green : Color.orange).frame(width: 6, height: 6)
            Text(engine.status).lineLimit(1).truncationMode(.tail)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
