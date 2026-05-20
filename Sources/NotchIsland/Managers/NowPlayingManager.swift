import AppKit
import Darwin

class NowPlayingManager: ObservableObject {
    @Published var info = NowPlayingInfo()

    // MARK: – MR function-pointer types
    private typealias RegisterFn    = @convention(c) (DispatchQueue) -> Void
    private typealias GetInfoFn     = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void
    private typealias GetPlayingFn  = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (Int, AnyObject?) -> Bool

    private var getInfo:    GetInfoFn?
    private var getPlaying: GetPlayingFn?
    private var sendCmd:    SendCommandFn?

    private let mrHandle: UnsafeMutableRawPointer?

    // Interpolation state
    private var progressTimer:  Timer?
    private var pollTimer:      Timer?
    private var fetchDate:      Date         = .distantPast
    private var elapsedAtFetch: TimeInterval = 0

    // MARK: – Init

    init() {
        mrHandle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        )
        loadSymbols()
        observeNotifications()
        fetchInfo()
        startProgressTimer()
        startPollTimer()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        progressTimer?.invalidate()
        pollTimer?.invalidate()
        if let h = mrHandle { dlclose(h) }
    }

    // MARK: – Setup

    private func loadSymbols() {
        guard let h = mrHandle else { return }

        // Register FIRST — without this macOS 12+ won't deliver NowPlaying data
        if let p = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            unsafeBitCast(p, to: RegisterFn.self)(.main)
        }

        if let p = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(p, to: GetInfoFn.self)
        }
        if let p = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            getPlaying = unsafeBitCast(p, to: GetPlayingFn.self)
        }
        if let p = dlsym(h, "MRMediaRemoteSendCommand") {
            sendCmd = unsafeBitCast(p, to: SendCommandFn.self)
        }
    }

    private func observeNotifications() {
        let names = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
        ]
        for n in names {
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(fetchInfo),
                name: NSNotification.Name(n), object: nil
            )
        }
    }

    // MARK: – Fetch

    @objc func fetchInfo() {
        // Use background queue for the callback — avoids RunLoop starvation on main
        getInfo?(.global()) { [weak self] raw in
            guard let self else { return }

            var next = NowPlayingInfo()

            if let raw {
                next.title    = raw["kMRMediaRemoteNowPlayingInfoTitle"]       as? String       ?? ""
                next.artist   = raw["kMRMediaRemoteNowPlayingInfoArtist"]      as? String       ?? ""
                next.duration = raw["kMRMediaRemoteNowPlayingInfoDuration"]    as? TimeInterval ?? 0
                next.elapsed  = raw["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0

                // Artwork — MR may return NSData, NSImage, or a MRMediaRemoteArtwork object
                let artRaw = raw["kMRMediaRemoteNowPlayingInfoArtworkData"]
                if let data = artRaw as? Data {
                    next.artwork = NSImage(data: data)
                } else if let img = artRaw as? NSImage {
                    next.artwork = img
                } else if let obj = artRaw as AnyObject?,
                          obj.responds(to: NSSelectorFromString("imageWithSize:")) {
                    // MRMediaRemoteArtwork — call imageWithSize: via ObjC runtime
                    let sel = NSSelectorFromString("imageWithSize:")
                    let img = obj.perform(sel, with: NSValue(size: NSSize(width: 100, height: 100)))?.takeUnretainedValue() as? NSImage
                    next.artwork = img
                }

                let rate = raw["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
                // Already have enough data — apply rate-based playing flag immediately
                if rate > 0 { next.isPlaying = true }
            }

            // If MR returned nothing (e.g. Spotify on some macOS versions), try AppleScript
            if next.title.isEmpty {
                if let as_ = Self.queryAppleScript() {
                    next.title    = as_.title
                    next.artist   = as_.artist
                    next.duration = as_.duration
                    next.elapsed  = as_.elapsed
                    next.isPlaying = as_.isPlaying
                    if let art = as_.artwork { next.artwork = art }
                }
            }

            // Cross-check the isPlaying flag with the dedicated MR call
            self.getPlaying?(.global()) { isPlaying in
                next.isPlaying = next.isPlaying || isPlaying
                DispatchQueue.main.async {
                    self.elapsedAtFetch = next.elapsed
                    self.fetchDate      = Date()
                    self.info           = next
                }
            }
            // If getPlaying is nil, commit what we have
            if self.getPlaying == nil {
                DispatchQueue.main.async {
                    self.elapsedAtFetch = next.elapsed
                    self.fetchDate      = Date()
                    self.info           = next
                }
            }
        }
    }

    // MARK: – AppleScript fallback (covers Spotify & Apple Music directly)

    private struct ASInfo {
        var title: String; var artist: String
        var duration: TimeInterval; var elapsed: TimeInterval
        var isPlaying: Bool; var artwork: NSImage?
    }

    private static func queryAppleScript() -> ASInfo? {
        // Try Spotify first, then Music
        for (appName, script) in appleScripts() {
            guard NSRunningApplication.runningApplications(withBundleIdentifier: appName).isEmpty == false else { continue }
            var err: NSDictionary?
            let src  = NSAppleScript(source: script)
            let desc = src?.executeAndReturnError(&err)
            guard err == nil, let desc else { continue }

            // Returns a list: {title, artist, duration_seconds, elapsed_seconds, isPlaying(0|1)}
            guard desc.numberOfItems >= 5 else { continue }
            let title    = desc.atIndex(1)?.stringValue ?? ""
            let artist   = desc.atIndex(2)?.stringValue ?? ""
            let duration = desc.atIndex(3)?.doubleValue ?? 0
            let elapsed  = desc.atIndex(4)?.doubleValue ?? 0
            let playing  = (desc.atIndex(5)?.int32Value ?? 0) == 1

            return ASInfo(title: title, artist: artist,
                          duration: duration, elapsed: elapsed,
                          isPlaying: playing, artwork: nil)
        }
        return nil
    }

    private static func appleScripts() -> [(String, String)] {
        let spotify = (
            "com.spotify.client",
            """
            tell application "Spotify"
                set t to name of current track
                set a to artist of current track
                set d to duration of current track / 1000
                set e to player position
                set p to (player state is playing)
                return {t, a, d, e, p as integer}
            end tell
            """
        )
        let music = (
            "com.apple.Music",
            """
            tell application "Music"
                if player state is playing or player state is paused then
                    set t to name of current track
                    set a to artist of current track
                    set d to duration of current track
                    set e to player position
                    set p to (player state is playing)
                    return {t, a, d, e, p as integer}
                end if
            end tell
            """
        )
        return [spotify, music]
    }

    // MARK: – Timers

    private func startProgressTimer() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.info.isPlaying, self.info.duration > 0 else { return }
            let interp = self.elapsedAtFetch + Date().timeIntervalSince(self.fetchDate)
            DispatchQueue.main.async { self.info.elapsed = min(interp, self.info.duration) }
        }
        RunLoop.main.add(t, forMode: .common)
        progressTimer = t
    }

    private func startPollTimer() {
        // Poll every 3 s to catch state changes the notifications miss
        let t = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in self?.fetchInfo() }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    // MARK: – Transport controls

    func togglePlayPause() {
        _ = sendCmd?(2, nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.fetchInfo() }
    }
    func previousTrack() {
        _ = sendCmd?(5, nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.fetchInfo() }
    }
    func nextTrack() {
        _ = sendCmd?(4, nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.fetchInfo() }
    }

    func seekTo(_ position: TimeInterval) {
        let pos  = max(0, info.duration > 0 ? min(position, info.duration) : position)
        let opts = ["kMRMediaRemoteOptionPlaybackPosition": pos] as NSDictionary
        _ = sendCmd?(42, opts)
        info.elapsed = pos; elapsedAtFetch = pos; fetchDate = Date()
    }

    func skipBackward(by seconds: TimeInterval = 10) { seekTo(info.elapsed - seconds) }
    func skipForward(by seconds: TimeInterval = 10)  { seekTo(info.elapsed + seconds) }
}
