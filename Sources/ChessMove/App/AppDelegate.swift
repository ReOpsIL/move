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
    private let popover = NSPopover()
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
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .applicationDefined
        popover.animates = true

        engine.start()

        scheduler.onFire = { [weak self] in self?.showPuzzle(automatic: true) }
        scheduler.canFire = { [weak self] in !(self?.popover.isShown ?? true) }
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
        } else if popover.isShown {
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

    // MARK: Popover

    func showPuzzle(automatic: Bool) {
        if session.puzzle == nil || session.isFinished { session.loadNext() }
        if !automatic {
            scheduler.userOpenedPuzzle()
            NSApp.activate(ignoringOtherApps: true)
        }
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        if automatic && settings.sounds { NSSound(named: "Purr")?.play() }
        popover.contentViewController?.view.window?.makeKey()
    }

    func closePopover() {
        popover.performClose(nil)
    }

    // MARK: Settings

    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, engine: engine, scheduler: scheduler, stats: stats, store: store,
                                    onLevelChanged: { [weak self] in
                                        self?.session.loadNext()
                                    })
            let hosting = NSHostingController(rootView: view)
            hosting.sizingOptions = .preferredContentSize
            let w = NSWindow(contentViewController: hosting)
            w.title = "Chess Move Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    var popoverView: NSView? { popover.contentViewController?.view }
}
