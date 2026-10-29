import SwiftUI
import WidgetKit

@main
struct LogiBatteryApp: App {
    @State private var viewModel = DeviceListViewModel(scanner: LiveScanner(), publish: publishSnapshot)

    init() {
        let viewModel = viewModel
        Task { await viewModel.poll() }
    }

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

/// Grava o snapshot do widget e pede a ele que recarregue (ADR 0001).
@MainActor
private func publishSnapshot(_ devices: [Device]) {
    guard let store = SnapshotStore.appGroup else { return }
    do {
        try store.write(devices, at: .now)
        WidgetCenter.shared.reloadAllTimelines()
    } catch {
        // Sem log com dado do usuário; o widget segue com o snapshot anterior.
    }
}
