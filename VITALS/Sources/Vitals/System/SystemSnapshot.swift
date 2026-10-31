import Foundation

// MARK: - Snapshot value types

struct CPUStats {
    var usage: Double = 0
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 1
    var cores: [Double] = []
    var loadAverage1: Double = 0
    var loadAverage5: Double = 0
    var loadAverage15: Double = 0
}

struct MemoryStats {
    var total: Int64 = 0
    var used: Int64 = 0
    var app: Int64 = 0
    var wired: Int64 = 0
    var compressed: Int64 = 0
    var swapUsed: Int64 = 0
    var swapTotal: Int64 = 0

    var usage: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    var free: Int64 {
        max(0, total - used)
    }
}

struct GPUStats {
    var usage: Double?
    var allocatedMemory: Int64?
    var model: String?
}

struct DiskStats {
    var total: Int64 = 0
    var free: Int64 = 0

    var used: Int64 {
        max(0, total - free)
    }

    var usage: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }
}

struct NetworkStats {
    var downloadBytesPerSecond: Double = 0
    var uploadBytesPerSecond: Double = 0
    var primaryInterface: String?
}

struct BatteryStats {
    var percentage: Double
    var isCharging: Bool
    var isOnAC: Bool
    var minutesRemaining: Int?
}

enum ThermalLevel: String {
    case nominal
    case fair
    case serious
    case critical

    var label: String {
        switch self {
        case .nominal: return "正常"
        case .fair: return "偏热"
        case .serious: return "较热"
        case .critical: return "过热"
        }
    }

    var symbol: String {
        switch self {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "thermometer.high"
        }
    }
}

struct SystemSnapshot {
    var cpu = CPUStats()
    var memory = MemoryStats()
    var gpu = GPUStats()
    var disk = DiskStats()
    var network = NetworkStats()
    var uptime: TimeInterval = 0
    var thermal: ThermalLevel = .nominal
    var lowPowerMode = false
    var battery: BatteryStats?
    var timestamp = Date()
}

// MARK: - Hardware description

struct HardwareInfo {
    let chipName: String
    let modelName: String
    let modelIdentifier: String
    let totalCores: Int
    let performanceCores: Int
    let efficiencyCores: Int
    let gpuCores: Int?
    let memoryBytes: Int64
    let macOSVersion: String

    var coreSummary: String {
        if efficiencyCores > 0 {
            return "\(totalCores) 核 · \(performanceCores)P + \(efficiencyCores)E"
        }
        return "\(totalCores) 核"
    }

    var memoryDescription: String {
        Formatters.memorySize(memoryBytes)
    }

    static func current() -> HardwareInfo {
        let modelIdentifier = Sysctl.string("hw.model") ?? "Mac"
        let chip = Sysctl.string("machdep.cpu.brand_string") ?? "Apple Silicon"
        let totalCores = Sysctl.int("hw.physicalcpu")
            ?? Sysctl.int("hw.ncpu")
            ?? ProcessInfo.processInfo.processorCount
        let performanceCores = Sysctl.int("hw.perflevel0.physicalcpu") ?? totalCores
        let efficiencyCores = Sysctl.int("hw.perflevel1.physicalcpu") ?? 0
        let memory = UInt64(Sysctl.int64("hw.memsize") ?? 0)
        let version = ProcessInfo.processInfo.operatingSystemVersion

        return HardwareInfo(
            chipName: chip,
            modelName: HardwareInfo.friendlyModelName(for: modelIdentifier),
            modelIdentifier: modelIdentifier,
            totalCores: totalCores,
            performanceCores: performanceCores,
            efficiencyCores: efficiencyCores,
            gpuCores: GPUReader.coreCount(),
            memoryBytes: Int64(memory),
            macOSVersion: "macOS \(version.majorVersion).\(version.minorVersion)"
        )
    }

