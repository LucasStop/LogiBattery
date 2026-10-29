import SwiftUI
import WidgetKit

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

struct LogiBatteryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LogiBatteryWidget", provider: PlaceholderProvider()) { _ in
            Text("LogiBattery").containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct LogiBatteryWidgetBundle: WidgetBundle {
    var body: some Widget { LogiBatteryWidget() }
}
