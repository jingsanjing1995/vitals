import SwiftUI
import AppKit

@MainActor
enum PreviewRenderer {
    enum RenderError: LocalizedError {
        case failedToEncode

        var errorDescription: String? {
            switch self {
            case .failedToEncode: return "无法编码预览图"
            }
        }
    }

    static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let normal = AppState(preview: true)
        let compact = AppState(preview: true, previewCompact: true)

        let stage = PreviewStage(normalState: normal, compactState: compact)
        try write(stage, size: CGSize(width: 1_020, height: 760), to: directory.appendingPathComponent("preview.png"))

        let full = SinglePreview(state: normal, compact: false)
        try write(full, size: CGSize(width: 580, height: 760), to: directory.appendingPathComponent("preview-full.png"))

        let compactOnly = SinglePreview(state: compact, compact: true)
        try write(compactOnly, size: CGSize(width: 600, height: 330), to: directory.appendingPathComponent("preview-compact.png"))

        let widgetStage = WidgetPreviewStage(model: .placeholder)
        try write(widgetStage, size: CGSize(width: 760, height: 590), to: directory.appendingPathComponent("widget-preview.png"))

        try write(
            SingleWidgetPreview(model: .placeholder, family: .small),
            size: CGSize(width: 330, height: 300),
            to: directory.appendingPathComponent("widget-small.png")
        )
        try write(
            SingleWidgetPreview(model: .placeholder, family: .medium),
            size: CGSize(width: 520, height: 300),
            to: directory.appendingPathComponent("widget-medium.png")
        )
        try write(
            SingleWidgetPreview(model: .placeholder, family: .large),
            size: CGSize(width: 520, height: 500),
            to: directory.appendingPathComponent("widget-large.png")
        )
    }

    private static func write<V: View>(_ view: V, size: CGSize, to url: URL) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.failedToEncode
        }
        try png.write(to: url, options: .atomic)
    }
}

private struct PreviewStage: View {
    let normalState: AppState
    let compactState: AppState

    var body: some View {
        ZStack {
            PreviewWallpaper()

            HStack(alignment: .center, spacing: 52) {
                WidgetView(state: normalState, monitor: normalState.monitor)
                    .frame(width: WidgetLayout.fullSize.width, height: WidgetLayout.fullSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: WidgetLayout.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.55), radius: 34, x: 0, y: 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text("COMPACT")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(2.6)
                        .foregroundStyle(Color.white.opacity(0.3))

                    WidgetView(state: compactState, monitor: compactState.monitor)
                        .frame(width: WidgetLayout.compactSize.width, height: WidgetLayout.compactSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: .black.opacity(0.45), radius: 26, x: 0, y: 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("点击右上角图标收起为紧凑模式")
                        Text("右键任意位置可快速切换状态")
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.32))
                }
                .padding(.top, 30)
            }
            .padding(.horizontal, 38)
        }
        .environment(\.vitalsPreviewRendering, true)
    }
}

private struct SinglePreview: View {
    let state: AppState
    let compact: Bool

    var body: some View {
        ZStack {
            PreviewWallpaper()

            WidgetView(state: state, monitor: state.monitor)
                .frame(
                    width: compact ? WidgetLayout.compactSize.width : WidgetLayout.fullSize.width,
                    height: compact ? WidgetLayout.compactSize.height : WidgetLayout.fullSize.height
                )
                .clipShape(RoundedRectangle(cornerRadius: WidgetLayout.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.55), radius: 36, x: 0, y: 24)
        }
        .environment(\.vitalsPreviewRendering, true)
    }
}

private enum WidgetPreviewFamily {
    case small, medium, large
}

private struct WidgetCard: View {
    let model: WidgetModel
    let family: WidgetPreviewFamily

    var body: some View {
        Group {
            switch family {
            case .small:
                WidgetSmallView(model: model)
                    .frame(width: 170, height: 170)
            case .medium:
                WidgetMediumView(model: model)
                    .frame(width: 364, height: 170)
            case .large:
                WidgetLargeView(model: model)
                    .frame(width: 364, height: 382)
            }
        }
        .background(WidgetBackground())
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
        )
    }
}

private struct WidgetPreviewStage: View {
    let model: WidgetModel

    var body: some View {
        ZStack {
            PreviewWallpaper()

            VStack(spacing: 22) {
                HStack(alignment: .center, spacing: 30) {
                    WidgetCard(model: model, family: .small)
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 14)
                    WidgetCard(model: model, family: .medium)
                        .shadow(color: .black.opacity(0.5), radius: 22, x: 0, y: 16)
                }
                WidgetCard(model: model, family: .large)
                    .shadow(color: .black.opacity(0.55), radius: 28, x: 0, y: 20)
            }
        }
        .environment(\.vitalsPreviewRendering, true)
    }
}

private struct SingleWidgetPreview: View {
    let model: WidgetModel
    let family: WidgetPreviewFamily

    var body: some View {
        ZStack {
            PreviewWallpaper()
            WidgetCard(model: model, family: family)
                .shadow(color: .black.opacity(0.55), radius: 30, x: 0, y: 20)
        }
        .environment(\.vitalsPreviewRendering, true)
    }
}

private struct PreviewWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x0C1222),
                    Color(hex: 0x070A13),
                    Color(hex: 0x04060B)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Palette.blue.opacity(0.32), .clear],
                center: UnitPoint(x: 0.16, y: 0.05),
                startRadius: 0,
                endRadius: 470
            )

            RadialGradient(
                colors: [Palette.violet.opacity(0.24), .clear],
                center: UnitPoint(x: 0.96, y: 0.72),
                startRadius: 0,
                endRadius: 500
            )

            Ellipse()
                .fill(Palette.cyan.opacity(0.055))
                .frame(width: 760, height: 320)
                .blur(radius: 90)
                .rotationEffect(.degrees(-18))
                .offset(x: -220, y: 280)

            Canvas { context, size in
                var path = Path()
                let spacing: CGFloat = 26
                var x: CGFloat = 0
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(.white.opacity(0.012)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
}
