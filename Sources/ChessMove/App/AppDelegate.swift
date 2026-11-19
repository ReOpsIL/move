import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings.shared
    let stats = Stats.shared
    let store = PuzzleStore()
    lazy var engine = EngineService(settings: settings)
    lazy var session = PuzzleSession(settings: settings, engine: engine, store: store, stats: stats)
    lazy var scheduler = PuzzleScheduler(settings: settings)

    private var statusItem: NSStatusItem!
    private var panel: PuzzlePanel!
    private var hostingView: NSView!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = PieceImages.menuBarIcon()
            button.toolTip = "Chess Move — click for a puzzle, right-click for options"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let root = PuzzleView(
            session: session, settings: settings, stats: stats, engine: engine,
            onClose: { [weak self] in self?.closePopover() },
            onSettings: { [weak self] in self?.openSettings() }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        hostingView = hosting
        panel = PuzzlePanel(contentView: hosting)

        engine.start()

        scheduler.onFire = { [weak self] in self?.showPuzzle(automatic: true) }
        scheduler.canFire = { [weak self] in !(self?.panel.isVisible ?? true) }
        scheduler.start()

        let args = CommandLine.arguments
        if args.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.showPuzzle(automatic: false) }
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            let moves = args.firstIndex(of: "--play").flatMap { $0 + 1 < args.count ? args[$0 + 1].split(separator: ",").map(String.init) : nil } ?? []
            Snapshot.run(delegate: self, path: args[i + 1], moves: moves)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.shutdown()
    }

    // MARK: Status item

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else if panel.isVisible {
            closePopover()
        } else {
            showPuzzle(automatic: false)
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Puzzle", action: #selector(menuShow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "New Puzzle", action: #selector(menuNew), keyEquivalent: "n").target = self
        menu.addItem(.separator())
        if let next = scheduler.nextFire, settings.puzzlesPerDay > 0 {
            let f = DateFormatter()
            f.dateStyle = .none
            f.timeStyle = .short
            let item = NSMenuItem(title: "Next pop-up: \(f.string(from: next))", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(withTitle: "Settings…", action: #selector(menuSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Chess Move", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuShow() { showPuzzle(automatic: false) }
    @objc private func menuNew() { session.loadNext(); showPuzzle(automatic: false) }
    @objc private func menuSettings() { openSettings() }

    // MARK: Panel

    func showPuzzle(automatic: Bool) {
        if session.puzzle == nil || session.isFinished { session.loadNext() }
        if !automatic {
            scheduler.userOpenedPuzzle()
            NSApp.activate(ignoringOtherApps: true)
        }
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        if !panel.isVisible {
            panel.place(below: anchor)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                panel.animator().alphaValue = 1
            }
        }
        if automatic {
            if settings.sounds { NSSound(named: "Purr")?.play() }
        } else {
            panel.makeKey()
        }
    }

    func closePopover() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in self?.panel.orderOut(nil) }
        })
    }

    // MARK: Settings

    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, engine: engine, scheduler: scheduler, stats: stats, store: store,
                                    onLevelChanged: { [weak self] in
                                        guard let self else { return }
                                        if let p = self.session.puzzle, self.settings.puzzleLevel.range.contains(p.rating) { return }
                                        self.session.loadNext()
                                    })
            let hosting = NSHostingController(rootView: view)
            hosting.sizingOptions = .preferredContentSize
            let w = NSWindow(contentViewController: hosting)
            w.appearance = NSAppearance(named: .darkAqua)
            w.title = "Chess Move Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    var popoverView: NSView? { hostingView }
}
