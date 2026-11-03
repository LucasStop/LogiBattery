import AppIntents
import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
    let series: [HistorySeries]
    var mediumPage = 0
    var largePage = 0
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
                         series: first.series, mediumPage: first.mediumPage, largePage: first.largePage)
        }
        completion(Timeline(entries: entries, policy: .after(first.date.addingTimeInterval(15 * 60))))
    }

    private func entry() -> BatteryEntry {
        let points = HistoryStore.appGroup?.points(since: .now.addingTimeInterval(-HistoryPeriod.day.interval)) ?? []
        let pages = WidgetPageStore.appGroup
        return BatteryEntry(date: .now, snapshot: SnapshotStore.appGroup?.read(),
                            series: HistorySeries.build(points, period: .day, now: .now),
                            mediumPage: pages?.page(for: "medium") ?? 0,
                            largePage: pages?.page(for: "large") ?? 0)
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
                ListWidget(devices: devices, page: entry.largePage, isStale: isStale, date: entry.date,
                           thresholds: thresholds, series: entry.series)
                    .padding(margins)
            } else if family == .systemMedium {
                let slice = WidgetPage.slice(devices, page: entry.mediumPage, perPage: WidgetPage.mediumPerPage)
                RingWidget(devices: slice.items, columns: 4, isStale: isStale, date: entry.date,
                           thresholds: thresholds, slice: slice)
            } else {
                RingWidget(devices: devices, columns: 2, isStale: isStale, date: entry.date,
                           thresholds: thresholds, slice: nil)
            }
        }
        // Transparente: fica a base do próprio sistema, que é a mais escura e vira vidro nos estilos claro e
        // tingido. Material, glassEffect e .fill.tertiary saem opacos no estilo padrão e no escuro (spike #64).
        .containerBackground(.clear, for: .widget)
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

/// Até 4 aparelhos em anéis por página, como o widget de baterias do macOS: grade 2x2 no pequeno e linha 4x1 no
/// médio (com paginação a partir do 5º aparelho, T09, #79). Posição sem aparelho fica com o anel vazio.
private struct RingWidget: View {
    static let slots = 4
    let devices: [Device]
    let columns: Int
    let isStale: Bool
    let date: Date
    let thresholds: BatteryThresholds
    let slice: WidgetPageSlice<Device>?

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
        .overlay(alignment: .topTrailing) {
            if let slice, slice.isPaged {
                WidgetPageButton(family: "medium")
                    .padding(8)
            }
        }
        .overlay(alignment: .bottom) {
            if let slice, slice.isPaged {
                WidgetPageDots(page: slice.page, pageCount: slice.pageCount)
                    .padding(.bottom, 9)
            }
        }
    }
}

/// Anel com o ícone do aparelho em cor primária. Todo aparelho com conexão traz o selo no próprio símbolo (#65 e #75).
/// Sem percentual no pequeno (lotava a grade; o anel mostra o nível e o VoiceOver lê o número). No médio, como no da
/// Apple: percentual embaixo do anel.
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
                Text(percentText)
                    .font(.system(size: RingMetrics.percent, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(gray ? Color.secondary : Color.primary)
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
                progress(device)
                device.symbol.font(.system(size: RingMetrics.icon))
            }
        }
        .padding(RingMetrics.stroke / 2)
        .frame(width: size, height: size)
    }

    private var size: CGFloat { medium ? RingMetrics.mediumRing : RingMetrics.smallRing }

    @ViewBuilder
    private func progress(_ device: Device) -> some View {
        let fraction = CGFloat(min(max(device.percent ?? 0, 0), 100)) / 100
        if #available(macOS 15, *), !gray {
            // Nos estilos translúcido e tonalizado o sistema pinta todo shape de uma cor só; imagem em cor cheia
            // escapa disso e o anel mantém a cor do nível. Sem checar `widgetRenderingMode`: no macOS 27 esses
            // estilos não chegam como `.accented` (#64). Leitura velha segue pelo shape, na cor do sistema.
            let tint = device.tint(thresholds)
            Image(size: CGSize(width: size, height: size)) { context in
                var arc = Path()
                arc.addArc(center: CGPoint(x: size / 2, y: size / 2), radius: (size - RingMetrics.stroke) / 2,
                           startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
                context.stroke(arc, with: .color(tint),
                               style: StrokeStyle(lineWidth: RingMetrics.stroke, lineCap: .round))
            }
            .widgetAccentedRenderingMode(.fullColor)
            .padding(-RingMetrics.stroke / 2)
        } else {
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(gray ? .secondary : device.tint(thresholds),
                        style: StrokeStyle(lineWidth: RingMetrics.stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
    }
}

private struct ListWidget: View {
    let devices: [Device]
    let page: Int
    let isStale: Bool
    let date: Date
    let thresholds: BatteryThresholds
    let series: [HistorySeries]

    var body: some View {
        let slice = WidgetPage.slice(devices, page: page, perPage: WidgetPage.largePerPage)
        let compactRows = devices.count > WidgetPage.largeChartMaxDevices
        VStack(alignment: .leading, spacing: compactRows ? 6 : 8) {
            Text(isStale ? "widget.title.stale" : "widget.title")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(slice.items) { device in
                let gray = isStale || device.isOld(at: date)
                let level = BatteryLevel(percent: device.percent, thresholds: thresholds)
                HStack(spacing: 8) {
                    device.symbol.font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name).font(.headline).lineLimit(1)
                        if !compactRows {
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
            if !compactRows, !series.isEmpty {
                HistoryChart(series: series, compact: true).frame(maxHeight: 110)
            }
            if slice.isPaged {
                HStack {
                    Text("\(slice.startItem) – \(slice.endItem) / \(slice.totalItems)")
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    WidgetPageDots(page: slice.page, pageCount: slice.pageCount)
                    Spacer()
                    WidgetPageButton(family: "large")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct WidgetPageButton: View {
    let family: String

    var body: some View {
        Button(intent: NextWidgetPageIntent(family: family)) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(.quaternary.opacity(0.6), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("widget.page.next"))
    }
}

private struct WidgetPageDots: View {
    let page: Int
    let pageCount: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
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
