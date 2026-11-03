import OSLog
import SwiftUI
import WidgetKit

@main
struct LogiBatteryApp: App {
    @State private var viewModel = DeviceListViewModel(
        scanner: LiveScanner(), restoring: SnapshotStore.appGroup?.read(), publish: publishSnapshot)
    @State private var permission = PermissionModel()
    @Environment(\.openWindow) private var openWindow

    init() {
        // O host dos testes é o app: sem isso ele lê o hardware e grava no App Group durante o `xcodebuild test`.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let viewModel = viewModel
        Task {
            await viewModel.run(interval: { SettingsModel.shared.values.interval }, changes: discovery.changes)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            DeviceList(viewModel: viewModel, permission: permission)
        } label: {
            // Largura fixa: se o item muda de tamanho ao aparecer a porcentagem, o macOS ancora o popover
            // na posição antiga e ele abre deslocado para a direita.
            HStack(spacing: 3) {
                Image(systemName: viewModel.menuBarSymbol)
                Text(viewModel.menuBarPercent.map { "\($0)%" } ?? "")
                    .monospacedDigit()
            }
            .frame(width: 62, alignment: .leading)
            // O label existe desde a abertura do app: é onde o guia de permissão aparece no primeiro uso.
            .task {
                if permission.needsGuide {
                    openWindow(id: "permission")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("history.title", id: "history") {
            HistoryView()
        }
        .windowResizability(.contentSize)

        Window("permission.window", id: "permission") {
            PermissionView(model: permission)
        }
        .windowResizability(.contentSize)

        Window("settings.title", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

private let discovery = HIDDiscovery()

/// Descobre as interfaces a cada leitura: receptor ou aparelho conectado agora aparece sem reiniciar o app.
private struct LiveScanner: DeviceScanning {
    func scan() async -> [Device] {
        await DeviceScanner(endpoints: discovery.endpoints()).scan()
    }
}

@MainActor private let alerts = AlertCoordinator(notifier: UserNotificationNotifier())

private let storageLog = Logger(subsystem: "com.lucasstop.LogiBattery", category: "storage")

/// Grava histórico e snapshot (um não bloqueia o outro) e recarrega o widget só quando o que ele mostra mudou
/// (ADR 0001). O snapshot é gravado sempre: `generatedAt` é o sinal de que o app está vivo.
@MainActor
private func publishSnapshot(_ devices: [Device]) {
    alerts.handle(devices)
    guard let store = SnapshotStore.appGroup else { return }
    let now = Date.now
    let previous = store.read()
    do {
        try HistoryStore.appGroup?.record(devices, at: now)
    } catch {
        // Sem nome nem série do aparelho no log.
        storageLog.error("history write failed: \(error.localizedDescription, privacy: .public)")
    }
    do {
        try store.write(devices, at: now)
    } catch {
        storageLog.error("snapshot write failed: \(error.localizedDescription, privacy: .public)")
        return
    }
    if previous.map({ $0.isStale(at: now) || Snapshot.meaningfullyDiffers($0.devices, devices, at: now) }) ?? true {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
