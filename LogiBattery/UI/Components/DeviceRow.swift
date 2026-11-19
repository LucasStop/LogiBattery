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
                DeviceSideItem(device: device, part: .left, thresholds: thresholds, gray: gray)
                DeviceSideItem(device: device, part: .right, thresholds: thresholds, gray: gray)
                if device.side(.case) != nil {
                    DeviceSideItem(device: device, part: .case, thresholds: thresholds, gray: gray)
                }
            }
            .padding(.leading, 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(device.sidesAccessibilitySummary))
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