    private static func friendlyModelName(for identifier: String) -> String {
        let known: [String: String] = [
            "Mac16,10": "Mac mini",
            "Mac16,11": "Mac mini",
            "Mac16,12": "MacBook Air",
            "Mac16,13": "MacBook Air",
            "Mac16,1": "MacBook Pro",
            "Mac16,2": "MacBook Pro",
            "Mac16,3": "MacBook Pro",
            "Mac16,5": "MacBook Pro",
            "Mac16,6": "MacBook Pro",
            "Mac16,7": "MacBook Pro",
            "Mac16,8": "MacBook Pro",
            "Mac15,3": "MacBook Pro",
            "Mac15,4": "iMac",
            "Mac15,5": "iMac",
            "Mac15,6": "MacBook Pro",
            "Mac15,7": "MacBook Pro",
            "Mac15,8": "MacBook Pro",
            "Mac15,9": "MacBook Pro",
            "Mac15,10": "MacBook Pro",
            "Mac15,11": "MacBook Pro",
            "Mac15,12": "MacBook Air",
            "Mac15,13": "MacBook Air",
            "Mac14,2": "MacBook Air",
            "Mac14,3": "Mac mini",
            "Mac14,4": "MacBook Air",
            "Mac14,5": "MacBook Pro",
            "Mac14,6": "MacBook Pro",
            "Mac14,7": "MacBook Pro",
            "Mac14,8": "Mac Studio",
            "Mac14,9": "MacBook Pro",
            "Mac14,10": "MacBook Pro",
            "Mac14,11": "Mac Studio",
            "Mac14,12": "Mac mini",
            "Mac14,13": "Mac Studio",
            "Mac14,14": "Mac Studio",
            "Mac14,15": "MacBook Air",
            "Mac13,1": "Mac Studio",
            "Mac13,2": "Mac Studio",
            "Mac13,3": "MacBook Air",
            "iMac21,1": "iMac",
            "iMac21,2": "iMac",
            "MacPro7,1": "Mac Pro",
            "Macmini9,1": "Mac mini"
        ]
        return known[identifier] ?? identifier
    }
}

// MARK: - Small system helpers

enum Sysctl {
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    static func int(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    static func int64(_ name: String) -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}

enum Formatters {
    private static let memorialByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private static let fileByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useTB, .useGB, .useMB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static func memorySize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        return memorialByteFormatter.string(fromByteCount: bytes)
            .replacingOccurrences(of: " ", with: " ")
    }

    static func diskSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        return fileByteFormatter.string(fromByteCount: bytes)
            .replacingOccurrences(of: " ", with: " ")
    }

    static func memoryCompact(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 100 {
            return String(format: "%.0f GB", gb)
        }
        return String(format: "%.1f GB", gb)
    }

    static func memoryTotal(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.0f GB", gb)
    }

    static func diskCompact(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let tb = Double(bytes) / 1_000_000_000_000
        if tb >= 1 {
            return String(format: "%.1f TB", tb)
        }
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 100 {
            return String(format: "%.0f GB", gb)
        }
        return String(format: "%.1f GB", gb)
    }

    static func percent(_ value: Double, decimals: Int = 0) -> String {
        let clamped = min(1, max(0, value)) * 100
        return String(format: "%.\(decimals)f", clamped)
    }

    static func load(_ value: Double) -> String {
        String(format: "%.2f", max(0, value))
    }

    static func networkRate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 1 else { return "0 KB/s" }
        let kb = bytesPerSecond / 1024
        if kb < 1000 {
            return kb < 10 ? String(format: "%.1f KB/s", kb) : String(format: "%.0f KB/s", kb)
        }
        let mb = kb / 1024
        if mb < 1000 {
            return mb < 10 ? String(format: "%.1f MB/s", mb) : String(format: "%.0f MB/s", mb)
        }
        let gb = mb / 1024
        return String(format: "%.2f GB/s", gb)
    }

    static func networkRateCompact(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 1 else { return "0 KB/s" }
        let kb = bytesPerSecond / 1024
        if kb < 1000 {
            return kb < 10 ? String(format: "%.1f K/s", kb) : String(format: "%.0f K/s", kb)
        }
        let mb = kb / 1024
        if mb < 1000 {
            return mb < 10 ? String(format: "%.1f M/s", mb) : String(format: "%.0f M/s", mb)
        }
        return String(format: "%.2f G/s", mb / 1024)
    }

    static func uptime(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds) / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return "\(days)天 \(hours)小时" }
        if hours > 0 { return "\(hours)小时 \(minutes)分" }
        return "\(minutes)分"
    }

    static func uptimeCompact(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds) / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return String(format: "%dd %02dh", days, hours) }
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        return "\(minutes)m"
    }
}
