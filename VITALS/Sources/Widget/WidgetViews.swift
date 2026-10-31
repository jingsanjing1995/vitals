import SwiftUI

// MARK: - Background

struct WidgetBackground: View {
    var body: some View {
        ZStack {
            Color(hex: 0x080F1C)
            LinearGradient(
                colors: [
                    Color(hex: 0x101D33).opacity(0.96),
                    Color(hex: 0x080D18).opacity(0.98),
                    Color(hex: 0x05080F)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Palette.cyan.opacity(0.20), .clear],
                center: UnitPoint(x: 0.04, y: 0.0),
                startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [Palette.violet.opacity(0.20), .clear],
                center: UnitPoint(x: 1.05, y: 0.78),
                startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [Palette.magenta.opacity(0.08), .clear],
                center: UnitPoint(x: 0.3, y: 1.08),
                startRadius: 0,
                endRadius: 240
            )
            LinearGradient(
                colors: [Color.white.opacity(0.045), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.26)
            )
        }
    }
}

// MARK: - Small widget

struct WidgetSmallView: View {
    let model: WidgetModel

    var body: some View {
        GeometryReader { geometry in
            let dial = min(68, max(52, geometry.size.width * 0.38))
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    WidgetLiveDot(color: Palette.cpuAccent(model.cpu))
                    Text("VITALS")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .tracking(1.7)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: 2)
                    Text(model.shortChip)
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }

                Spacer(minLength: 3)

                HStack(spacing: 9) {
                    WidgetDial(
                        title: "CPU",
                        value: model.cpu,
                        colors: Palette.cpuColors(model.cpu),
                        accent: Palette.cpuAccent(model.cpu),
                        size: dial
                    )
                    WidgetDial(
                        title: "内存",
                        value: model.memoryUsage,
                        colors: Palette.memoryColors(model.memoryUsage),
                        accent: Palette.violet,
                        size: dial
                    )
                }

                Spacer(minLength: 3)

                HStack(spacing: 4) {
                    Text(model.memoryDetail)
                    Spacer(minLength: 2)
                    Text("更新 \(model.updateTime)")
                }
                .font(.system(size: 7.2, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
        }
    }
}

private struct WidgetDial: View {
    let title: String
    let value: Double
    let colors: [Color]
    let accent: Color
    let size: CGFloat

