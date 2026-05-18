import AppKit
import Darwin

// Uses the private MediaRemote.framework — the same approach as Alcove, Notchmeister, etc.
// Apple provides no public API for system-wide now-playing on macOS.
class NowPlayingManager: ObservableObject {
    @Published var info = NowPlayingInfo()

    private typealias GetInfoFn      = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias GetPlayingFn   = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias SendCommandFn  = @convention(c) (Int, AnyObject?) -> Bool

    private var getInfo: GetInfoFn?
    private var getPlaying: GetPlayingFn?
    private var sendCmd: SendCommandFn?

    private let mrHandle: UnsafeMutableRawPointer?

    // Progress interpolation — updated every 0.5 s while playing
    private var progressTimer: Timer?
    private var fetchDate:     Date         = .distantPast
    private var elapsedAtFetch: TimeInterval = 0

    init() {
        mrHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        loadSymbols()
        observeNotifications()
        fetchInfo()
        startProgressTimer()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        progressTimer?.invalidate()
        if let h = mrHandle { dlclose(h) }
    }

    // MARK: – Private

    private func loadSymbols() {
        guard let h = mrHandle else { return }

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
        for name in names {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(fetchInfo),
                name: NSNotification.Name(name),
                object: nil
            )
        }
    }

    @objc func fetchInfo() {
        getInfo?(.main) { [weak self] raw in
            guard let self else { return }
            var next = NowPlayingInfo()
            next.title    = raw["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            next.artist   = raw["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            next.duration = raw["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0
            next.elapsed  = raw["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0
            if let data = raw["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                next.artwork = NSImage(data: data)
            }
            self.getPlaying?(.main) { isPlaying in
                next.isPlaying = isPlaying
                DispatchQueue.main.async {
                    self.elapsedAtFetch = next.elapsed
                    self.fetchDate      = Date()
                    self.info = next
                }
            }
        }
    }

    // MARK: – Progress interpolation

    private func startProgressTimer() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.info.isPlaying, self.info.duration > 0 else { return }
            let interpolated = self.elapsedAtFetch + Date().timeIntervalSince(self.fetchDate)
            self.info.elapsed = min(interpolated, self.info.duration)
        }
        RunLoop.main.add(t, forMode: .common)
        progressTimer = t
    }

    // MARK: – Controls (MRCommand values from MediaRemote private header)

    func togglePlayPause() { _ = sendCmd?(2, nil) }
    func previousTrack()   { _ = sendCmd?(5, nil) }
    func nextTrack()       { _ = sendCmd?(4, nil) }
}
