import SwiftUI

@main
struct LogiBatteryApp: App {
    @State private var viewModel = DeviceListViewModel(scanner: LiveScanner())

    var body: some Scene {
        MenuBarExtra("LogiBattery", systemImage: "battery.100") {
            DeviceList(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Descobre os receptores a cada leitura: receptor plugado ou removido aparece sem reiniciar o app.
private struct LiveScanner: DeviceScanning {
    private let discovery = ReceiverDiscovery()

    func scan() async -> [Device] {
        await ReceiverScanner(receivers: discovery.receivers()).scan()
    }
}
