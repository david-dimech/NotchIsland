import AppKit
import SwiftUI

// Intercepts two-finger trackpad scroll events and forwards horizontal deltas.
// Placed as an overlay so it doesn't interfere with button hit testing.
struct TrackpadScrollReader: NSViewRepresentable {
    var onScroll: (CGFloat, NSEvent.Phase) -> Void

    func makeNSView(context: Context) -> ScrollReaderView {
        let v = ScrollReaderView()
        v.onScroll = onScroll
        return v
    }

    func updateNSView(_ v: ScrollReaderView, context: Context) {
        v.onScroll = onScroll
    }

    final class ScrollReaderView: NSView {
        var onScroll: ((CGFloat, NSEvent.Phase) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            // hasPreciseScrollingDeltas = true for trackpad, false for mouse wheel
            guard event.hasPreciseScrollingDeltas else {
                super.scrollWheel(with: event)
                return
            }
            // Only care about predominantly horizontal swipes
            guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 0.5 else {
                super.scrollWheel(with: event)
                return
            }
            onScroll?(event.scrollingDeltaX, event.phase)
        }
    }
}
