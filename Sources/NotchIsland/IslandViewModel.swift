import AppKit
import SwiftUI
import Combine

@MainActor
class IslandViewModel: ObservableObject {
    static let shared = IslandViewModel()

    @Published var state: IslandState = .compact
    @Published var nowPlaying         = NowPlayingInfo()
    @Published var systemStats        = SystemStats()
    @Published var timerState         = TimerState()
    @Published var calendarEvents:    [CalendarEventInfo] = []
    @Published var weather            = WeatherInfo()
    @Published var bluetoothDevices:  [BTDeviceInfo] = []

    // Hover: set directly by PillHitTestView; didSet handles peek promotion.
    @Published var isHovering: Bool = false {
        didSet { guard isHovering != oldValue else { return }; onHoverChanged(isHovering) }
    }

    // MIDI ambient border glow (0 = off, 1 = full intensity).
    @Published var midiGlowOpacity: Double = 0.0

    // Pinch-to-resize scale for expanded island (1.0 = default)
    @Published var expandedSizeMultiplier: CGFloat = 1.0
    private var pinchBaseMultiplier: CGFloat = 1.0
    private var magnifyMonitor: Any?

    let nowPlayingManager       = NowPlayingManager()
    let systemStatsManager      = SystemStatsManager()
    let contextManager          = ContextManager()
    let calendarManager         = CalendarManager()
    let weatherManager          = WeatherManager()
    let bluetoothManager        = BluetoothManager()
    let alertManager            = AlertManager()
    let midiManager             = MIDIManager()
    let todoistManager          = TodoistManager()
    let googleCalendarManager   = GoogleCalendarManager()
    let gmailManager            = GmailManager()
    let notificationInterceptor = NotificationInterceptor()

    var onSwipeEvent: ((CGFloat, NSEvent.Phase) -> Void)?

    private var cancellables            = Set<AnyCancellable>()
    private var countdownTimer:         AnyCancellable?
    private var mouseMonitor:           Any?
    private var localScrollMonitor:     Any?
    private var midiFlashGeneration:    Int = 0
    private var alertReturnTask:        Task<Void, Never>?
    private var alertInterruptedPeek    = false
    private var remindedEventKeys:      Set<String> = []

    init() {
        // Wire Gmail to share Google auth tokens with Calendar
        gmailManager.authProvider = googleCalendarManager

        // Fetch Gmail messages after successful Google auth or on launch if already authed,
        // then start the 60 s polling loop.
        NotificationCenter.default.addObserver(forName: .googleAuthDidComplete, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.gmailManager.fetchMessages() }
            self?.gmailManager.startPolling()
        }
        if googleCalendarManager.isAuthenticated {
            Task { await gmailManager.fetchMessages() }
            gmailManager.startPolling()
        }

        // ── Data-manager subscriptions ──────────────────────────────────
        nowPlayingManager.$info
            .receive(on: RunLoop.main)
            .assign(to: \.nowPlaying, on: self)
            .store(in: &cancellables)

        systemStatsManager.$stats
            .receive(on: RunLoop.main)
            .assign(to: \.systemStats, on: self)
            .store(in: &cancellables)

        calendarManager.$events
            .receive(on: RunLoop.main)
            .assign(to: \.calendarEvents, on: self)
            .store(in: &cancellables)

        weatherManager.$weather
            .receive(on: RunLoop.main)
            .assign(to: \.weather, on: self)
            .store(in: &cancellables)

        bluetoothManager.$devices
            .receive(on: RunLoop.main)
            .assign(to: \.bluetoothDevices, on: self)
            .store(in: &cancellables)

        // Auto-expand to now-playing only from idle compact state.
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

        // React to alert queue changes.
        alertManager.$current
            .receive(on: RunLoop.main)
            .sink { [weak self] info in self?.handleAlertChange(info) }
            .store(in: &cancellables)

        // MIDI flash signal.
        midiManager.onEvent = { [weak self] in self?.triggerMIDIFlash() }

        // Todoist: start polling + wire overdue alerts + new-task alerts.
        todoistManager.start()
        todoistManager.onOverdueAlert = { [weak self] task in
            self?.alertManager.post(
                icon: "checkmark.circle",
                text: task.content,
                source: "Todoist"
            )
        }
        todoistManager.onNewTask = { [weak self] task in
            self?.alertManager.post(
                icon: "checkmark.circle.badge.plus",
                text: task.content,
                source: "Todoist"
            )
        }

        // Gmail: new-message alerts (fires after first fetch when new IDs appear)
        gmailManager.onNewMessage = { [weak self] msg in
            let text = msg.subject.isEmpty ? msg.fromName : msg.subject
            self?.alertManager.post(icon: "envelope.fill", text: text, source: msg.fromName)
        }

