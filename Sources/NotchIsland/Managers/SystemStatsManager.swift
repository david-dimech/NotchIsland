import Foundation
import IOKit
import Darwin

class SystemStatsManager: ObservableObject {
    @Published var stats = SystemStats()

    private var updateTimer: Timer?
    private var prevCPUInfo: processor_info_array_t?
    private var prevCPUInfoCount: mach_msg_type_number_t = 0

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
