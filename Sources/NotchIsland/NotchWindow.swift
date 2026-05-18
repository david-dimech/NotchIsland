import AppKit
import SwiftUI
import Combine

// Root NSView — handles hit testing, hover haptics, and scroll interception.
// It sits at the top of the responder chain so scroll events over the island
// always reach it, regardless of what SwiftUI content is rendered inside.
final class PillHitTestView: NSView {
    var viewModel: IslandViewModel?
    private var trackingArea: NSTrackingArea?

    // MARK: – Hit testing (click-through outside pill)

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let vm = viewModel else { return nil }
        guard vm.pillRectInWindow.contains(point) else { return nil }
        return super.hitTest(point)
    }

    override var isOpaque: Bool { false }

    // MARK: – Hover tracking

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
        // Haptic only when compact — island is already open, no need to signal
        if case .compact = viewModel?.state {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment, performanceTime: .default
            )
        }
        MainActor.assumeIsolated {
            withAnimation(IslandViewModel.hoverSpring) {
                viewModel?.isHovering = true
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        MainActor.assumeIsolated {
            withAnimation(IslandViewModel.hoverSpring) {
                viewModel?.isHovering = false
            }
        }
    }

    // MARK: – Scroll / swipe interception

    // scrollWheel is called on the main thread by AppKit for any scroll event
    // whose hit-test lands within our window. By overriding here (the root NSView)
    // we catch events before NSHostingView can consume them, giving us reliable
    // 2-finger swipe tracking without NSViewRepresentable hacks.
    override func scrollWheel(with event: NSEvent) {
        guard let vm = viewModel, case .expanded = vm.state else {
            super.scrollWheel(with: event)
            return
        }

        // Ignore momentum phase (system coasting after finger lift)
        guard event.momentumPhase.isEmpty else { return }

        let phase = event.phase

        // Always forward end/cancel so the view can snap, even when deltas are ~0
        if phase == .ended || phase == .cancelled {
            MainActor.assumeIsolated { vm.onSwipeEvent?(0, phase) }
            return
        }

        // Trackpad-only (hasPreciseScrollingDeltas == false for physical mouse wheel)
        guard event.hasPreciseScrollingDeltas else {
            super.scrollWheel(with: event)
            return
        }

        // Only handle gestures that are more horizontal than vertical
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else {
            super.scrollWheel(with: event)
            return
        }

        if phase == .began || phase == .changed {
            MainActor.assumeIsolated { vm.onSwipeEvent?(event.scrollingDeltaX, phase) }
            // Don't call super — event is consumed by the island
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
