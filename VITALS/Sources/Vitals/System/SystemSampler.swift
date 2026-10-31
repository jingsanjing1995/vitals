import Foundation
import IOKit
import IOKit.ps
import Darwin

// MARK: - IOKit helpers

enum GPUReader {
    struct Reading {
        var usage: Double?
        var allocatedMemory: Int64?
        var model: String?
    }

    static func read() -> Reading {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == KERN_SUCCESS else {
            return Reading()
        }
        defer { IOObjectRelease(iterator) }

        var best = Reading()
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let rawStats = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            let device = number(rawStats["Device Utilization %"])
            let renderer = number(rawStats["Renderer Utilization %"])
            let tiler = number(rawStats["Tiler Utilization %"])
            let usage = device ?? renderer ?? tiler

            let allocated = int64(rawStats["Alloc system memory"])
                ?? int64(rawStats["In use system memory"])

            let model = IORegistryEntryCreateCFProperty(
                service,
                "model" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? String

            let reading = Reading(
                usage: usage.map { min(1, max(0, $0 / 100)) },
                allocatedMemory: allocated,
                model: model
            )

            if reading.usage != nil {
                return reading
            }
            if best.usage == nil {
                best = reading
            }
        }
        return best
    }

    static func coreCount() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let value = IORegistryEntryCreateCFProperty(
                service,
                "gpu-core-count" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? NSNumber {
                IOObjectRelease(service)
                return value.intValue
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Int { return Double(value) }
        if let value = value as? Double { return value }
        return nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        return nil
    }
}

enum BatteryReader {
    static func read() -> BatteryStats? {
        guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(powerSourcesInfo, source)?
                .takeUnretainedValue() as? [String: Any] else {
                continue
            }
            guard (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else {
                continue
            }

            let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue ?? 0
            let maxCapacity = (description[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue ?? 100
            let percentage = maxCapacity > 0 ? min(1, current / maxCapacity) : 0
            let isCharging = (description[kIOPSIsChargingKey] as? NSNumber)?.boolValue
                ?? (description[kIOPSIsChargingKey] as? Bool)
                ?? false
            let powerSource = description[kIOPSPowerSourceStateKey] as? String
            let isOnAC = powerSource == kIOPSACPowerValue

            var minutes: Int?
            if isCharging {
                if let value = (description[kIOPSTimeToFullChargeKey] as? NSNumber)?.intValue, value > 0 {
                    minutes = value
                }
            } else if let value = (description[kIOPSTimeToEmptyKey] as? NSNumber)?.intValue, value > 0 {
                minutes = value
            }

            return BatteryStats(
                percentage: percentage,
                isCharging: isCharging,
                isOnAC: isOnAC,
                minutesRemaining: minutes
            )
        }
        return nil
    }
}

// MARK: - Sampler

final class SystemSampler {
    struct CPUTicks {
        var user: UInt64
        var system: UInt64
        var nice: UInt64
        var idle: UInt64
    }

    struct NetworkCounters {
        var received: UInt32
        var sent: UInt32
    }

    let hardware: HardwareInfo
    private(set) var hasCPUBaseline = false

    private var previousCPUTicks: [CPUTicks]?
    private var previousNetwork: [String: NetworkCounters] = [:]
    private var cachedDisk = DiskStats()
    private var lastDiskSample = Date.distantPast
    private let pageSize: Int64

    init(hardware: HardwareInfo) {
        self.hardware = hardware
        self.pageSize = Int64(sysconf(_SC_PAGESIZE))
    }

    func sample() -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        snapshot.cpu = sampleCPU()
        snapshot.memory = sampleMemory()
        let gpu = GPUReader.read()
        snapshot.gpu = GPUStats(
            usage: gpu.usage,
            allocatedMemory: gpu.allocatedMemory,
            model: gpu.model
        )
        if Date().timeIntervalSince(lastDiskSample) >= 12 || cachedDisk.total == 0 {
            cachedDisk = sampleDisk()
            lastDiskSample = Date()
        }
        snapshot.disk = cachedDisk
        snapshot.network = sampleNetwork()
        snapshot.uptime = ProcessInfo.processInfo.systemUptime
        snapshot.thermal = mapThermal(ProcessInfo.processInfo.thermalState)
        snapshot.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        snapshot.battery = BatteryReader.read()
        snapshot.timestamp = Date()
        return snapshot
    }

    // MARK: CPU

    private func sampleCPU() -> CPUStats {
        var stats = CPUStats()
        let loads = loadAverages()
        stats.loadAverage1 = loads.0
        stats.loadAverage5 = loads.1
        stats.loadAverage15 = loads.2

        guard let current = readCPUTicks(), !current.isEmpty else {
            return stats
        }

        if let previous = previousCPUTicks, previous.count == current.count {
            var totalUser: Double = 0
            var totalSystem: Double = 0
            var totalIdle: Double = 0
            var coreUsages: [Double] = []
            coreUsages.reserveCapacity(current.count)

            for (now, before) in zip(current, previous) {
                let user = delta(now.user, before.user)
                let system = delta(now.system, before.system)
                let nice = delta(now.nice, before.nice)
                let idle = delta(now.idle, before.idle)
                let total = Double(user + system + nice + idle)

                if total > 0 {
                    let active = Double(user + system + nice)
                    coreUsages.append(min(1, max(0, active / total)))
                    totalUser += Double(user + nice)
                    totalSystem += Double(system)
                    totalIdle += Double(idle)
                } else {
                    coreUsages.append(0)
                }
            }

            let grandTotal = totalUser + totalSystem + totalIdle
            if grandTotal > 0 {
                stats.user = totalUser / grandTotal
                stats.system = totalSystem / grandTotal
                stats.idle = totalIdle / grandTotal
                stats.usage = min(1, max(0, 1 - stats.idle))
                stats.cores = coreUsages
                hasCPUBaseline = true
            }
        } else {
            stats.cores = Array(repeating: 0, count: current.count)
        }

        previousCPUTicks = current
        return stats
    }

    private func readCPUTicks() -> [CPUTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )
        guard result == KERN_SUCCESS, let info else { return nil }

        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                size
            )
        }

