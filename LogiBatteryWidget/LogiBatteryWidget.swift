import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry { BatteryEntry(date: .now, snapshot: nil) }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        // Reavalia o "desatualizado" mesmo sem o host recarregar a timeline.
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func entry() -> BatteryEntry {
        BatteryEntry(date: .now, snapshot: SnapshotStore.appGroup?.read())
    }
}

struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BatteryEntry

    private var devices: [Device] { Snapshot.widgetOrder(entry.snapshot?.devices ?? []) }
    private var isStale: Bool { entry.snapshot?.isStale(at: entry.date) ?? false }

    var body: some View {
        Group {
            if devices.isEmpty {
                EmptyWidget()
            } else if family == .systemSmall, let device = devices.first {
                SmallWidget(device: device, isStale: isStale)
            } else {
                ListWidget(devices: Array(devices.prefix(family == .systemMedium ? 3 : 6)), isStale: isStale)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct EmptyWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("widget.empty.title").font(.headline)
            Text("widget.empty.body").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct SmallWidget: View {
    let device: Device
    let isStale: Bool

    var body: some View {
        let level = BatteryLevel(percent: device.percent)
        VStack(alignment: .leading, spacing: 6) {
            Label(device.name, systemImage: device.symbolName)
                .font(.headline).lineLimit(1).labelStyle(.titleAndIcon)
            Text(device.percent.map { "\($0)%" } ?? "—")
                .font(.system(size: 34, weight: .semibold)).monospacedDigit()
                .foregroundStyle(isStale ? .secondary : level.color)
            BatteryCell(percent: device.percent, tint: isStale ? .secondary : device.tint)
            StatusLine(device: device, isStale: isStale)
            Spacer(minLength: 0)
            Text(device.readAt, format: .relative(presentation: .named))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ListWidget: View {
    let devices: [Device]
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isStale ? "widget.title.stale" : "widget.title")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(devices) { device in
                HStack(spacing: 8) {
                    Image(systemName: device.symbolName).foregroundStyle(.secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name).font(.headline).lineLimit(1)
                        Text(device.readAt, format: .relative(presentation: .named))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    StatusLine(device: device, isStale: isStale)
                    Text(device.percent.map { "\($0)%" } ?? "—")
                        .font(.title3.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(isStale ? .secondary : BatteryLevel(percent: device.percent).color)
                    BatteryCell(percent: device.percent, tint: isStale ? .secondary : device.tint)
                        .frame(width: 44)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Texto do estado: desatualizado, carga ou nível baixo (cor sozinha não basta).
private struct StatusLine: View {
    let device: Device
    let isStale: Bool

    var body: some View {
        if isStale {
            Text("widget.stale").font(.caption2).foregroundStyle(.secondary)
        } else if let label = device.chargeState.labelKey {
            Text(label).font(.caption2).foregroundStyle(.secondary)
        } else if let label = BatteryLevel(percent: device.percent).labelKey {
            Text(label).font(.caption2).foregroundStyle(BatteryLevel(percent: device.percent).color)
        }
    }
}

struct LogiBatteryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LogiBatteryWidget", provider: BatteryProvider()) { entry in
            BatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("LogiBattery")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct LogiBatteryWidgetBundle: WidgetBundle {
    var body: some Widget { LogiBatteryWidget() }
}
