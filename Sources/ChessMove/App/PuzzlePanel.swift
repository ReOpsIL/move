import AppKit
import SwiftUI

/// Borderless, rounded, shadowed panel that drops down from the menu-bar icon.
final class PuzzlePanel: NSPanel {
    init(contentView view: NSView) {
        super.init(contentRect: NSRect(origin: .zero, size: view.fittingSize),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .darkAqua)
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private var contentSize: NSSize { contentView?.fittingSize ?? frame.size }

    /// Frame just below `anchor` (a screen rect, e.g. the menu-bar icon), kept on screen.
    func frameBelow(_ anchor: NSRect) -> NSRect {
        let size = contentSize
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        return NSRect(x: x, y: anchor.minY - 6 - size.height, width: size.width, height: size.height)
    }

    func place(below anchor: NSRect) {
        setFrame(frameBelow(anchor), display: true)
    }

    /// Places the panel with its top-left corner at `p` (screen coordinates).
    func place(topLeft p: NSPoint) {
        let size = contentSize
        setFrame(NSRect(x: p.x, y: p.y - size.height, width: size.width, height: size.height), display: true)
    }

    func resizeKeepingTopLeft(to size: NSSize) {
        guard size.width > 0, size.height > 0, size != frame.size else { return }
        setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height), display: true)
    }
}

/// Hosting view that reports when its SwiftUI content wants a different size.
final class SizingHostingView<Content: View>: NSHostingView<Content> {
    var onSizeChange: ((NSSize) -> Void)?

    /// Let the first click act (drag, resize, move a piece) even when another app is active.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onSizeChange?(self.fittingSize)
        }
    }
}
