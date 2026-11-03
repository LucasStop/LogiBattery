import SwiftUI

/// Cartão de aparelho do popover (T04): ícone, nome e hora da leitura, selo de estado, % e célula.
struct DeviceRow: View {
    let device: Device

    var body: some View {
        let thresholds = SettingsModel.shared.values.thresholds
        let level = BatteryLevel(percent: device.percent, thresholds: thresholds)
        // Leitura velha (aparelho dormindo ou fora de alcance) fica cinza, como no widget.
        let gray = device.isOld(at: .now)
        HStack(spacing: 8) {
            Image(systemName: device.symbolName).foregroundStyle(.secondary).frame(width: 20)
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
                .font(.title3.weight(.semibold)).monospacedDigit()
            BatteryCell(percent: device.percent, tint: gray ? .secondary : device.tint(thresholds)).frame(width: 44)
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
