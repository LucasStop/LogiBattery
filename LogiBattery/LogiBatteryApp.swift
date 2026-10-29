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

/// Descobre as interfaces a cada leitura: receptor ou aparelho conectado agora aparece sem reiniciar o app.
private struct LiveScanner: DeviceScanning {
    private let discovery = HIDDiscovery()

    func scan() async -> [Device] {
        await DeviceScanner(endpoints: discovery.endpoints()).scan()
    }
}
