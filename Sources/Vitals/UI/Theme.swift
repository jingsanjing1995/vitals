import SwiftUI
import AppKit

private struct PreviewRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var vitalsPreviewRendering: Bool {
        get { self[PreviewRenderingKey.self] }
        set { self[PreviewRenderingKey.self] = newValue }
    }
}

// MARK: - Palette

enum Palette {
    static let cyan = Color(hex: 0x66E7FF)
    static let blue = Color(hex: 0x5A8DFF)
    static let violet = Color(hex: 0xA78BFA)
    static let magenta = Color(hex: 0xFF77D2)
    static let mint = Color(hex: 0x68F0C0)
    static let amber = Color(hex: 0xFFC96B)
    static let orange = Color(hex: 0xFF9A62)
    static let red = Color(hex: 0xFF6F7D)

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.32)
    static let hairline = Color.white.opacity(0.07)

    static func cpuColors(_ value: Double) -> [Color] {
        if value >= 0.82 { return [amber, red, magenta] }
        if value >= 0.62 { return [mint, amber, orange] }
        return [cyan, blue, violet]
    }

    static func cpuAccent(_ value: Double) -> Color {
        if value >= 0.82 { return red }
        if value >= 0.62 { return amber }
        return cyan
    }

    static func memoryColors(_ value: Double) -> [Color] {
        value >= 0.9 ? [violet, magenta, red] : [violet, blue]
    }

    static func gpuColors(_ value: Double) -> [Color] {
        value >= 0.85 ? [cyan, amber, red] : [mint, cyan, blue]
    }

    static func diskColors(_ value: Double) -> [Color] {
        value >= 0.9 ? [amber, red] : [amber, orange]
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Surface

struct WidgetCardBackground: View {
    @Environment(\.vitalsPreviewRendering) private var previewRendering

    var body: some View {
        ZStack {
            if !previewRendering {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            }
            LinearGradient(
                colors: [
                    Color(hex: 0x0B1222).opacity(0.84),
                    Color(hex: 0x070A13).opacity(0.93)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Palette.cyan.opacity(0.18), .clear],
                center: UnitPoint(x: 0.06, y: 0.02),
                startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [Palette.violet.opacity(0.16), .clear],
                center: UnitPoint(x: 1.0, y: 0.52),
                startRadius: 0,
                endRadius: 330
            )
            RadialGradient(
                colors: [Palette.magenta.opacity(0.075), .clear],
                center: UnitPoint(x: 0.18, y: 1.02),
                startRadius: 0,
                endRadius: 250
            )
            LinearGradient(
                colors: [Color.white.opacity(0.055), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.32)
            )
        }
    }
}

struct WidgetBorder: View {
    var cornerRadius: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.white.opacity(0.05),
                        Palette.violet.opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

// MARK: - Shared small components

struct LiveDot: View {
    var color: Color = Palette.cyan
    var size: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: size * 2.8, height: size * 2.8)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.8), radius: 4)
        }
        .accessibilityHidden(true)
    }
}

struct MicroLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .tracking(1.15)
            .foregroundStyle(Palette.textTertiary)
    }
}

struct GlassIconButton: View {
    let systemName: String
    let help: String
    var active = false
    var tint: Color = Palette.cyan
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(active ? tint : Color.white.opacity(hovering ? 0.82 : 0.55))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(active ? tint.opacity(0.15) : Color.white.opacity(hovering ? 0.10 : 0.055))
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            active ? tint.opacity(0.34) : Color.white.opacity(hovering ? 0.13 : 0.07),
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = 17
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.055),
                                Color.white.opacity(0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
    }
}

extension View {
    func glassCard(radius: CGFloat = 17, tint: Color = .white) -> some View {
        modifier(GlassCardModifier(radius: radius, tint: tint))
    }
}

struct StatusPill: View {
    let symbol: String
    let text: String
    var tint: Color = Palette.textSecondary

    var body: some View {
        HStack(spacing: 3.5) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.055), lineWidth: 0.7)
        )
    }
}
