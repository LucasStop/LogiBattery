import SwiftUI

/// Cartão de aparelho do popover (T04): ícone, nome e hora da leitura, selo de estado, % e célula.
struct DeviceRow: View {
    let device: Device
    /// Leitura mantida (dormindo ou fora de alcance) fica cinza, como no widget (`DeviceListViewModel.isGray`).
    var gray = false

    var body: some View {
        if device.sides != nil { sidesBody } else { singleBody }
    }

    @ViewBuilder private var singleBody: some View {
        let thresholds = SettingsModel.shared.values.thresholds
        let level = BatteryLevel(percent: device.percent, thresholds: thresholds)
        HStack(spacing: 8) {
            device.symbol.font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 20)
                .accessibilityHidden(true) // a conexão já vai no texto embaixo do nome
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.headline).lineLimit(1)
                HStack(spacing: 4) {
                    Text(device.path.labelKey)
                    Text("·")
                    Text(device.readAt, format: .relative(presentation: .named))
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let label = device.chargeState.labelKey {
                Text(label).font(.caption).foregroundStyle(.secondary)
            } else if let label = level.labelKey {
                Text(label).font(.caption).foregroundStyle(gray ? .secondary : level.color)
            }
            Text(device.percent.map { "\($0)%" } ?? "—")
                .font(.callout.weight(.semibold)).monospacedDigit()
                .foregroundStyle(gray ? .secondary : .primary)
            BatteryCell(percent: device.percent, tint: gray ? .secondary : device.tint(thresholds), gray: gray)
                .frame(width: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

/// Fone com lados (T13, #142): nome na primeira faixa; na segunda, L e R e, havendo leitura, o estojo.
private extension DeviceRow {
    @ViewBuilder var sidesBody: some View {
        let thresholds = SettingsModel.shared.values.thresholds
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                device.symbol.font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).font(.headline).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(device.path.labelKey)
                        Text("·")
                        Text(device.readAt, format: .relative(presentation: .named))
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
            }
            HStack(spacing: 16) {
                sideItem(.left, thresholds: thresholds)
                sideItem(.right, thresholds: thresholds)
                if device.side(.case) != nil { sideItem(.case, thresholds: thresholds) }
            }
            .padding(.leading, 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    func sideItem(_ part: DeviceSide.Part, thresholds: BatteryThresholds) -> some View {
        let side = device.side(part)
        let tint: Color = gray ? .secondary : (side?.tint(thresholds) ?? .secondary)
        return HStack(spacing: 4) {
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

    /// "QCY MeloBuds Pro, esquerdo 90%, direito 85%" (T13); lado sem leitura vira "sem leitura".
    var accessibilitySummary: String {
        let parts = [DeviceSide.Part.left, .right, .case].compactMap { part -> String? in
            if let side = device.side(part) {
                let charging = side.charging ? ", \(String(localized: "charge.charging"))" : ""
                return "\(part.spokenName) \(side.percent)%" + charging
            }
            return part == .case ? nil : "\(part.spokenName) \(String(localized: "device.side.unknown"))"
        }
        return ([device.name] + parts).joined(separator: ", ")
    }
}

extension DeviceSide.Part {
    /// Letra do popover (L, R, E; em inglês C de case).
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

#if DEBUG
#Preview("Cartões") {
    VStack(spacing: 8) {
        DeviceRow(device: Sample.mouse)
        DeviceRow(device: Sample.keyboard, gray: true)
        DeviceRow(device: Sample.headphones)
    }
    .padding().frame(width: 360)
}
#endif