    var body: some View {
        VStack(spacing: 3) {
            GaugeRing(
                progress: value,
                size: size,
                lineWidth: 5,
                colors: colors,
                accent: accent
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 0.2) {
                    Text(Formatters.percent(value))
                        .font(.system(size: size * 0.25, weight: .semibold, design: .rounded).monospacedDigit())
                    Text("%")
                        .font(.system(size: size * 0.13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }
                .foregroundStyle(Palette.textPrimary)
            }

            Text(title)
                .font(.system(size: 7.2, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - Medium widget

struct WidgetMediumView: View {
    let model: WidgetModel

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(88, max(70, geometry.size.height * 0.53))
            VStack(spacing: 0) {
                WidgetHeader(model: model, compact: false)

                Spacer(minLength: 5)

                HStack(spacing: 13) {
                    VStack(spacing: 4) {
                        GaugeRing(
                            progress: model.cpu,
                            size: ringSize,
                            lineWidth: 6,
                            colors: Palette.cpuColors(model.cpu),
                            accent: Palette.cpuAccent(model.cpu),
                            showTicks: false
                        ) {
                            VStack(spacing: 1) {
                                HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                                    Text(Formatters.percent(model.cpu))
                                        .font(.system(size: ringSize * 0.27, weight: .semibold, design: .rounded).monospacedDigit())
                                    Text("%")
                                        .font(.system(size: ringSize * 0.12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Palette.textTertiary)
                                }
                                .foregroundStyle(Palette.textPrimary)
                                Text("CPU")
                                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                                    .tracking(1.0)
                                    .foregroundStyle(Palette.textTertiary)
                            }
                        }

                        Text("负载 \(WidgetFormatting.load(model.snapshot.cpu.loadAverage1)) · \(model.hardware.totalCores) 核")
                            .font(.system(size: 7, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(Palette.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(width: 100)

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 0.7, height: ringSize)
                        .padding(.vertical, 2)

                    VStack(spacing: 7) {
                        WidgetMetricRow(
                            title: "内存",
                            symbol: "memorychip",
                            value: model.memoryUsage,
                            colors: Palette.memoryColors(model.memoryUsage),
                            accent: Palette.violet,
                            detail: model.memoryDetail,
                            help: "应用 \(Formatters.memorySize(model.snapshot.memory.app)) · 联动 \(Formatters.memorySize(model.snapshot.memory.wired))"
                        )
                        WidgetMetricRow(
                            title: "GPU",
                            symbol: "display",
                            value: model.gpuUsage,
                            colors: Palette.gpuColors(model.gpuUsage ?? 0),
                            accent: Palette.cyan,
                            detail: model.gpuDetail,
                            help: "GPU 利用率"
                        )
                        WidgetMetricRow(
                            title: "存储",
                            symbol: "internaldrive",
                            value: model.diskUsage,
                            colors: Palette.diskColors(model.diskUsage),
                            accent: Palette.amber,
                            detail: model.diskDetail,
                            help: "已用 \(Formatters.diskSize(model.snapshot.disk.used))，共 \(Formatters.diskSize(model.snapshot.disk.total))"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

private struct WidgetMetricRow: View {
    let title: String
    let symbol: String
    let value: Double?
    let colors: [Color]
    let accent: Color
    let detail: String
    let help: String

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.92))
                    .frame(width: 9)
                Text(title)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 2)
                Text(detail)
                    .font(.system(size: 7, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
                Text(value.map { "\(Formatters.percent($0))%" } ?? "—")
                    .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 30, alignment: .trailing)
            }

            WidgetProgressBar(value: value ?? 0, colors: colors, accent: accent)
                .frame(height: 3)
        }
        .help(help)
    }
}

private struct WidgetProgressBar: View {
    let value: Double
    let colors: [Color]
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.065))
                Capsule()
                    .fill(
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(3, geometry.size.width * min(1, max(0, value))))
                    .shadow(color: accent.opacity(0.35), radius: 2)
            }
        }
    }
}

// MARK: - Large widget

struct WidgetLargeView: View {
    let model: WidgetModel

    var body: some View {
        GeometryReader { geometry in
            let heroHeight = min(148, max(118, geometry.size.height * 0.37))
            let metricHeight = min(92, max(76, geometry.size.height * 0.23))
            let infoHeight = min(82, max(64, geometry.size.height * 0.205))
            let ringSize = min(132, heroHeight - 12)
            VStack(spacing: 0) {
                WidgetHeader(model: model, compact: false)

                HStack(spacing: 14) {
                    GaugeRing(
                        progress: model.cpu,
                        size: ringSize,
                        lineWidth: 8,
                        colors: Palette.cpuColors(model.cpu),
                        accent: Palette.cpuAccent(model.cpu),
                        showTicks: true
                    ) {
                        VStack(spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                                Text(Formatters.percent(model.cpu))
                                    .font(.system(size: ringSize * 0.27, weight: .semibold, design: .rounded).monospacedDigit())
                                Text("%")
                                    .font(.system(size: ringSize * 0.11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.textTertiary)
                            }
                            .foregroundStyle(Palette.textPrimary)
                            Text("CPU 负载")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .tracking(1.0)
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text("用户")
                                .foregroundStyle(Palette.textTertiary)
                            Text("\(Formatters.percent(model.snapshot.cpu.user, decimals: 1))%")
                                .foregroundStyle(Palette.textSecondary)
                            Text("系统")
                                .foregroundStyle(Palette.textTertiary)
                            Text("\(Formatters.percent(model.snapshot.cpu.system, decimals: 1))%")
                                .foregroundStyle(Palette.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 7.5, weight: .medium, design: .rounded).monospacedDigit())

                        Spacer(minLength: 5)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("平均负载")
                                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.textTertiary)
                            Text(WidgetFormatting.load(model.snapshot.cpu.loadAverage1))
                                .font(.system(size: 15, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(Palette.textSecondary)
                            Text("1m")
                                .font(.system(size: 6.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textTertiary)
                        }

                        Spacer(minLength: 6)

                        Text("每核负载")
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.textTertiary)
                            .padding(.bottom, 3)

                        CoreLoadBars(
                            values: model.snapshot.cpu.cores,
                            performanceCores: model.hardware.performanceCores,
                            efficiencyCores: model.hardware.efficiencyCores
                        )

                        Text(model.hardware.coreSummary)
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.textTertiary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: heroHeight)
                .padding(.top, 7)

                HStack(spacing: 7) {
                    WidgetLargeMetricCard(
                        title: "内存",
                        symbol: "memorychip",
                        value: model.memoryUsage,
                        colors: Palette.memoryColors(model.memoryUsage),
                        accent: Palette.violet,
                        detail: model.memoryDetail
                    )
                    WidgetLargeMetricCard(
                        title: "GPU",
                        symbol: "display",
                        value: model.gpuUsage,
                        colors: Palette.gpuColors(model.gpuUsage ?? 0),
                        accent: Palette.cyan,
                        detail: model.gpuDetail
                    )
                    WidgetLargeMetricCard(
                        title: "存储",
                        symbol: "internaldrive",
                        value: model.diskUsage,
                        colors: Palette.diskColors(model.diskUsage),
                        accent: Palette.amber,
                        detail: model.diskDetail
                    )
                }
                .frame(height: metricHeight)
                .padding(.top, 9)

                Spacer(minLength: 4)

                HStack(alignment: .top, spacing: 8) {
                    hardwareCard
                    networkCard
                }
                .frame(height: infoHeight)

                Text("点击小组件打开实时面板 · 约每分钟请求刷新")
                    .font(.system(size: 6.4, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
    }

    private var hardwareCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Palette.cyan.opacity(0.9))
                Text("硬件")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
                Text(model.hardware.modelName)
                    .font(.system(size: 7.2, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
            }
            HStack(spacing: 4) {
                Text(model.hardware.chipName)
                    .foregroundStyle(Palette.textSecondary)
                Text("·")
                Text(model.hardware.coreSummary)
                Text("·")
                Text(Formatters.memoryTotal(model.hardware.memoryBytes))
            }
            .font(.system(size: 7.2, weight: .medium, design: .rounded))
            .foregroundStyle(Palette.textTertiary)
            .lineLimit(1)
            if let gpuCores = model.hardware.gpuCores {
                HStack(spacing: 4) {
                    Text("GPU \(gpuCores) 核")
                    Text("·")
                    Text(model.hardware.macOSVersion)
                    Text("·")
                    Text("运行 \(Formatters.uptimeCompact(model.snapshot.uptime))")
                }
                .font(.system(size: 7.2, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(radius: 13, tint: Palette.cyan)
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(Palette.mint.opacity(0.9))
                Text("网络")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
            }
            HStack(spacing: 3) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(Palette.mint.opacity(0.9))
                Text(model.networkDown)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 2)
                Image(systemName: "arrow.up")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(Palette.cyan.opacity(0.9))
                Text(model.networkUp)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
            }
            Text("热状态 \(model.snapshot.thermal.label) · 更新 \(model.updateTime)")
                .font(.system(size: 6.8, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 133)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .glassCard(radius: 13, tint: Palette.mint)
    }
}

private struct WidgetLargeMetricCard: View {
    let title: String
    let symbol: String
    let value: Double?
    let colors: [Color]
    let accent: Color
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.9))
                Text(title)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            MiniGauge(
                value: value,
                colors: colors,
                accent: accent,
                size: 44,
                lineWidth: 4.5
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(detail)
                .font(.system(size: 7.2, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(radius: 13, tint: accent)
    }
}

// MARK: - Shared widget pieces

private struct WidgetHeader: View {
    let model: WidgetModel
    let compact: Bool

    var body: some View {
        HStack(spacing: 5) {
            WidgetLiveDot(color: Palette.cpuAccent(model.cpu))
            Text("VITALS")
                .font(.system(size: compact ? 9.5 : 10, weight: .heavy, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(Palette.textPrimary)
            Text("· \(model.hardware.modelName)")
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 3)
            Text("更新 \(model.updateTime)")
                .font(.system(size: 7, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.textTertiary)
        }
    }
}

private struct WidgetLiveDot: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 12, height: 12)
            Circle()
                .fill(color)
                .frame(width: 4.5, height: 4.5)
                .shadow(color: color.opacity(0.8), radius: 3)
        }
    }
}
