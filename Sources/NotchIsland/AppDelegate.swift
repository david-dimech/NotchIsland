import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = IslandViewModel.shared
        panel = NotchPanel(viewModel: vm)
        panel?.orderFrontRegardless()

        setupMenuBarItem()

        // Re-position if the user switches displays or resolution
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionPanel),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func repositionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let x = screen.frame.midX - kWindowWidth / 2
        let y = screen.frame.maxY - kWindowHeight
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem?.button {
            btn.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "NotchIsland")
        }

        let menu = NSMenu()

        let nowPlayingItem = NSMenuItem(title: "Now Playing", action: #selector(showNowPlaying), keyEquivalent: "1")
        let statsItem      = NSMenuItem(title: "System Stats", action: #selector(showStats), keyEquivalent: "2")
        let timerItem      = NSMenuItem(title: "Timer", action: #selector(showTimer), keyEquivalent: "3")
        menu.addItem(nowPlayingItem)
        menu.addItem(statsItem)
        menu.addItem(timerItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func showNowPlaying() {
        Task { @MainActor in IslandViewModel.shared.toggle(.nowPlaying) }
    }
    @objc private func showStats() {
        Task { @MainActor in IslandViewModel.shared.toggle(.systemStats) }
    }
    @objc private func showTimer() {
        Task { @MainActor in IslandViewModel.shared.toggle(.timer) }
    }
}
