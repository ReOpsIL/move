import AppKit
import SwiftUI

/// Debug helper: `ChessMove --snapshot out.png [--play uci,uci]` renders the puzzle UI offscreen to a PNG and quits.
@MainActor
enum Snapshot {
    static func run(delegate: AppDelegate, path: String, moves: [String]) {
        let session = delegate.session
        if let custom = ProcessInfo.processInfo.environment["PUZZLE_CUSTOM"]?.split(separator: "|"), custom.count == 2 {
            session.load(Puzzle(id: "custom", fen: String(custom[0]), moves: custom[1].split(separator: " ").compactMap { Move(uci: String($0)) },
                                rating: 1500, themes: []))
        } else if let id = ProcessInfo.processInfo.environment["PUZZLE_ID"], let p = delegate.store.puzzles.first(where: { $0.id == id }) {
            session.load(p)
        } else {
            session.loadNext()
        }
        let view = PuzzleView(session: session, settings: delegate.settings, stats: delegate.stats, engine: delegate.engine,
                              onClose: {}, onSettings: {})
        let hosting: NSView = ProcessInfo.processInfo.environment["SNAPSHOT_SETTINGS"] != nil
            ? NSHostingView(rootView: SettingsView(settings: delegate.settings, engine: delegate.engine, scheduler: delegate.scheduler,
                                                   stats: delegate.stats, store: delegate.store, onLevelChanged: {}))
            : NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
        window.orderFrontRegardless()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            for uci in moves {
                if uci == "hint" { session.hint() }
                else if uci == "answer" { session.showAnswer() }
                else if let m = ChessCoreMove(uci) { session.attempt(from: m.from, to: m.to) }
                try? await Task.sleep(for: .seconds(4))
            }
            hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
            window.setContentSize(hosting.frame.size)
            hosting.layoutSubtreeIfNeeded()
            if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
            print("snapshot: puzzle \(session.puzzle?.id ?? "-") moves \(session.puzzle?.moves.map(\.uci) ?? []) state \(session.state) feedback \(session.feedback)")
            NSApp.terminate(nil)
        }
    }
}

import ChessCore
private func ChessCoreMove(_ s: String) -> Move? { Move(uci: s) }
