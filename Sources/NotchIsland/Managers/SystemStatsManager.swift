import Foundation
import IOKit
import Darwin

class SystemStatsManager: ObservableObject {
    @Published var stats = SystemStats()

    private var updateTimer: Timer?
    private var prevCPUInfo: processor_info_array_t?
    private var prevCPUInfoCount: mach_msg_type_number_t = 0
    private var prevNetBytes: (up: UInt64, down: UInt64) = (0, 0)
    private var prevNetTime: Date = .distantPast

    init() {
        update()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    deinit {
        updateTimer?.invalidate()
        if let p = prevCPUInfo {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: p), vm_size_t(prevCPUInfoCount))
        }
    }

    private func update() {
        var next = SystemStats()
        next.cpuUsage     = cpuUsage()
        next.memoryUsage  = memoryUsage()
        next.diskUsage    = diskUsage()
        (next.netUpBps, next.netDownBps) = networkThroughput()
        (next.batteryLevel, next.isCharging, next.hasBattery) = batteryInfo()
        DispatchQueue.main.async { self.stats = next }
    }

    // MARK: – CPU

    private func cpuUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &cpuInfo, &numCPUInfo) == KERN_SUCCESS,
              let cpuInfo else { return 0 }

        var usedTicks: Double = 0
        var totalTicks: Double = 0

        if let prev = prevCPUInfo {
            for i in 0..<Int(numCPUs) {
                let base = Int(CPU_STATE_MAX) * i
                let user   = Double(cpuInfo[base + Int(CPU_STATE_USER)]   - prev[base + Int(CPU_STATE_USER)])
                let sys    = Double(cpuInfo[base + Int(CPU_STATE_SYSTEM)] - prev[base + Int(CPU_STATE_SYSTEM)])
                let nice   = Double(cpuInfo[base + Int(CPU_STATE_NICE)]   - prev[base + Int(CPU_STATE_NICE)])
                let idle   = Double(cpuInfo[base + Int(CPU_STATE_IDLE)]   - prev[base + Int(CPU_STATE_IDLE)])
                usedTicks  += user + sys + nice
                totalTicks += user + sys + nice + idle
            }
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(prevCPUInfoCount))
        }

        prevCPUInfo      = cpuInfo
        prevCPUInfoCount = numCPUInfo

        return totalTicks > 0 ? min(usedTicks / totalTicks, 1.0) : 0
    }

    // MARK: – Memory

    private func memoryUsage() -> Double {
        var vmStats = vm_statistics64()
        var count   = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let pageSize  = Double(vm_page_size)
        let used      = Double(vmStats.active_count + vmStats.wire_count) * pageSize
        let total     = Double(ProcessInfo.processInfo.physicalMemory)
        return min(used / total, 1.0)
    }

    // MARK: – Disk

    private func diskUsage() -> Double {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize]     as? Int64, total > 0,
              let free  = attrs[.systemFreeSize] as? Int64 else { return 0 }
        return Double(total - free) / Double(total)
    }

    // MARK: – Network throughput (bytes/sec over all en* interfaces)

    private func networkThroughput() -> (up: Double, down: Double) {
        var ifaddrsPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrsPtr) == 0, let ifaddrsPtr else { return (0, 0) }
        defer { freeifaddrs(ifaddrsPtr) }

        var totalUp:   UInt64 = 0
        var totalDown: UInt64 = 0
        var cursor = ifaddrsPtr
        while true {
            let ifa = cursor.pointee
            if ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifa.ifa_name)
                // Include en (ethernet/wifi), utun (VPN) — skip loopback
                if name.hasPrefix("en") || name.hasPrefix("utun") {
                    if let data = ifa.ifa_data?.assumingMemoryBound(to: if_data.self) {
                        totalUp   += UInt64(data.pointee.ifi_obytes)
                        totalDown += UInt64(data.pointee.ifi_ibytes)
                    }
                }
            }
            guard let next = ifa.ifa_next else { break }
            cursor = next
        }

        let now      = Date()
        let elapsed  = now.timeIntervalSince(prevNetTime)
        let prevUp   = prevNetBytes.up
        let prevDown = prevNetBytes.down
        prevNetBytes = (totalUp, totalDown)
        prevNetTime  = now

        guard elapsed > 0, prevUp > 0 || prevDown > 0 else { return (0, 0) }
        let up   = Double(totalUp   > prevUp   ? totalUp   - prevUp   : 0) / elapsed
        let down = Double(totalDown > prevDown ? totalDown - prevDown : 0) / elapsed
        return (up, down)
    }

    // MARK: – Battery (via IORegistry — avoids IOKit.ps SPM linkage issues)

    private func batteryInfo() -> (level: Double, charging: Bool, hasBattery: Bool) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return (0, false, false) }
        defer { IOObjectRelease(service) }

        func intProp(_ key: String) -> Int {
            (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int) ?? 0
        }
        func boolProp(_ key: String) -> Bool {
            (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Bool) ?? false
        }

        let current  = intProp("CurrentCapacity")
        let maximum  = intProp("MaxCapacity")
        let charging = boolProp("IsCharging")

        guard maximum > 0 else { return (0, false, false) }
        return (Double(current) / Double(maximum), charging, true)
    }
}
