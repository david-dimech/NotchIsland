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
        // Scan both driver classes — deduplicate by name afterwards.
        // IOBluetoothHIDDriver: keyboards, mice, trackpads.
        // IOHIDDevice filtered to Bluetooth transport: AirPods, headsets, some newer devices.
        let combined = scan(serviceClass: "IOBluetoothHIDDriver", requireBTTransport: false)
                     + scan(serviceClass: "IOHIDDevice",          requireBTTransport: true)

        var seen = Set<String>()
        return combined.filter { seen.insert($0.name).inserted }
    }

    private static func scan(serviceClass: String, requireBTTransport: Bool) -> [BTDeviceInfo] {
        var result: [BTDeviceInfo] = []
        var iter: io_iterator_t = 0

        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching(serviceClass), &iter
        ) == KERN_SUCCESS else { return result }
        defer { IOObjectRelease(iter) }

        var service = IOIteratorNext(iter)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iter) }

            if requireBTTransport {
                let transport = cfProp(service, "Transport") as? String ?? ""
                guard transport == "Bluetooth" else { continue }
            }

            guard let name = cfProp(service, "Product") as? String,
                  !name.isEmpty else { continue }

            // Battery keys (in preference order — all are 0–100 %).
            let pct: Int? = (cfProp(service, "BatteryPercent")      as? Int)
                         ?? (cfProp(service, "DeviceBatteryPercent") as? Int)
                         ?? (cfProp(service, "BatteryLevel")         as? Int)

            if let p = pct {
                result.append(BTDeviceInfo(name: name, batteryPercent: p))
            }
        }
        return result
    }

    private static func cfProp(_ service: io_object_t, _ key: String) -> AnyObject? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }
}
