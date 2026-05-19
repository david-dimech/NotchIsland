import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var moduleOrder:   [IslandModule]
    @Published var hiddenModules: Set<IslandModule>

    private static let orderKey  = "ni.widgetOrder"
    private static let hiddenKey = "ni.hiddenWidgets"

    private init() {
        let defaults = UserDefaults.standard

        // Load saved order, appending any modules added in newer versions
        if let raw = defaults.stringArray(forKey: Self.orderKey) {
            var loaded = raw.compactMap { IslandModule(rawValue: $0) }
            for mod in IslandModule.allCases where !loaded.contains(mod) {
                loaded.append(mod)
            }
            moduleOrder = loaded
        } else {
            moduleOrder = IslandModule.allCases
        }

        if let raw = defaults.stringArray(forKey: Self.hiddenKey) {
            hiddenModules = Set(raw.compactMap { IslandModule(rawValue: $0) })
        } else {
            hiddenModules = []
        }
    }

    // Ordered list of modules the user has not hidden
    var enabledModules: [IslandModule] {
        moduleOrder.filter { !hiddenModules.contains($0) }
    }

    func isEnabled(_ module: IslandModule) -> Bool { !hiddenModules.contains(module) }

    func toggle(_ module: IslandModule) {
        if hiddenModules.contains(module) { hiddenModules.remove(module) }
        else                              { hiddenModules.insert(module) }
        save()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        moduleOrder.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    private func save() {
        UserDefaults.standard.set(moduleOrder.map(\.rawValue), forKey: Self.orderKey)
        UserDefaults.standard.set(Array(hiddenModules).map(\.rawValue), forKey: Self.hiddenKey)
    }
}
