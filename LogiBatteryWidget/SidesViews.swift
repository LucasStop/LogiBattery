import SwiftUI

/// Fone com lados na lista grande (T14, #154): nome e tempo; embaixo L, R e, havendo leitura, o estojo.
struct SidesRow: View {
    let device: Device
    let gray: Bool
    let thresholds: BatteryThresholds

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                device.symbol.font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).font(.headline).lineLimit(1)
                    Text(device.readAt, format: .relative(presentation: .named))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
            }
            HStack(spacing: 16) {
                DeviceSideItem(device: device, part: .left, thresholds: thresholds, gray: gray)
                DeviceSideItem(device: device, part: .right, thresholds: thresholds, gray: gray)
                if device.side(.case) != nil {
                    DeviceSideItem(device: device, part: .case, thresholds: thresholds, gray: gray)
                }
            }
            .padding(.leading, 28)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(device.sidesAccessibilitySummary))
    }
}

/// Meio anel que enche de baixo para cima, com folga no topo e embaixo (T14). `fraction` 1 é o meio anel cheio.
struct HalfRing: Shape {
    enum Side { case left, right }
    static let gap = Angle.degrees(8)
    static let style = StrokeStyle(lineWidth: RingMetrics.stroke, lineCap: .round)

    let side: Side
    var fraction: CGFloat

    func path(in rect: CGRect) -> Path {
        Self.path(side: side, fraction: fraction, center: CGPoint(x: rect.midX, y: rect.midY),
                  radius: min(rect.width, rect.height) / 2)
    }

    /// No `Path` do SwiftUI (y para baixo) o fundo é 90°; o lado direito sobe no sentido anti-horário visual.
    static func path(side: Side, fraction: CGFloat, center: CGPoint, radius: CGFloat) -> Path {
        let span = Angle.degrees(180) - gap * 2
        let right = side == .right
        let start = Angle.degrees(90) + (right ? -gap : gap)
        let end = start + (right ? -span : span) * Double(min(max(fraction, 0), 1))
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: right)
        return path
    }
}
