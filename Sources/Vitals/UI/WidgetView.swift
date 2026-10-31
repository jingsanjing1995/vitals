import SwiftUI
import AppKit

enum WidgetLayout {
    static let fullSize = CGSize(width: 380, height: 612)
    static let compactSize = CGSize(width: 344, height: 150)
    static let cornerRadius: CGFloat = 30
}

struct WidgetView: View {
    @ObservedObject var state: AppState
    @ObservedObject var monitor: SystemMonitor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if state.isCompact {
                CompactWidgetView(state: state, monitor: monitor)
            } else {
                FullWidgetView(state: state, monitor: monitor)
            }
        }
        .background(WidgetCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: WidgetLayout.cornerRadius, style: .continuous))
        .overlay(WidgetBorder(cornerRadius: WidgetLayout.cornerRadius))
        .overlay(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.28), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 128, height: 0.8)
                .padding(.top, 1)
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: state.isCompact)
        .contextMenu {
            Button(state.isVisible ? "隐藏仪表盘" : "显示仪表盘") {
                state.isVisible.toggle()
            }
            Button(state.isPinned ? "固定在桌面" : "悬浮于窗口之上") {
                state.togglePinned()
            }
            Button(state.isCompact ? "展开仪表盘" : "紧凑模式") {
                state.toggleCompact()
            }
            Divider()
            Button("退出 VITALS") {
                NSApp.terminate(nil)
            }
        }
    }
}

// MARK: - Full layout

private struct FullWidgetView: View {
    @ObservedObject var state: AppState
    @ObservedObject var monitor: SystemMonitor

