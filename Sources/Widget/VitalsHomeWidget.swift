import WidgetKit
import SwiftUI

struct VitalsWidgetEntry: TimelineEntry {
    let date: Date
    let model: WidgetModel
}

struct VitalsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VitalsWidgetEntry {
        VitalsWidgetEntry(date: Date(), model: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (VitalsWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let model = Self.sampleModel()
        completion(VitalsWidgetEntry(date: model.date, model: model))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VitalsWidgetEntry>) -> Void) {
        Task {
            let model = await Self.sampleModelAsync()
            let entry = VitalsWidgetEntry(date: model.date, model: model)
            let nextRefresh = Date().addingTimeInterval(60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private static func sampleModel() -> WidgetModel {
        let hardware = HardwareInfo.current()
        let sampler = SystemSampler(hardware: hardware)
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 0.08)
        let snapshot = sampler.sample()
        return WidgetModel(date: Date(), snapshot: snapshot, hardware: hardware)
    }

    private static func sampleModelAsync() async -> WidgetModel {
        let hardware = HardwareInfo.current()
        let sampler = SystemSampler(hardware: hardware)
        _ = sampler.sample()
        try? await Task.sleep(nanoseconds: 140_000_000)
        let snapshot = sampler.sample()
        return WidgetModel(date: Date(), snapshot: snapshot, hardware: hardware)
    }
}

struct VitalsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VitalsWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                WidgetSmallView(model: entry.model)
            case .systemMedium:
                WidgetMediumView(model: entry.model)
            default:
                WidgetLargeView(model: entry.model)
            }
        }
        .widgetURL(URL(string: "vitals://open"))
    }
}

@main
struct VitalsHomeWidget: Widget {
    private let kind = "VITALSHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsTimelineProvider()) { entry in
            VitalsWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("VITALS 硬件仪表")
        .description("在桌面查看 CPU、内存、GPU 与存储的当前状态。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
