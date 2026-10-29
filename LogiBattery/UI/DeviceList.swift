import SwiftUI

// Lista mínima da US-01. O popover aprovado (T04) com ícone por nível, estados e rodapé entra na US-06.
struct DeviceList: View {
    let viewModel: DeviceListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.devices.isEmpty {
                Text(viewModel.hasLoaded ? "Nenhum aparelho Logitech encontrado" : "Lendo…")
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.devices) { device in
                HStack {
                    Text(device.name)
                    Spacer()
                    Text(device.percent.map { "\($0)%" } ?? "—")
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(12)
        .frame(width: 320)
        .task { await viewModel.refresh() }
    }
}
