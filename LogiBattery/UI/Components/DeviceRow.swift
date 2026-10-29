import SwiftUI

/// Cartão de aparelho do popover (T04): ícone, nome e hora da leitura, selo de estado, % e célula.
struct DeviceRow: View {
    let device: Device

    var body: some View {
        let level = BatteryLevel(percent: device.percent)
        HStack(spacing: 8) {
            Image(systemName: device.symbolName).foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.headline).lineLimit(1)
                Text(device.readAt, format: .relative(presentation: .named))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let label = device.chargeState.labelKey {
                Text(label).font(.caption).foregroundStyle(.secondary)
            } else if let label = level.labelKey {
                Text(label).font(.caption).foregroundStyle(level.color)
            }
            Text(device.percent.map { "\($0)%" } ?? "—")
                .font(.title3.weight(.semibold)).monospacedDigit()
            BatteryCell(percent: device.percent, tint: device.tint).frame(width: 44)
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
