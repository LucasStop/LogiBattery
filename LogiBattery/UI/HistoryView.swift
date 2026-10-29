import SwiftUI

/// Janela de histórico (T05): período em controle segmentado, um gráfico com uma linha por aparelho.
struct HistoryView: View {
    @State private var period = HistoryPeriod.day
    @State private var points: [HistoryPoint] = []
    @State private var loaded = false

    var body: some View {
        let series = HistorySeries.build(points, period: period, now: .now)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("history.title").font(.headline)
                Spacer()
                Picker("history.period", selection: $period) {
                    Text("history.period.day").tag(HistoryPeriod.day)
                    Text("history.period.week").tag(HistoryPeriod.week)
                    Text("history.period.month").tag(HistoryPeriod.month)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }
            if series.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loaded ? "history.empty.title" : "popover.reading").font(.headline)
                    if loaded { Text("history.empty.body").font(.callout).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                HistoryChart(series: series).frame(height: 220)
            }
        }
        .padding(16)
        .frame(width: 480)
        .task(id: period) {
            points = HistoryStore.appGroup?.points(since: .now.addingTimeInterval(-period.interval)) ?? []
            loaded = true
        }
    }
}
