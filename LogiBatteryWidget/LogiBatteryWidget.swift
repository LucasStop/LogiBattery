import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
    let series: [HistorySeries]
}

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry { BatteryEntry(date: .now, snapshot: nil, series: []) }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        completion(entry())
    }

    /// Uma entrada por minuto: o "há X min" e o cinza de leitura velha andam sem o host recarregar o widget,
    /// que só recarrega quando a leitura muda (orçamento do WidgetKit).
    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        let first = entry()
        let entries = (0..<15).map {
            BatteryEntry(date: first.date.addingTimeInterval(Double($0) * 60), snapshot: first.snapshot,
                         series: first.series)
        }
        completion(Timeline(entries: entries, policy: .after(first.date.addingTimeInterval(15 * 60))))
    }

    private func entry() -> BatteryEntry {
        let points = HistoryStore.appGroup?.points(since: .now.addingTimeInterval(-HistoryPeriod.day.interval)) ?? []
        return BatteryEntry(date: .now, snapshot: SnapshotStore.appGroup?.read(),
                            series: HistorySeries.build(points, period: .day, now: .now))
    }
}

struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    /// Margens do sistema, devolvidas à mão onde valem: as margens automáticas estão desligadas para a grade de
    /// anéis ter as medidas do widget da Apple (`contentMarginsDisabled`).
    @Environment(\.widgetContentMargins) private var margins
    let entry: BatteryEntry

    private var devices: [Device] { Snapshot.widgetOrder(entry.snapshot?.devices ?? []) }
    private var isStale: Bool { entry.snapshot?.isStale(at: entry.date) ?? false }
    private var thresholds: BatteryThresholds { entry.snapshot?.levelThresholds ?? BatteryThresholds() }

    var body: some View {
        Group {
            if devices.isEmpty {
                EmptyWidget().padding(margins)
            } else if family == .systemLarge {
                ListWidget(devices: Array(devices.prefix(4)), isStale: isStale, date: entry.date,
                           thresholds: thresholds, series: entry.series)
                    .padding(margins)
            } else {
                RingWidget(devices: devices, columns: family == .systemSmall ? 2 : 4, isStale: isStale,
                           date: entry.date, thresholds: thresholds)
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

/// Medidas do widget Baterias da Apple, medidas em print (DESIGN.md §3.8).
private enum RingMetrics {
    static let smallRing: CGFloat = 64
    static let mediumRing: CGFloat = 62
    static let stroke: CGFloat = 6
    /// Entre os anéis do pequeno: a grade de 140 pt fica centrada no widget.
    static let smallGap: CGFloat = 12
    /// Laterais do médio: o resto vira 4 colunas iguais (passo de 81 pt).
    static let mediumMargin: CGFloat = 10
    static let icon: CGFloat = 24
    static let percent: CGFloat = 16
    /// Do anel à caixa do texto; o topo do dígito fica a 18 pt do anel, como no da Apple.
    static let percentGap: CGFloat = 15
}

/// Até 4 aparelhos em anéis, como o widget de baterias do macOS: grade 2x2 no pequeno e linha 4x1 no médio.
/// Posição sem aparelho fica com o anel vazio, para a grade não mudar de forma.
private struct RingWidget: View {
    static let slots = 4
    let devices: [Device]
    let columns: Int
    let isStale: Bool
    let date: Date
    let thresholds: BatteryThresholds

    var body: some View {
        let filled = devices.prefix(Self.slots).map { Optional($0) }
        let slots = filled + Array(repeating: nil, count: Self.slots - filled.count)
        let medium = columns > 2
        VStack(spacing: RingMetrics.smallGap) {
            ForEach(0..<Self.slots / columns, id: \.self) { row in
                HStack(spacing: medium ? 0 : RingMetrics.smallGap) {
                    ForEach(row * columns..<(row + 1) * columns, id: \.self) { index in
                        let device = slots[index]
                        RingSlot(device: device, gray: isStale || device?.isOld(at: date) == true,
                                 thresholds: thresholds, medium: medium)
                            .frame(maxWidth: medium ? .infinity : nil)
                    }
                }
            }
        }
        .padding(.horizontal, medium ? RingMetrics.mediumMargin : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Anel com o ícone do aparelho em cor primária. No pequeno, o selo de conexão fica dentro do anel, embaixo do
/// ícone, e não há percentual (lotava a grade; o anel mostra o nível e o VoiceOver lê o número). No médio, como
/// no da Apple: percentual embaixo do anel, com o selo ao lado.
private struct RingSlot: View {
    let device: Device?
    let gray: Bool
    let thresholds: BatteryThresholds
    let medium: Bool

    private var percentText: String { device?.percent.map { "\($0)%" } ?? "—" }

    var body: some View {
        VStack(spacing: RingMetrics.percentGap) {
            ring
            if medium {
                HStack(spacing: 3) {
                    if let device { TransportBadge(path: device.path) }
                    Text(percentText)
                        .font(.system(size: RingMetrics.percent, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(gray ? Color.secondary : Color.primary)
                }
                .opacity(device == nil ? 0 : 1)
            }
        }
        // A caixa do texto sobra uns 4 pt abaixo dos dígitos; a Apple centraliza anel e dígitos, não a caixa.
        .padding(.top, medium ? 4 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(device?.name ?? "") \(percentText)"))
        .accessibilityHidden(device == nil)
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: RingMetrics.stroke)
            if let device {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(device.percent ?? 0, 0), 100)) / 100)
                    .stroke(gray ? .secondary : device.tint(thresholds),
                            style: StrokeStyle(lineWidth: RingMetrics.stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: device.symbolName).font(.system(size: RingMetrics.icon))
                // Topo do selo a 12 pt do centro: o ícone fica no centro mesmo sem selo (Mac) e o selo não encosta
                // no traço.
                if !medium { TransportBadge(path: device.path).offset(y: 18) }
            }
        }
        .padding(RingMetrics.stroke / 2)
        .frame(width: medium ? RingMetrics.mediumRing : RingMetrics.smallRing,
               height: medium ? RingMetrics.mediumRing : RingMetrics.smallRing)
    }
}

private struct ListWidget: View {
    let devices: [Device]
    let isStale: Bool
    let date: Date
    let thresholds: BatteryThresholds
    let series: [HistorySeries]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isStale ? "widget.title.stale" : "widget.title")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(devices) { device in
                let gray = isStale || device.isOld(at: date)
                let level = BatteryLevel(percent: device.percent, thresholds: thresholds)
                HStack(spacing: 8) {
                    Image(systemName: device.symbolName).foregroundStyle(.secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name).font(.headline).lineLimit(1)
                        HStack(spacing: 4) {
                            TransportBadge(path: device.path)
                            Text(device.readAt, format: .relative(presentation: .named))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 4)
                    StatusLine(device: device, isStale: gray, level: level)
                    Text(device.percent.map { "\($0)%" } ?? "—")
                        .font(.title3.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(gray ? .secondary : level.color)
                    BatteryCell(percent: device.percent, tint: gray ? .secondary : device.tint(thresholds))
                        .frame(width: 44)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
            if !series.isEmpty { HistoryChart(series: series, compact: true).frame(maxHeight: 110) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Texto do estado: desatualizado, carga ou nível baixo (cor sozinha não basta).
private struct StatusLine: View {
    let device: Device
    let isStale: Bool
    let level: BatteryLevel

    var body: some View {
        if isStale {
            Text("widget.stale").font(.caption2).foregroundStyle(.secondary)
        } else if let label = device.chargeState.labelKey {
            Text(label).font(.caption2).foregroundStyle(.secondary)
        } else if let label = level.labelKey {
            Text(label).font(.caption2).foregroundStyle(level.color)
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
        .contentMarginsDisabled()
    }
}

@main
struct LogiBatteryWidgetBundle: WidgetBundle {
    var body: some Widget { LogiBatteryWidget() }
}
