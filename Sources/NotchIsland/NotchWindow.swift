import AppKit
import SwiftUI
import Combine

// Custom root view that only hit-tests within the pill, letting clicks fall through
// to windows underneath everywhere else.
final class PillHitTestView: NSView {
    var viewModel: IslandViewModel?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let vm = viewModel else { return nil }
        // pillRectInWindow is in NSView coords (origin bottom-left)
        guard vm.pillRectInWindow.contains(point) else { return nil }
        return super.hitTest(point)
    }

    // Needed so our NSPanel level actually places us above the menu bar
    override var isOpaque: Bool { false }
}

final class NotchPanel: NSPanel {
    private var hitTestView: PillHitTestView?
    private var cancellable: AnyCancellable?

    init(viewModel: IslandViewModel) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let x = screen.frame.midX - kWindowWidth / 2
        let y = screen.frame.maxY - kWindowHeight

        super.init(
            contentRect: NSRect(x: x, y: y, width: kWindowWidth, height: kWindowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Level 26 = one above NSWindow.Level.statusBar (25) — sits above menu bar
        level                   = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        backgroundColor         = .clear
        isOpaque                = false
        hasShadow               = false
        collectionBehavior      = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        isReleasedWhenClosed    = false

        let rootView = PillHitTestView(frame: NSRect(x: 0, y: 0, width: kWindowWidth, height: kWindowHeight))
        rootView.viewModel = viewModel
        hitTestView = rootView

        let hosting = NSHostingView(rootView: IslandView(viewModel: viewModel))
        hosting.frame = rootView.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.layer?.backgroundColor = .clear
        rootView.addSubview(hosting)
        contentView = rootView

        // Refresh hit-test rect when pill size changes
        cancellable = viewModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak rootView] _ in rootView?.needsDisplay = true }
    }

    // Allow key events (so buttons inside respond to keyboard) but don't steal main status
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
