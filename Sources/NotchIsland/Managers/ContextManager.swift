import AppKit
import Combine

// Watches the frontmost application and surfaces the most relevant island module.
class ContextManager: ObservableObject {
    @Published var suggestedModule: IslandModule = .systemStats
    @Published var frontmostBundleId: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        NSWorkspace.shared.publisher(for: \.frontmostApplication)
            .compactMap { $0?.bundleIdentifier }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] bundleId in
                self?.frontmostBundleId = bundleId
                self?.suggestedModule   = Self.module(for: bundleId)
            }
            .store(in: &cancellables)
    }

    private static func module(for bundleId: String) -> IslandModule {
        let id = bundleId.lowercased()

        // Music / media players → show now playing
        if id.contains("music")    ||
           id.contains("spotify")  ||
           id.contains("tidal")    ||
           id.contains("deezer")   ||
           id.contains("vlc")      ||
           id.contains("podcasts") ||
           id.contains("vox")      { return .nowPlaying }

        // Heavy CPU apps → show system stats
        if id.contains("xcode")      ||
           id.contains("simulator")  ||
           id.contains("unity")      ||
           id.contains("blender")    ||
           id.contains("ffmpeg")     ||
           id.contains("resolve")    { return .systemStats }

        // Productivity / focus → show timer
        if id.contains("notion")   ||
           id.contains("obsidian") ||
           id.contains("bear")     ||
           id.contains("craft")    ||
           id.contains("things")   ||
           id.contains("reminders"){ return .timer }

        return .systemStats
    }
}
