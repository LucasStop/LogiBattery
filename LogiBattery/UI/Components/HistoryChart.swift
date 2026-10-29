import Charts
import SwiftUI

extension HistorySeries {
    /// Paleta categórica distinta das cores de nível (DESIGN.md §3.1); a segunda série também é tracejada.
    var color: Color {
        [Color(light: 0x5B4FCF, dark: 0x9D93FF), Color(light: 0x0E7C86, dark: 0x4FD1C5),
         Color(light: 0xB8329B, dark: 0xF28BD8)][index % 3]
    }

    var dash: [CGFloat] { index % 2 == 1 ? [5, 3] : [] }
}

/// Gráfico de porcentagem por aparelho (T05); no widget grande é a versão compacta (T03).
struct HistoryChart: View {
    let series: [HistorySeries]
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(series) { line in
                    ForEach(line.points, id: \.timestamp) { point in
                        LineMark(x: .value("history.time", point.timestamp),
                                 y: .value("history.percent", point.percent),
                                 series: .value("history.device", line.deviceName))
                            .foregroundStyle(line.color)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: line.dash))
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { _ in
                    AxisGridLine()
                    if !compact { AxisValueLabel() }
                }
            }
            .chartXAxis(compact ? .hidden : .automatic)
            .accessibilityLabel(Text(summary))
            HStack(spacing: 12) {
                ForEach(series) { line in
                    HStack(spacing: 4) {
                        Capsule().fill(line.color).frame(width: 12, height: 3)
                        Text(line.deviceName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
    }

    /// Texto para VoiceOver: primeiro e último valor de cada aparelho.
    private var summary: String {
        series.compactMap { line in
            guard let first = line.points.first, let last = line.points.last else { return nil }
            return "\(line.deviceName): \(first.percent)% → \(last.percent)%"
        }.joined(separator: "; ")
    }
}
