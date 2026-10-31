import Foundation
import SwiftUI

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot: SystemSnapshot
    @Published private(set) var cpuHistory: [Double] = []

    let hardware: HardwareInfo
    private let sampler: SystemSampler
    private var timer: Timer?
    private var previewMode = false
    private(set) var interval: TimeInterval = 1.0

    static let historyLimit = 60

    init(hardware: HardwareInfo = .current(), startImmediately: Bool = true) {
        self.hardware = hardware
        self.sampler = SystemSampler(hardware: hardware)
        self.snapshot = sampler.sample()
        if startImmediately {
            start()
        }
    }

    func start() {
        guard !previewMode, timer == nil else { return }
        let initial = Timer(
            timeInterval: 0.35,
            target: self,
            selector: #selector(initialTick),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(initial, forMode: .common)
        timer = initial
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setInterval(_ newInterval: TimeInterval) {
        let clamped = min(5, max(0.5, newInterval))
        guard clamped != interval else { return }
        interval = clamped
        guard !previewMode else { return }
        stop()
        scheduleRepeatingTimer()
    }

    func applyPreview(snapshot: SystemSnapshot, history: [Double]) {
        previewMode = true
        stop()
        self.snapshot = snapshot
        self.cpuHistory = Array(history.suffix(Self.historyLimit))
    }

    @objc private func initialTick() {
        timer = nil
        tick()
        scheduleRepeatingTimer()
    }

    private func scheduleRepeatingTimer() {
        guard !previewMode, timer == nil else { return }
        let repeating = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        repeating.tolerance = interval * 0.15
        RunLoop.main.add(repeating, forMode: .common)
        timer = repeating
    }

    @objc private func tick() {
        let updated = sampler.sample()
        snapshot = updated
        if sampler.hasCPUBaseline {
            cpuHistory.append(updated.cpu.usage)
            if cpuHistory.count > Self.historyLimit {
                cpuHistory.removeFirst(cpuHistory.count - Self.historyLimit)
            }
        }
    }

    var historyWindowDescription: String {
        let seconds = Int((Double(Self.historyLimit) * interval).rounded())
        if seconds >= 60 {
            let minutes = Double(seconds) / 60
            return minutes.truncatingRemainder(dividingBy: 1) == 0
                ? "近 \(Int(minutes)) 分钟"
                : "近 \(String(format: "%.1f", minutes)) 分钟"
        }
        return "近 \(seconds) 秒"
    }

    var peakCPU: Double {
        cpuHistory.max() ?? snapshot.cpu.usage
    }
}

// MARK: - App-wide settings

@MainActor
final class AppState: ObservableObject {
    let monitor: SystemMonitor

    @Published var isPinned: Bool {
        didSet { persist(isPinned, key: "isPinned") }
    }
    @Published var isCompact: Bool {
        didSet { persist(isCompact, key: "isCompact") }
    }
    @Published var refreshInterval: TimeInterval {
        didSet {
            persist(refreshInterval, key: "refreshInterval")
            monitor.setInterval(refreshInterval)
        }
    }
    @Published var isVisible = true

    private let persistsSettings: Bool
    private static let frameAutosaveName = "VitalsWidgetFrame"

    init(preview: Bool = false, previewCompact: Bool = false) {
        self.persistsSettings = !preview
        let defaults = UserDefaults.standard

        if preview {
            isPinned = true
            isCompact = previewCompact
            refreshInterval = 1
        } else {
            isPinned = defaults.object(forKey: "isPinned") as? Bool ?? false
            isCompact = defaults.object(forKey: "isCompact") as? Bool ?? false
            let storedInterval = defaults.object(forKey: "refreshInterval") as? Double ?? 1
            refreshInterval = [0.5, 1.0, 2.0, 5.0].contains(storedInterval) ? storedInterval : 1
        }

        monitor = SystemMonitor(startImmediately: false)
        monitor.setInterval(refreshInterval)
        if preview {
            monitor.applyPreview(
                snapshot: PreviewData.snapshot(hardware: monitor.hardware),
                history: PreviewData.history
            )
        } else {
            monitor.start()
        }
    }

    func togglePinned() {
        isPinned.toggle()
    }

    func toggleCompact() {
        isCompact.toggle()
    }

    func hideWidget() {
        isVisible = false
    }

    func showWidget() {
        isVisible = true
    }

    func resetWindowPosition() {
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(Self.frameAutosaveName)")
        NotificationCenter.default.post(name: .vitalsResetWindowPosition, object: nil)
    }

    private func persist<T>(_ value: T, key: String) {
        guard persistsSettings else { return }
        UserDefaults.standard.set(value, forKey: key)
    }
}

extension Notification.Name {
    static let vitalsResetWindowPosition = Notification.Name("vitals.resetWindowPosition")
}

// MARK: - Deterministic preview content

enum PreviewData {
    static let history: [Double] = {
        (0..<60).map { index in
            let wave = sin(Double(index) * 0.31) * 0.12
            let pulse = sin(Double(index) * 0.09 + 1.2) * 0.07
            let spikes: [Int: Double] = [9: 0.26, 10: 0.34, 11: 0.22, 31: 0.3, 32: 0.38, 33: 0.28, 49: 0.18]
            let base = 0.24 + wave + pulse + (spikes[index] ?? 0)
            return min(0.86, max(0.04, base))
        }
    }()

    static func snapshot(hardware: HardwareInfo) -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        snapshot.cpu = CPUStats(
            usage: 0.237,
            user: 0.148,
            system: 0.053,
            idle: 0.799,
            cores: [0.42, 0.18, 0.31, 0.55, 0.12, 0.08, 0.23, 0.16, 0.09, 0.05],
            loadAverage1: 1.24,
            loadAverage5: 1.08,
            loadAverage15: 0.96
        )
        let totalMemory = max(hardware.memoryBytes, 16 * 1024 * 1024 * 1024)
        let usedMemory = Int64(Double(totalMemory) * 0.571)
        snapshot.memory = MemoryStats(
            total: totalMemory,
            used: usedMemory,
            app: Int64(Double(usedMemory) * 0.63),
            wired: Int64(Double(usedMemory) * 0.24),
            compressed: Int64(Double(usedMemory) * 0.13),
            swapUsed: 512 * 1024 * 1024,
            swapTotal: 2048 * 1024 * 1024
        )
        snapshot.gpu = GPUStats(
            usage: 0.34,
            allocatedMemory: 2_400_000_000,
            model: hardware.chipName
        )
        snapshot.disk = DiskStats(
            total: 2_000_000_000_000,
            free: 1_163_000_000_000
        )
        snapshot.network = NetworkStats(
            downloadBytesPerSecond: 1_460_000,
            uploadBytesPerSecond: 186_000,
            primaryInterface: "en0"
        )
        snapshot.uptime = 3 * 86_400 + 7 * 3_600 + 42 * 60
        snapshot.thermal = .nominal
        return snapshot
    }
}
