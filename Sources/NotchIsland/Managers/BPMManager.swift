import QuartzCore
import Combine

/// Thread-safe BPM calculator isolated to the main actor.
/// Uses CACurrentMediaTime() for sub-millisecond tap resolution.
@MainActor
final class BPMManager: ObservableObject {
    @Published private(set) var bpm: Int?
    /// Incremented on every tap — use as animation trigger in views.
    @Published private(set) var tapCount: Int = 0

    private var timestamps: [Double] = []

    // Auto-reset threshold and rolling window size
    private static let resetThreshold: Double = 2.5
    private static let maxSamples:     Int    = 16

    // MARK: – Public

    func tap() {
        let now = CACurrentMediaTime()

        // Stale gap detected → start a fresh sequence
        if let last = timestamps.last, now - last > Self.resetThreshold {
            timestamps.removeAll()
            bpm = nil
        }

        timestamps.append(now)
        tapCount &+= 1   // wrapping increment — purely a change-notification token

        // Keep the rolling window bounded
        if timestamps.count > Self.maxSamples { timestamps.removeFirst() }

        // Need at least two points to derive an interval
        guard timestamps.count >= 2 else { return }

        let intervals = zip(timestamps, timestamps.dropFirst()).map { $1 - $0 }
        let mean      = intervals.reduce(0, +) / Double(intervals.count)
        bpm = mean > 0 ? max(20, min(300, Int((60.0 / mean).rounded()))) : nil
    }

    func reset() {
        timestamps.removeAll()
        bpm      = nil
        tapCount = 0
    }
}