        let stateCount = Int(CPU_STATE_MAX)
        var ticks: [CPUTicks] = []
        ticks.reserveCapacity(Int(cpuCount))

        for core in 0..<Int(cpuCount) {
            let base = core * stateCount
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            ticks.append(CPUTicks(user: user, system: system, nice: nice, idle: idle))
        }
        return ticks
    }

    private func delta(_ now: UInt64, _ before: UInt64) -> UInt64 {
        now >= before ? now - before : 0
    }

    private func loadAverages() -> (Double, Double, Double) {
        var values = [Double](repeating: 0, count: 3)
        let count = getloadavg(&values, 3)
        guard count > 0 else { return (0, 0, 0) }
        return (
            count > 0 ? values[0] : 0,
            count > 1 ? values[1] : 0,
            count > 2 ? values[2] : 0
        )
    }

    // MARK: Memory

    private func sampleMemory() -> MemoryStats {
        var stats = MemoryStats()
        stats.total = hardware.memoryBytes

        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        if result == KERN_SUCCESS {
            let appPages = vmStats.internal_page_count > vmStats.purgeable_count
                ? vmStats.internal_page_count - vmStats.purgeable_count
                : 0
            stats.app = Int64(appPages) * pageSize
            stats.wired = Int64(vmStats.wire_count) * pageSize
            stats.compressed = Int64(vmStats.compressor_page_count) * pageSize
            let used = stats.app + stats.wired + stats.compressed
            stats.used = min(stats.total, max(0, used))
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.stride
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            stats.swapUsed = Int64(swap.xsu_used)
            stats.swapTotal = Int64(swap.xsu_total)
        }
        return stats
    }

    // MARK: Disk

    private func sampleDisk() -> DiskStats {
        var stats = DiskStats()
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else {
            return stats
        }
        if let total = values.volumeTotalCapacity {
            stats.total = Int64(total)
        }
        if let free = values.volumeAvailableCapacityForImportantUsage {
            stats.free = free
        } else if let free = values.volumeAvailableCapacity {
            stats.free = Int64(free)
        }
        return stats
    }

    // MARK: Network

    private func sampleNetwork() -> NetworkStats {
        var stats = NetworkStats()
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let first = addressPointer else {
            return stats
        }
        defer { freeifaddrs(addressPointer) }

        var current: [String: NetworkCounters] = [:]
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = pointer {
            defer { pointer = interface.pointee.ifa_next }
            let name = String(cString: interface.pointee.ifa_name)
            guard name.hasPrefix("en"),
                  let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let data = interface.pointee.ifa_data else {
                continue
            }
            let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
            current[name] = NetworkCounters(
                received: interfaceData.ifi_ibytes,
                sent: interfaceData.ifi_obytes
            )
        }

        var download: Double = 0
        var upload: Double = 0
        for (name, counters) in current {
            guard let before = previousNetwork[name] else { continue }
            download += Double(counterDelta(counters.received, before.received))
            upload += Double(counterDelta(counters.sent, before.sent))
        }
        previousNetwork = current
        stats.downloadBytesPerSecond = download
        stats.uploadBytesPerSecond = upload
        stats.primaryInterface = current.max(by: {
            (UInt64($0.value.received) + UInt64($0.value.sent))
                < (UInt64($1.value.received) + UInt64($1.value.sent))
        })?.key
        return stats
    }

    private func counterDelta(_ now: UInt32, _ before: UInt32) -> UInt32 {
        now >= before ? now - before : (UInt32.max - before) &+ now &+ 1
    }

    // MARK: Thermal

    private func mapThermal(_ state: ProcessInfo.ThermalState) -> ThermalLevel {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .fair
        }
    }
}