    private var snapshot: SystemSnapshot { monitor.snapshot }
    private var hardware: HardwareInfo { monitor.hardware }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)

            CPUHeroView(
                cpu: snapshot.cpu,
                hardware: hardware
            )
            .frame(height: 196)
            .padding(.horizontal, 20)

            metrics
                .frame(height: 128)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            activity
                .frame(height: 104)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Spacer(minLength: 10)

            footer
                .padding(.horizontal, 20)
                .padding(.bottom, 15)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    LiveDot(size: 5.5)
                    Text("VITALS")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .tracking(2.6)
                        .foregroundStyle(Palette.textPrimary)
                }
                HStack(spacing: 4) {
                    Text(hardware.modelName)
                    Text("·")
                    Text(hardware.memoryDescription)
                    Text("·")
                    Text("每 \(intervalLabel) 秒刷新")
                }
                .font(.system(size: 8.2, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                GlassIconButton(
                    systemName: state.isPinned ? "pin.fill" : "pin.slash",
                    help: state.isPinned ? "取消置顶，固定在桌面" : "悬浮于窗口之上",
                    active: state.isPinned
                ) {
                    state.togglePinned()
                }

                GlassIconButton(
                    systemName: "rectangle.compress.vertical",
                    help: "紧凑模式"
                ) {
                    state.toggleCompact()
                }

                GlassIconButton(
                    systemName: "xmark",
                    help: "隐藏仪表盘"
                ) {
                    state.hideWidget()
                }
            }
            .padding(.top, 1)
        }
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            MetricCard(
                title: "内存",
                symbol: "memorychip",
                value: snapshot.memory.usage,
                colors: Palette.memoryColors(snapshot.memory.usage),
                accent: Palette.violet,
                detail: "\(Formatters.memoryCompact(snapshot.memory.used)) / \(Formatters.memoryTotal(snapshot.memory.total))",
                help: memoryHelp
            )

            MetricCard(
                title: "GPU",
                symbol: "display",
                value: snapshot.gpu.usage,
                colors: Palette.gpuColors(snapshot.gpu.usage ?? 0),
                accent: Palette.cyan,
                detail: gpuDetail,
                help: gpuHelp
            )

            MetricCard(
                title: "存储",
                symbol: "internaldrive",
                value: snapshot.disk.usage,
                colors: Palette.diskColors(snapshot.disk.usage),
                accent: Palette.amber,
                detail: "可用 \(Formatters.diskCompact(snapshot.disk.free))",
                help: "已用 \(Formatters.diskSize(snapshot.disk.used))，共 \(Formatters.diskSize(snapshot.disk.total))"
            )
        }
    }

    private var activity: some View {
        HStack(spacing: 8) {
            chartCard
            networkCard
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("CPU 历史")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(monitor.historyWindowDescription)
                    .font(.system(size: 7.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
            }

            Sparkline(
                values: monitor.cpuHistory,
                accent: Palette.cpuAccent(snapshot.cpu.usage),
                lineWidth: 1.5
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 4) {
                Text("峰值")
                Text("\(Formatters.percent(monitor.peakCPU))%")
                    .foregroundStyle(Palette.cpuAccent(monitor.peakCPU).opacity(0.9))
                Spacer()
                Text("\(monitor.cpuHistory.count) 个采样")
            }
            .font(.system(size: 7.5, weight: .medium, design: .rounded))
            .foregroundStyle(Palette.textTertiary)
            .monospacedDigit()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .glassCard(radius: 17, tint: Palette.cyan)
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Palette.mint.opacity(0.9))
                Text("网络")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 5)

            NetworkRateRow(
                symbol: "arrow.down",
                label: "下行",
                rate: snapshot.network.downloadBytesPerSecond,
                tint: Palette.mint
            )

            Spacer(minLength: 4)

            NetworkRateRow(
                symbol: "arrow.up",
                label: "上行",
                rate: snapshot.network.uploadBytesPerSecond,
                tint: Palette.cyan
            )

            Spacer(minLength: 4)

            HStack(spacing: 3) {
                Circle()
                    .fill(Palette.mint.opacity(0.8))
                    .frame(width: 3, height: 3)
                Text(snapshot.network.primaryInterface ?? "LIVE")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: 108)
        .glassCard(radius: 17, tint: Palette.mint)
        .help("网络吞吐 · \(Formatters.networkRate(snapshot.network.downloadBytesPerSecond)) 下行 · \(Formatters.networkRate(snapshot.network.uploadBytesPerSecond)) 上行")
    }

    private var footer: some View {
        VStack(spacing: 9) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.12), Color.white.opacity(0.03), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.7)

            HStack(spacing: 6) {
                StatusPill(
                    symbol: "clock",
                    text: Formatters.uptimeCompact(snapshot.uptime)
                )
                StatusPill(
                    symbol: snapshot.thermal.symbol,
                    text: "热状态 \(snapshot.thermal.label)",
                    tint: thermalTint
                )
                if let battery = snapshot.battery {
                    StatusPill(
                        symbol: battery.isCharging ? "battery.100percent.bolt" : batterySymbol(battery.percentage),
                        text: "\(Formatters.percent(battery.percentage))%",
                        tint: battery.isCharging ? Palette.mint : Palette.textSecondary
                    )
                }
                if snapshot.lowPowerMode {
                    StatusPill(
                        symbol: "bolt.fill",
                        text: "低电量模式",
                        tint: Palette.amber
                    )
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                Text(hardware.chipName.uppercased())
                    .foregroundStyle(Palette.textSecondary.opacity(0.75))
                Text("·")
                Text(hardware.coreSummary)
                if let gpuCores = hardware.gpuCores {
                    Text("·")
                    Text("GPU \(gpuCores) 核")
                }
                Spacer(minLength: 0)
                Text(hardware.macOSVersion)
            }
            .font(.system(size: 7.2, weight: .medium, design: .rounded))
            .tracking(0.3)
            .foregroundStyle(Palette.textTertiary)
            .lineLimit(1)
        }
    }

    private var intervalLabel: String {
        monitor.interval == floor(monitor.interval)
            ? String(Int(monitor.interval))
            : String(format: "%.1f", monitor.interval)
    }

    private var memoryHelp: String {
        let memory = snapshot.memory
        var text = "应用 \(Formatters.memorySize(memory.app)) · 联动 \(Formatters.memorySize(memory.wired)) · 压缩 \(Formatters.memorySize(memory.compressed))"
        if memory.swapTotal > 0 {
            text += "\n交换空间 \(Formatters.memorySize(memory.swapUsed)) / \(Formatters.memorySize(memory.swapTotal))"
        }
        return text
    }

    private var gpuDetail: String {
        guard snapshot.gpu.usage != nil else { return "不可用" }
        if let cores = hardware.gpuCores { return "\(cores) 核 · 统一内存" }
        return "统一内存"
    }

    private var gpuHelp: String {
        guard let usage = snapshot.gpu.usage else { return "当前设备未提供 GPU 使用率" }
        let memory = snapshot.gpu.allocatedMemory.map { "\n显存占用 \(Formatters.memorySize($0))" } ?? ""
        return "GPU 利用率 \(Formatters.percent(usage, decimals: 1))%\(memory)"
    }

    private var thermalTint: Color {
        switch snapshot.thermal {
        case .nominal: return Palette.mint.opacity(0.88)
        case .fair: return Palette.amber
        case .serious: return Palette.orange
        case .critical: return Palette.red
        }
    }

    private func batterySymbol(_ value: Double) -> String {
        switch value {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

// MARK: - CPU hero

private struct CPUHeroView: View {
    let cpu: CPUStats
    let hardware: HardwareInfo

    private var accent: Color { Palette.cpuAccent(cpu.usage) }
    private var colors: [Color] { Palette.cpuColors(cpu.usage) }

    var body: some View {
        HStack(spacing: 18) {
            GaugeRing(
                progress: cpu.usage,
                size: 174,
                lineWidth: 10,
                colors: colors,
                accent: accent,
                showTicks: true
            ) {
                VStack(spacing: 5) {
                    Image(systemName: "cpu")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accent.opacity(0.55), radius: 7)

                    Text("CPU")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(Palette.textSecondary)

                    HStack(spacing: 3) {
                        Circle()
                            .fill(accent)
                            .frame(width: 3, height: 3)
                        Text("LIVE")
                            .font(.system(size: 6.5, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(accent.opacity(0.8))
                    }
                }
            }
            .frame(width: 174, height: 174)

            VStack(alignment: .leading, spacing: 0) {
                MicroLabel(text: "CPU 负载")

                HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                    Text(Formatters.percent(cpu.usage, decimals: 1))
                        .font(.system(size: 37, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.textPrimary)
                    Text("%")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }
                .padding(.top, 1)
                .lineLimit(1)

                HStack(spacing: 9) {
                    LegendValue(color: Palette.cyan, label: "用户", value: cpu.user)
                    LegendValue(color: Palette.violet, label: "系统", value: cpu.system)
                }
                .padding(.top, 4)

                Rectangle()
                    .fill(Color.white.opacity(0.065))
                    .frame(height: 0.7)
                    .padding(.vertical, 7)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("平均负载")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                    Spacer(minLength: 2)
                    Text(Formatters.load(cpu.loadAverage1))
                        .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.textSecondary)
                    Text("1m")
                        .font(.system(size: 6.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }

                Spacer(minLength: 4)

                Text("每核负载")
                    .font(.system(size: 7.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.bottom, 4)

                CoreLoadBars(
                    values: cpu.cores,
                    performanceCores: hardware.performanceCores,
                    efficiencyCores: hardware.efficiencyCores
                )

                Text(hardware.coreSummary)
                    .font(.system(size: 7.2, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.top, 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LegendValue: View {
    let color: Color
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .shadow(color: color.opacity(0.7), radius: 2)
            Text(label)
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
            Text("\(Formatters.percent(value, decimals: 1))%")
                .font(.system(size: 8, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
        }
        .lineLimit(1)
    }
}

// MARK: - Metric cards

private struct MetricCard: View {
    let title: String
    let symbol: String
    let value: Double?
    let colors: [Color]
    let accent: Color
    let detail: String
    let help: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.92))
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 3)

            MiniGauge(
                value: value,
                colors: colors,
                accent: accent,
                size: 57,
                lineWidth: 5
            )
            .frame(maxWidth: .infinity)

            Spacer(minLength: 3)

            Text(detail)
                .font(.system(size: 8, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(radius: 17, tint: accent)
        .help(help)
    }
}

// MARK: - Network

private struct NetworkRateRow: View {
    let symbol: String
    let label: String
    let rate: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(tint.opacity(0.9))
                .frame(width: 9)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
                Text(Formatters.networkRateCompact(rate))
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

// MARK: - Compact layout

private struct CompactWidgetView: View {
    @ObservedObject var state: AppState
    @ObservedObject var monitor: SystemMonitor

    private var snapshot: SystemSnapshot { monitor.snapshot }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                LiveDot(size: 5)
                Text("VITALS")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Palette.textPrimary)
                Text("· \(monitor.hardware.modelName)")
                    .font(.system(size: 7.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                GlassIconButton(
                    systemName: "rectangle.expand.vertical",
                    help: "展开仪表盘"
                ) {
                    state.toggleCompact()
                }
                GlassIconButton(
                    systemName: "xmark",
                    help: "隐藏仪表盘"
                ) {
                    state.hideWidget()
                }
            }

            HStack(spacing: 13) {
                CompactGauge(
                    title: "CPU",
                    value: snapshot.cpu.usage,
                    colors: Palette.cpuColors(snapshot.cpu.usage),
                    accent: Palette.cpuAccent(snapshot.cpu.usage)
                )

                CompactGauge(
                    title: "内存",
                    value: snapshot.memory.usage,
                    colors: Palette.memoryColors(snapshot.memory.usage),
                    accent: Palette.violet
                )

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.7, height: 55)

                VStack(alignment: .leading, spacing: 5) {
                    NetworkRateRow(
                        symbol: "arrow.down",
                        label: "下行",
                        rate: snapshot.network.downloadBytesPerSecond,
                        tint: Palette.mint
                    )
                    NetworkRateRow(
                        symbol: "arrow.up",
                        label: "上行",
                        rate: snapshot.network.uploadBytesPerSecond,
                        tint: Palette.cyan
                    )
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 7, weight: .medium))
                        Text(Formatters.uptimeCompact(snapshot.uptime))
                            .font(.system(size: 7.3, weight: .medium, design: .rounded).monospacedDigit())
                    }
                    .foregroundStyle(Palette.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 82)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct CompactGauge: View {
    let title: String
    let value: Double
    let colors: [Color]
    let accent: Color

    var body: some View {
        VStack(spacing: 3) {
            GaugeRing(
                progress: value,
                size: 62,
                lineWidth: 5,
                colors: colors,
                accent: accent,
                animationDuration: 0.4
            ) {
                Text("\(Formatters.percent(value))%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
            }

            Text(title)
                .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(width: 66)
    }
}
