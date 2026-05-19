import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = IslandViewModel.shared
        panel = NotchPanel(viewModel: vm)
        panel?.orderFrontRegardless()

        setupMenuBarItem()

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

        let modules: [(String, String, Int)] = [
            ("Media",     "1", 0),
            ("Calendar",  "2", 1),
            ("Battery",   "3", 2),
            ("Timer",     "4", 3),
            ("Weather",   "5", 4),
            ("Bluetooth", "6", 5),
        ]
        for (title, key, _) in modules {
            let item = NSMenuItem(title: title, action: #selector(showModule(_:)), keyEquivalent: key)
            item.tag = modules.firstIndex(where: { $0.0 == title })!
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func showModule(_ sender: NSMenuItem) {
        let all = IslandModule.allCases
        let idx = sender.tag
        guard idx < all.count else { return }
        let mod = all[idx]
        Task { @MainActor in IslandViewModel.shared.toggle(mod) }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: SettingsManager.shared)
            let vc   = NSHostingController(rootView: view)
            let win  = NSWindow(contentViewController: vc)
            win.title = "NotchIsland Settings"
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.setContentSize(NSSize(width: 300, height: 380))
            win.isMovableByWindowBackground = true
            win.center()
            win.appearance = NSAppearance(named: .darkAqua)
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
