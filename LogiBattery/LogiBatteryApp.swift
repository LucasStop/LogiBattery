import SwiftUI
import WidgetKit

@main
struct LogiBatteryApp: App {
    @State private var viewModel = DeviceListViewModel(scanner: LiveScanner(), publish: publishSnapshot)

    init() {
        let viewModel = viewModel
        Task { await viewModel.poll { SettingsModel.shared.values.interval } }
    }

    var body: some Scene {
        MenuBarExtra {
            DeviceList(viewModel: viewModel)
        } label: {
            Image(systemName: viewModel.menuBarSymbol)
            if let percent = viewModel.menuBarPercent {
                Text("\(percent)%")
            }
        }
        .menuBarExtraStyle(.window)

        Window("history.title", id: "history") {
            HistoryView()
        }
        .windowResizability(.contentSize)

        Window("settings.title", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

/// Descobre as interfaces a cada leitura: receptor ou aparelho conectado agora aparece sem reiniciar o app.
private struct LiveScanner: DeviceScanning {
    private let discovery = HIDDiscovery()

    func scan() async -> [Device] {
        await DeviceScanner(endpoints: discovery.endpoints()).scan()
    }
}

@MainActor private let alerts = AlertCoordinator(notifier: UserNotificationNotifier())

/// Grava o snapshot do widget e pede a ele que recarregue (ADR 0001).
@MainActor
private func publishSnapshot(_ devices: [Device]) {
    alerts.handle(devices)
    guard let store = SnapshotStore.appGroup else { return }
    do {
        try HistoryStore.appGroup?.record(devices, at: .now)
        try store.write(devices, at: .now)
        WidgetCenter.shared.reloadAllTimelines()
    } catch {
        // Sem log com dado do usuário; o widget segue com o snapshot anterior.
    }
}
