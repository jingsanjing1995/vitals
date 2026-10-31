import Foundation

struct WidgetModel {
    let date: Date
    let snapshot: SystemSnapshot
    let hardware: HardwareInfo

    var cpu: Double { snapshot.cpu.usage }
    var memoryUsage: Double { snapshot.memory.usage }
    var gpuUsage: Double? { snapshot.gpu.usage }
    var diskUsage: Double { snapshot.disk.usage }

    var updateTime: String {
        WidgetFormatting.timeFormatter.string(from: date)
    }

    var shortChip: String {
        let name = hardware.chipName
        if name.hasPrefix("Apple ") {
            return String(name.dropFirst("Apple ".count))
        }
        return name
    }

    var memoryDetail: String {
        "\(Formatters.memoryCompact(snapshot.memory.used)) / \(Formatters.memoryTotal(snapshot.memory.total))"
    }

    var gpuDetail: String {
        guard gpuUsage != nil else { return "不可用" }
        if let cores = hardware.gpuCores {
            return "\(cores) 核"
        }
        return "统一内存"
    }

    var diskDetail: String {
        "可用 \(Formatters.diskCompact(snapshot.disk.free))"
    }

    var networkDown: String {
        Formatters.networkRateCompact(snapshot.network.downloadBytesPerSecond)
    }

    var networkUp: String {
        Formatters.networkRateCompact(snapshot.network.uploadBytesPerSecond)
    }

    static var placeholder: WidgetModel {
        let hardware = HardwareInfo.current()
        var snapshot = SystemSnapshot()
        let totalMemory = max(hardware.memoryBytes, 16 * 1024 * 1024 * 1024)
        let usedMemory = Int64(Double(totalMemory) * 0.64)
        snapshot.cpu = CPUStats(
            usage: 0.28,
            user: 0.17,
            system: 0.06,
            idle: 0.77,
            cores: [0.42, 0.18, 0.31, 0.55, 0.12, 0.08, 0.23, 0.16, 0.09, 0.05],
            loadAverage1: 1.42,
            loadAverage5: 1.18,
            loadAverage15: 1.02
        )
        snapshot.memory = MemoryStats(
            total: totalMemory,
            used: usedMemory,
            app: Int64(Double(usedMemory) * 0.64),
            wired: Int64(Double(usedMemory) * 0.23),
            compressed: Int64(Double(usedMemory) * 0.13),
            swapUsed: 384 * 1024 * 1024,
            swapTotal: 2 * 1024 * 1024 * 1024
        )
        snapshot.gpu = GPUStats(usage: 0.34, allocatedMemory: 2_100_000_000, model: hardware.chipName)
        snapshot.disk = DiskStats(total: 2_000_000_000_000, free: 1_280_000_000_000)
        snapshot.network = NetworkStats(
            downloadBytesPerSecond: 1_460_000,
            uploadBytesPerSecond: 186_000,
            primaryInterface: "en0"
        )
        snapshot.uptime = 3 * 86_400 + 7 * 3_600 + 42 * 60
        snapshot.thermal = .nominal
        return WidgetModel(date: Date(), snapshot: snapshot, hardware: hardware)
    }
}

enum WidgetFormatting {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func percent(_ value: Double) -> String {
        "\(Formatters.percent(value))%"
    }

    static func load(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