        // Notification interceptor: start if enabled, wire incoming banners.
        if SettingsManager.shared.notifInterceptEnabled {
            NotificationInterceptor.requestPermission()
            notificationInterceptor.start()
        }
        notificationInterceptor.onNotification = { [weak self] notif in
            guard let self else { return }
            let settings = SettingsManager.shared
            guard settings.notifInterceptEnabled else { return }
            // DND gating: skip if DND active and bypass is OFF
            if settings.systemDNDActive && !settings.notifBypassDND { return }
            // App filter: if allowlist is non-empty, only show listed apps
            if !settings.notifAllowedApps.isEmpty,
               !settings.notifAllowedApps.contains(notif.appName) { return }
            let text = notif.title.isEmpty ? notif.body : notif.title
            self.alertManager.post(icon: "bell.fill", text: text, source: notif.appName)
        }

        // Pinch-to-resize the expanded island.
        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self, case .expanded = self.state else { return event }
            if event.phase == .began {
                MainActor.assumeIsolated { self.pinchBaseMultiplier = self.expandedSizeMultiplier }
            }
            let raw  = self.pinchBaseMultiplier * (1.0 + event.magnification)
            let next = min(max(raw, 0.75), 1.60)
            MainActor.assumeIsolated {
                withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.9)) {
                    self.expandedSizeMultiplier = next
                }
            }
            return nil  // consume — prevent system zoom
        }

        // Horizontal scroll interceptor — keeps page-swipe working over ScrollViews.
        localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, case .expanded = self.state else { return event }
            guard event.momentumPhase.isEmpty else { return event }
            let phase = event.phase
            if phase == .ended || phase == .cancelled {
                MainActor.assumeIsolated { self.onSwipeEvent?(0, phase) }
                return nil
            }
            guard event.hasPreciseScrollingDeltas,
                  abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return event }
            if phase == .began || phase == .changed {
                MainActor.assumeIsolated { self.onSwipeEvent?(event.scrollingDeltaX, phase) }
                return nil
            }
            return event
        }

        // 15-minute calendar reminder check — runs every 60 s.
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkCalendarReminders() }
            .store(in: &cancellables)
    }

    // MARK: – Calendar reminders

    private func checkCalendarReminders() {
        let now  = Date()
        let soon = now.addingTimeInterval(15 * 60)

        // Local EventKit events
        for ev in calendarEvents {
            let key = "\(ev.title)-\(Int(ev.startDate.timeIntervalSince1970))"
            guard !remindedEventKeys.contains(key), ev.startDate > now, ev.startDate <= soon else { continue }
            remindedEventKeys.insert(key)
            alertManager.post(icon: "calendar", text: ev.title, source: "In 15 min")
        }

        // Google Calendar events
        for ev in googleCalendarManager.events {
            let key = "gcal-\(ev.id)"
            guard !remindedEventKeys.contains(key), ev.start > now, ev.start <= soon else { continue }
            remindedEventKeys.insert(key)
            let meetURL = ev.hangoutLink.flatMap(URL.init(string:))
            alertManager.post(icon: "calendar", text: ev.title, source: "In 15 min", actionURL: meetURL)
        }
    }

    // MARK: – Spring catalogue (dampingFraction ≈ 0.76 for alert / peek)

    private static let expandSpring  = Animation.interpolatingSpring(mass: 1, stiffness: 160, damping: 18)
    private static let collapseSpring = Animation.interpolatingSpring(mass: 1, stiffness: 260, damping: 28)
    static  let hoverSpring           = Animation.interpolatingSpring(mass: 1, stiffness: 320, damping: 24)
    // dampingFraction ≈ d / (2√(m·k)) = 22 / (2√220) ≈ 0.74  — organic, snappy
    private static let alertSpring   = Animation.spring(response: 0.36, dampingFraction: 0.76)
    private static let peekSpring    = Animation.spring(response: 0.32, dampingFraction: 0.76)

    // MARK: – State transitions

    func expand(to module: IslandModule) {
        alertManager.clearAll()
        alertReturnTask?.cancel()
        withAnimation(Self.expandSpring) { state = .expanded(module) }
        startClickOutsideMonitor()
    }

    func collapse() {
        alertManager.clearAll()
        alertReturnTask?.cancel()
        alertInterruptedPeek = false
        withAnimation(Self.collapseSpring) { state = .compact }
        stopClickOutsideMonitor()
    }

    func toggle(_ module: IslandModule) {
        switch state {
        case .compact, .alert, .peek:
            expand(to: module)
        case .expanded(let current) where current == module:
            collapse()
        case .expanded:
            withAnimation(Self.expandSpring) { state = .expanded(module) }
        }
    }

    // The module to navigate to when the user taps the peek panel.
    var peekTargetModule: IslandModule {
        if timerState.isRunning { return .timer }
        return contextManager.suggestedModule
    }

    // MARK: – Hover → Peek promotion

    // True when a foreground-visible background process deserves the peek panel.
    var hasActiveBackgroundTask: Bool {
        timerState.isRunning && !timerState.justFinished
    }

    private func onHoverChanged(_ hovering: Bool) {
        if hovering {
            // Always promote to peek from idle — gives meaningful preview on every hover.
            guard case .compact = state else { return }
            withAnimation(Self.peekSpring) { state = .peek }
            startClickOutsideMonitor()
        } else {
            if case .peek = state {
                withAnimation(Self.collapseSpring) { state = .compact }
                stopClickOutsideMonitor()
            }
        }
    }

    // MARK: – Alert priority handling

    private func handleAlertChange(_ alert: AlertInfo?) {
        if let alert {
            switch state {
            case .expanded: return  // never interrupt a user-opened dashboard
            case .compact:
                // Record whether we're pre-empting a hovering task session.
                alertInterruptedPeek = isHovering && hasActiveBackgroundTask
            case .peek:
                alertInterruptedPeek = true
            case .alert:
                break  // alert → alert cycling: keep existing flag
            }
            withAnimation(Self.alertSpring) { state = .alert(alert) }
            startClickOutsideMonitor()
        } else {
            // Queue drained — return to whatever context is appropriate.
            alertReturnTask?.cancel()
            guard case .alert = state else { return }

            if alertInterruptedPeek || (isHovering && hasActiveBackgroundTask) {
                withAnimation(Self.peekSpring) { state = .peek }
            } else {
                withAnimation(Self.collapseSpring) { state = .compact }
                if !isHovering { stopClickOutsideMonitor() }
            }
            alertInterruptedPeek = false
        }
    }

    // MARK: – Click-outside monitor

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self else { return }
            // External-display safety: only evaluate against the notch screen.
            guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
                            ?? NSScreen.main else { return }
            let cursor = NSEvent.mouseLocation
            let w = self.islandWidth
            let h = self.islandHeight
            let rect = CGRect(x: screen.frame.midX - w / 2,
                              y: screen.frame.maxY  - h,
                              width: w, height: h)
            if !rect.contains(cursor) {
                Task { @MainActor [weak self] in self?.collapse() }
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
    }

    // MARK: – MIDI glow

    func triggerMIDIFlash() {
        midiFlashGeneration &+= 1
        let gen = midiFlashGeneration
        midiGlowOpacity = 1.0                                  // instant snap to full
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) { [weak self] in
            guard let self, self.midiFlashGeneration == gen else { return }
            withAnimation(.linear(duration: 0.15)) { self.midiGlowOpacity = 0.0 }
        }
    }

    // MARK: – Now Playing controls

    func togglePlayPause() { nowPlayingManager.togglePlayPause() }
    func previousTrack()   { nowPlayingManager.previousTrack() }
    func nextTrack()       { nowPlayingManager.nextTrack() }
    func skipForward()     { nowPlayingManager.skipForward() }
    func skipBackward()    { nowPlayingManager.skipBackward() }
    func seekTo(_ pos: TimeInterval) { nowPlayingManager.seekTo(pos) }

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
        timerState.remaining    = 0
        timerState.justFinished = true
        NSSound(named: .init(SettingsManager.shared.timerSoundName))?.play()
        expand(to: .timer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            self.timerState.justFinished = false
            self.timerState.isBreak      = !self.timerState.isBreak
            self.timerState.duration     = self.timerState.isBreak ? 5 * 60 : 25 * 60
            self.timerState.remaining    = self.timerState.duration
        }
    }

    // MARK: – Island geometry

    var notchWidth: CGFloat {
        guard let screen = NSScreen.main, screen.safeAreaInsets.top > 0 else { return kNotchWidth }
        let left  = screen.auxiliaryTopLeftArea?.width  ?? 0
        let right = screen.auxiliaryTopRightArea?.width ?? 0
        let w = screen.frame.width - left - right
        return w > 80 ? w : kNotchWidth
    }

    var notchHeight: CGFloat {
        let h = NSScreen.main?.safeAreaInsets.top ?? 0
        return h > 0 ? h : kNotchHeight
    }

    private var hoverWidth:  CGFloat { notchWidth  * kHoverWidthMultiplier  }
    private var hoverHeight: CGFloat { notchHeight * kHoverHeightMultiplier }

    var isTimerWarning: Bool {
        let t = timerState
        return t.isRunning && !t.justFinished && t.duration > 0 && t.progress >= 0.95
    }

    var islandWidth: CGFloat {
        switch state {
        case .compact:  return (isHovering || isTimerWarning) ? hoverWidth  : notchWidth
        case .alert:    return notchWidth * 1.15
        case .peek:     return kPeekExpandedWidth
        case .expanded: return (kIslandExpandedWidth * expandedSizeMultiplier).rounded()
        }
    }

    var islandHeight: CGFloat {
        switch state {
        case .compact:  return (isHovering || isTimerWarning) ? hoverHeight : notchHeight
        case .alert:    return notchHeight * 1.10
        case .peek:     return kPeekExpandedHeight
        case .expanded(let mod): return (mod.preferredExpandedHeight * expandedSizeMultiplier).rounded()
        }
    }

    // Hit-test rect in NSView coordinates (origin bottom-left).
    var pillRectInWindow: CGRect {
        func rect(_ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: (kWindowWidth - w) / 2, y: kWindowHeight - h, width: w, height: h)
        }
        switch state {
        case .expanded: return rect(islandWidth, islandHeight)
        case .peek:     return rect(kPeekExpandedWidth,   kPeekExpandedHeight)
        case .alert:    return rect(notchWidth * 1.15,    notchHeight * 1.10)
        case .compact:  return rect(hoverWidth,           hoverHeight)
        }
    }
}
