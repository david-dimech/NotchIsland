import AppKit
import SwiftUI
import Combine

// Root NSView that passes clicks through to windows below for anything
// outside the island rect, and fires hover events for haptic feedback.
final class PillHitTestView: NSView {
    var viewModel: IslandViewModel?
    private var trackingArea: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let vm = viewModel else { return nil }
        guard vm.pillRectInWindow.contains(point) else { return nil }
        return super.hitTest(point)
    }

    override var isOpaque: Bool { false }

    // Called whenever the view hierarchy changes — keeps the tracking rect tight
    // to the current island size so hover fires right at the notch edge.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }
        guard let vm = viewModel else { return }
        let area = NSTrackingArea(
            rect: vm.pillRectInWindow,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        // .alignment = the subtle "snap" haptic — feels like finding an edge
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment, performanceTime: .default
        )
        Task { @MainActor [weak self] in
            withAnimation(IslandViewModel.hoverSpring) {
                self?.viewModel?.isHovering = true
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        Task { @MainActor [weak self] in
            withAnimation(IslandViewModel.hoverSpring) {
                self?.viewModel?.isHovering = false
            }
        }
    }
}

final class NotchPanel: NSPanel {
    private var hitTestView: PillHitTestView?
    private var stateCancellable: AnyCancellable?

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

        // Level 26 = statusBar (25) + 1 → floats above the menu bar
        level                       = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        backgroundColor             = .clear
        isOpaque                    = false
        hasShadow                   = false
        collectionBehavior          = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        isReleasedWhenClosed        = false

        let root = PillHitTestView(frame: NSRect(x: 0, y: 0, width: kWindowWidth, height: kWindowHeight))
        root.viewModel = viewModel
        hitTestView    = root

        let hosting = NSHostingView(rootView: IslandView(viewModel: viewModel))
        hosting.frame              = root.bounds
        hosting.autoresizingMask   = [.width, .height]
        hosting.layer?.backgroundColor = .clear
        root.addSubview(hosting)
        contentView = root

        // Refresh tracking area whenever the island size changes
        stateCancellable = viewModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak root] _ in
                root?.updateTrackingAreas()
                root?.needsDisplay = true
            }
    }

    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }
}
