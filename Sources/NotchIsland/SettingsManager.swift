import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var moduleOrder:    [IslandModule]
    @Published var hiddenModules:  Set<IslandModule>
    @Published var timerSoundName: String

    // Todoist
    @Published var todoistAPIToken:      String
    @Published var todoistAlertsEnabled: Bool

    // Notification intercept
    @Published var notifInterceptEnabled: Bool
    @Published var notifBypassDND:        Bool
    @Published var notifAllowedApps:      [String]  // empty = allow all

    private static let orderKey         = "ni.widgetOrder"
    private static let hiddenKey        = "ni.hiddenWidgets"
    private static let soundKey         = "ni.timerSound"
    private static let todoistTokenKey   = "ni.todoistToken"
    private static let todoistAlertKey   = "ni.todoistAlerts"
    private static let notifEnabledKey  = "ni.notifIntercept"
    private static let notifDNDKey      = "ni.notifBypassDND"
    private static let notifAppsKey     = "ni.notifApps"

    // .settings is always pinned last and is not user-reorderable
    private static let reorderable = IslandModule.allCases.filter { $0 != .settings }

    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Pop",
        "Purr", "Sosumi", "Submarine", "Tink"
    ]

    private init() {
        let defaults = UserDefaults.standard

        if let raw = defaults.stringArray(forKey: Self.orderKey) {
            var loaded = raw.compactMap { IslandModule(rawValue: $0) }.filter { $0 != .settings }
            for mod in Self.reorderable where !loaded.contains(mod) { loaded.append(mod) }
            moduleOrder = loaded
        } else {
            moduleOrder = Self.reorderable
        }

        if let raw = defaults.stringArray(forKey: Self.hiddenKey) {
            hiddenModules = Set(raw.compactMap { IslandModule(rawValue: $0) }.filter { $0 != .settings })
        } else {
            hiddenModules = []
        }

        timerSoundName        = defaults.string(forKey: Self.soundKey)        ?? "Glass"
        todoistAPIToken        = defaults.string(forKey: Self.todoistTokenKey)  ?? ""
        todoistAlertsEnabled   = defaults.object(forKey: Self.todoistAlertKey)  as? Bool ?? true
        notifInterceptEnabled  = defaults.object(forKey: Self.notifEnabledKey) as? Bool ?? false
        notifBypassDND         = defaults.object(forKey: Self.notifDNDKey)     as? Bool ?? false
        notifAllowedApps       = defaults.stringArray(forKey: Self.notifAppsKey) ?? []
    }

    // Ordered visible modules (excludes .settings — ExpandedIslandView appends it separately)
    var enabledModules: [IslandModule] {
        moduleOrder.filter { !hiddenModules.contains($0) }
    }

    func isEnabled(_ module: IslandModule) -> Bool { !hiddenModules.contains(module) }

    func toggle(_ module: IslandModule) {
        guard module != .settings else { return }
        if hiddenModules.contains(module) { hiddenModules.remove(module) }
        else                              { hiddenModules.insert(module) }
        save()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        moduleOrder.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    func setTimerSound(_ name: String) {
        timerSoundName = name
        UserDefaults.standard.set(name, forKey: Self.soundKey)
    }

    func setTodoistToken(_ token: String) {
        todoistAPIToken = token
        UserDefaults.standard.set(token, forKey: Self.todoistTokenKey)
    }

    func setTodoistAlerts(_ on: Bool) {
        todoistAlertsEnabled = on
        UserDefaults.standard.set(on, forKey: Self.todoistAlertKey)
    }

    func setNotifIntercept(_ on: Bool) {
        notifInterceptEnabled = on
        UserDefaults.standard.set(on, forKey: Self.notifEnabledKey)
    }

    func setNotifBypassDND(_ on: Bool) {
        notifBypassDND = on
        UserDefaults.standard.set(on, forKey: Self.notifDNDKey)
    }

    func setNotifAllowedApps(_ apps: [String]) {
        notifAllowedApps = apps
        UserDefaults.standard.set(apps, forKey: Self.notifAppsKey)
    }

    // MARK: – DND detection (best-effort, reads NC prefs — works for apps not in sandbox)
    var systemDNDActive: Bool {
        UserDefaults(suiteName: "com.apple.notificationcenterui")?
            .bool(forKey: "doNotDisturb") ?? false
    }

    private func save() {
        UserDefaults.standard.set(moduleOrder.map(\.rawValue), forKey: Self.orderKey)
        UserDefaults.standard.set(Array(hiddenModules).map(\.rawValue), forKey: Self.hiddenKey)
    }
}
