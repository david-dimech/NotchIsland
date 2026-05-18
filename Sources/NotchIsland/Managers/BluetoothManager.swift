import IOKit
import Foundation

class BluetoothManager: ObservableObject {
    @Published var devices: [BTDeviceInfo] = []

    private var refreshTimer: Timer?

    init() {
        refresh()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
    }

    deinit { refreshTimer?.invalidate() }

    func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let found = Self.scanDevices()
            DispatchQueue.main.async { self?.devices = found }
        }
    }

    // MARK: – IORegistry scan

    private static func scanDevices() -> [BTDeviceInfo] {
        var result: [BTDeviceInfo] = []
        var iter: io_iterator_t = 0

        // IOBluetoothHIDDriver covers AirPods, keyboards, mice, trackpads, etc.
        let matching = IOServiceMatching("IOBluetoothHIDDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return result
        }
        defer { IOObjectRelease(iter) }

        var service = IOIteratorNext(iter)
        while service != 0 {
            defer { IOObjectRelease(service) }

            let name = cfProp(service, "Product") as? String ?? "Unknown Device"

            // Different drivers expose different keys
            let pct: Int? = cfProp(service, "BatteryPercent") as? Int
                         ?? cfProp(service, "DeviceBatteryPercent") as? Int

            if let p = pct {
                result.append(BTDeviceInfo(name: name, batteryPercent: p))
            }
            service = IOIteratorNext(iter)
        }
        return result
    }

    private static func cfProp(_ service: io_object_t, _ key: String) -> AnyObject? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }
}
