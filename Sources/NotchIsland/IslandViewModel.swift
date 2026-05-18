import SwiftUI
import Combine

@MainActor
class IslandViewModel: ObservableObject {
    static let shared = IslandViewModel()

    @Published var state: IslandState = .compact
    @Published var nowPlaying = NowPlayingInfo()
    @Published var systemStats = SystemStats()
    @Published var timerState = TimerState()

    let nowPlayingManager = NowPlayingManager()
    let systemStatsManager = SystemStatsManager()

    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: AnyCancellable?

    init() {
        nowPlayingManager.$info
            .receive(on: RunLoop.main)
            .assign(to: \.nowPlaying, on: self)
            .store(in: &cancellables)

        systemStatsManager.$stats
            .receive(on: RunLoop.main)
            .assign(to: \.systemStats, on: self)
            .store(in: &cancellables)
    }

    // MARK: – Island state

    func expand(to module: IslandModule) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            state = .expanded(module)
        }
    }

    func collapse() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            state = .compact
        }
    }

    func toggle(_ module: IslandModule) {
        switch state {
        case .compact:
            expand(to: module)
        case .expanded(let current) where current == module:
            collapse()
        case .expanded:
            expand(to: module)
        }
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
        timerState.duration = TimeInterval(minutes * 60)
        timerState.remaining = timerState.duration
    }

    private func timerFinished() {
        pauseTimer()
        timerState.remaining = 0
        // Switch between work / break rounds
        if timerState.isBreak {
            timerState.isBreak = false
            timerState.duration = 25 * 60
        } else {
            timerState.isBreak = true
            timerState.duration = 5 * 60
        }
        timerState.remaining = timerState.duration
        // Bounce the island open to signal the user
        expand(to: .timer)
    }

    // MARK: – Pill geometry (used by click-through view)

    var pillWidth: CGFloat {
        switch state {
        case .compact:        return kPillCompactWidth
        case .expanded:       return kPillExpandedWidth
        }
    }

    var pillHeight: CGFloat {
        switch state {
        case .compact:        return kPillCompactHeight
        case .expanded:       return kPillExpandedHeight
        }
    }

    /// Pill rect in NSView coordinate space (origin bottom-left, window size kWindowWidth x kWindowHeight)
    var pillRectInWindow: CGRect {
        let x = (kWindowWidth - pillWidth) / 2
        let y = kWindowHeight - pillHeight
        return CGRect(x: x, y: y, width: pillWidth, height: pillHeight)
    }
}
