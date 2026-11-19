import SwiftUI

/// Um lado do fone QCY (ou o estojo): letra, porcentagem, raio se carregando e a célula. Popover (T13) e widget
/// grande (T14, #154) usam o mesmo item.
struct DeviceSideItem: View {
    let device: Device
    let part: DeviceSide.Part
    let thresholds: BatteryThresholds
    var gray = false

    var body: some View {
        let side = device.side(part)
        let tint: Color = gray ? .secondary : (side?.tint(thresholds) ?? .secondary)
        HStack(spacing: 4) {
            Text(part.shortName).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(side.map { "\($0.percent)%" } ?? "—")
                .font(.callout.weight(.semibold)).monospacedDigit()
                .foregroundStyle(gray ? .secondary : .primary)
            if side?.charging == true {
                Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(tint)
            }
            BatteryCell(percent: side?.percent, tint: tint, gray: gray).frame(width: 28)
        }
    }
}

extension Device {
    /// "QCY MeloBuds Pro, esquerdo 90%, direito 85%" (T13, T14); lado sem leitura vira "sem leitura".
    var sidesAccessibilitySummary: String {
        let parts = [DeviceSide.Part.left, .right, .case].compactMap { part -> String? in
            if let side = side(part) {
                let charging = side.charging ? ", \(String(localized: "charge.charging"))" : ""
                return "\(part.spokenName) \(side.percent)%" + charging
            }
            return part == .case ? nil : "\(part.spokenName) \(String(localized: "device.side.unknown"))"
        }
        return ([name] + parts).joined(separator: ", ")
    }
}

extension DeviceSide.Part {
    /// Letra do popover e do widget (L, R, E; em inglês C de case).
    var shortName: String {
        switch self {
        case .left: String(localized: "device.side.left.short")
        case .right: String(localized: "device.side.right.short")
        case .case: String(localized: "device.side.case.short")
        }
    }

    var spokenName: String {
        switch self {
        case .left: String(localized: "device.side.left")
        case .right: String(localized: "device.side.right")
        case .case: String(localized: "device.side.case")
        }
    }
}
