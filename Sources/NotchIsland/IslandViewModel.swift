import AppKit
import SwiftUI
import Combine

@MainActor
class IslandViewModel: ObservableObject {
    static let shared = IslandViewModel()

    @Published var state: IslandState = .compact
    @Published var isHovering: Bool   = false
    @Published var nowPlaying         = NowPlayingInfo()
    @Published var systemStats        = SystemStats()
    @Published var timerState         = TimerState()

    let nowPlayingManager  = NowPlayingManager()
    let systemStatsManager = SystemStatsManager()
    let contextManager     = ContextManager()

    private var cancellables     = Set<AnyCancellable>()
    private var countdownTimer:  AnyCancellable?
    private var mouseMonitor:    Any?

    init() {
        nowPlayingManager.$info
            .receive(on: RunLoop.main)
            .assign(to: \.nowPlaying, on: self)
            .store(in: &cancellables)

        systemStatsManager.$stats
            .receive(on: RunLoop.main)
            .assign(to: \.systemStats, on: self)
            .store(in: &cancellables)

        // Auto-expand to now-playing when a track starts
        nowPlayingManager.$info
            .map(\.isPlaying)
            .removeDuplicates()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, case .compact = self.state else { return }
                self.expand(to: .nowPlaying)
            }
            .store(in: &cancellables)
    }

    // MARK: – Island state

    // Slight overshoot on expand for organic feel; crisp snap on collapse.
    private static let expandSpring   = Animation.interpolatingSpring(mass: 1, stiffness: 160, damping: 18)
    private static let collapseSpring = Animation.interpolatingSpring(mass: 1, stiffness: 260, damping: 28)
    static let hoverSpring            = Animation.interpolatingSpring(mass: 1, stiffness: 320, damping: 24)

    func expand(to module: IslandModule) {
        withAnimation(Self.expandSpring) { state = .expanded(module) }
        startClickOutsideMonitor()
    }

    func collapse() {
        withAnimation(Self.collapseSpring) { state = .compact }
        stopClickOutsideMonitor()
    }

    func toggle(_ module: IslandModule) {
        switch state {
        case .compact:
            expand(to: module)
        case .expanded(let current) where current == module:
            collapse()
        case .expanded:
            withAnimation(Self.expandSpring) { state = .expanded(module) }
        }
    }

    // MARK: – Click-outside to collapse

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        // Global mouse-down monitor (mouse events don't require Accessibility permission)
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self else { return }
            let cursor  = NSEvent.mouseLocation
            let screen  = NSScreen.main ?? NSScreen.screens[0]
            let w = self.islandWidth
            let h = self.islandHeight
            let islandRect = CGRect(
                x: screen.frame.midX - w / 2,
                y: screen.frame.maxY - h,
                width: w, height: h
            )
            if !islandRect.contains(cursor) {
                Task { @MainActor [weak self] in self?.collapse() }
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
    }

    // MARK: – Now Playing controls

    func togglePlayPause() { nowPlayingManager.togglePlayPause() }
    func previousTrack()   { nowPlayingManager.previousTrack() }
    func nextTrack()       { nowPlayingManager.nextTrack() }

    // MARK: – Timer

    func startTimer() {
        timerState.isRunning = true
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.timerState.remaining > 0 {
                    self.timerState.remaining -= 1
                } else {
                    self.timerFinished()
                }
            }
    }

    func pauseTimer() {
        timerState.isRunning = false
        countdownTimer?.cancel()
        countdownTimer = nil
    }

    func resetTimer() {
        pauseTimer()
        timerState.remaining = timerState.duration
    }

    func setTimerDuration(minutes: Int) {
        pauseTimer()
        timerState.duration  = TimeInterval(minutes * 60)
        timerState.remaining = timerState.duration
    }

    private func timerFinished() {
        pauseTimer()
        timerState.remaining = 0
        timerState.isBreak   = !timerState.isBreak
        timerState.duration  = timerState.isBreak ? 5 * 60 : 25 * 60
        timerState.remaining = timerState.duration
        expand(to: .timer)
    }

    // MARK: – Island geometry

    // Measure the real notch from NSScreen (macOS 12+ APIs).
    // auxiliaryTopLeftArea / auxiliaryTopRightArea give the menu-bar regions
    // on either side of the notch; subtracting them from frame width gives
    // the exact notch width without any hard-coding.
    var notchWidth: CGFloat {
        guard let screen = NSScreen.main, screen.safeAreaInsets.top > 0 else {
            return kNotchWidth
        }
        let left  = screen.auxiliaryTopLeftArea?.width  ?? 0
        let right = screen.auxiliaryTopRightArea?.width ?? 0
        let w = screen.frame.width - left - right
        return w > 80 ? w : kNotchWidth
    }

    var notchHeight: CGFloat {
        let h = NSScreen.main?.safeAreaInsets.top ?? 0
        return h > 0 ? h : kNotchHeight
    }

    var islandWidth: CGFloat {
        state.isExpanded ? kIslandExpandedWidth : notchWidth
    }

    var islandHeight: CGFloat {
        state.isExpanded ? kIslandExpandedHeight : notchHeight
    }

    // Hit-test rect in NSView coords (origin bottom-left).
    // Add a small buffer in compact mode so hovering near the notch edge
    // registers before the visual boundary.
    var pillRectInWindow: CGRect {
        let w = islandWidth  + (state.isExpanded ? 0 : 16)
        let h = islandHeight + (state.isExpanded ? 0 :  8)
        let x = (kWindowWidth - w) / 2
        let y = kWindowHeight - h
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
