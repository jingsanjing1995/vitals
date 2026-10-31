import SwiftUI

// MARK: - Large ring gauge

struct GaugeRing<Center: View>: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let colors: [Color]
    let accent: Color
    var showTicks = false
    var animationDuration: Double = 0.55
    @ViewBuilder let center: Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        let inset: CGFloat = showTicks ? 15 : 0
        let diameter = size - inset * 2
        let radius = diameter / 2
        let angle = clamped * 2 * .pi - .pi / 2

        ZStack {
            if showTicks {
                GaugeTickRing(
                    progress: clamped,
                    diameter: diameter,
                    lineWidth: lineWidth,
                    accent: accent
                )
                .frame(width: size, height: size)
            }

            Circle()
                .stroke(Color.white.opacity(0.055), lineWidth: lineWidth)
                .frame(width: diameter, height: diameter)

            Circle()
                .trim(from: 0, to: max(0.0001, clamped))
                .stroke(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(0.45), radius: 7)

            if clamped > 0.012 {
                Circle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 4.5, height: 4.5)
                    .shadow(color: accent, radius: 5)
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
            }

            center
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("使用率")
        .accessibilityValue("\(Formatters.percent(clamped)) %")
    }
}

struct GaugeTickRing: View {
    let progress: Double
    let diameter: CGFloat
    let lineWidth: CGFloat
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = diameter / 2 + lineWidth / 2 + 4
            let tickCount = 72

            for index in 0..<tickCount {
                let fraction = Double(index) / Double(tickCount)
                let angle = fraction * 2 * .pi - .pi / 2
                let major = index % 6 == 0
                let length: CGFloat = major ? 5.5 : 3
                let start = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                let end = CGPoint(
                    x: center.x + cos(angle) * (radius + length),
                    y: center.y + sin(angle) * (radius + length)
                )

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                let lit = fraction <= progress
                context.stroke(
                    path,
                    with: .color(lit ? accent.opacity(major ? 0.78 : 0.42) : Color.white.opacity(0.09)),
                    style: StrokeStyle(lineWidth: major ? 1.15 : 0.7, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Mini ring gauge

struct MiniGauge: View {
    let value: Double?
    let colors: [Color]
    let accent: Color
    var size: CGFloat = 56
    var lineWidth: CGFloat = 5

    var body: some View {
        GaugeRing(
            progress: value ?? 0,
            size: size,
            lineWidth: lineWidth,
            colors: colors,
            accent: accent,
            animationDuration: 0.45
        ) {
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 0.4) {
                    Text(Formatters.percent(value))
                        .font(.system(size: size * 0.235, weight: .semibold, design: .rounded).monospacedDigit())
                    Text("%")
                        .font(.system(size: size * 0.135, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                .foregroundStyle(Palette.textPrimary)
            } else {
                Text("—")
                    .font(.system(size: size * 0.24, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}

// MARK: - Per-core load bars

struct CoreLoadBars: View {
    let values: [Double]
    let performanceCores: Int
    let efficiencyCores: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.6) {
            if values.isEmpty {
                ForEach(0..<10, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.055))
                        .frame(width: 4.5, height: 24)
                }
            } else {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    if efficiencyCores > 0,
                       index == performanceCores,
                       performanceCores > 0 {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 0.8, height: 18)
                            .padding(.horizontal, 1)
                    }

                    CoreBar(value: value)
                        .help("核心 \(index + 1) · \(Formatters.percent(value))%")
                }
            }
        }
        .frame(height: 24, alignment: .bottom)
    }
}

private struct CoreBar: View {
    let value: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let clamped = min(1, max(0, value))
        let accent = Palette.cpuAccent(clamped)

        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(width: 4.5, height: 24)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.5), accent],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 4.5, height: max(2.5, 24 * clamped))
                .shadow(color: accent.opacity(0.35), radius: 2)
        }
        .frame(width: 4.5, height: 24)
    }
}

// MARK: - History sparkline

struct Sparkline: View {
    let values: [Double]
    let accent: Color
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let points = chartPoints(in: CGSize(width: width, height: height))
            let linePath = smoothPath(points: points)
            let areaPath = filledPath(points: points, height: height)

            ZStack {
                grid(width: width, height: height)
                    .stroke(
                        Color.white.opacity(0.055),
                        style: StrokeStyle(lineWidth: 0.6, dash: [2.5, 4])
                    )

                areaPath
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.24), accent.opacity(0.015)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                linePath
                    .stroke(
                        LinearGradient(
                            colors: [Palette.blue.opacity(0.7), accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: accent.opacity(0.35), radius: 3)

                if let last = points.last {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                        .shadow(color: accent.opacity(0.9), radius: 4)
                        .position(last)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CPU 历史曲线")
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let peak = values.max() ?? 0
        let top = min(1, max(0.2, peak * 1.38))
        let count = max(1, values.count - 1)
        let inset: CGFloat = 2.5

        return values.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(count) * size.width
            let normalized = min(1, max(0, value / top))
            let y = size.height - inset - CGFloat(normalized) * (size.height - inset * 2)
            return CGPoint(x: x, y: y)
        }
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midX = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }
        return path
    }

    private func filledPath(points: [CGPoint], height: CGFloat) -> Path {
        var path = smoothPath(points: points)
        guard let last = points.last, let first = points.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
    }

    private func grid(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        for index in 1...3 {
            let y = height * CGFloat(index) / 4
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        return path
    }
}
