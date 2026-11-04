import OSLog
import SwiftUI
import WidgetKit

@main
struct LogiBatteryApp: App {
    @State private var permission = PermissionModel()
    @AppStorage(SettingsModel.showMenuBarIconKey) private var showMenuBarIcon = true
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    init() {
        // Processo filho da leitura de Bluetooth: não abre interface (#107).
        if CommandLine.arguments.contains(SystemBatteries.levelsArgument) {
            SystemBatteries.printLevels()
            exit(0)
        }
        // O host dos testes é o app: sem isso ele lê o hardware e grava no App Group durante o `xcodebuild test`.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        // Ajuste novo vale na hora para a lista, o ícone e o widget, sem esperar a próxima leitura (#115).
        SettingsModel.shared.onChange = { viewModel.apply($0.readingPolicy) }
        Task {
            await viewModel.run(interval: { SettingsModel.shared.values.interval }, changes: discovery.changes)
        }
    }

    var body: some Scene {
        // Escondido, só some o ícone: a leitura roda no `init` e o widget segue atualizando (US-14).
        MenuBarExtra(isInserted: $showMenuBarIcon) {
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

/// Abrir o app de novo (Spotlight, Finder, clique no widget) traz o ícone escondido de volta: sem ele não há
/// outro caminho até os Ajustes.
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        UserDefaults.standard.set(true, forKey: SettingsModel.showMenuBarIconKey)
        return true
    }
}

private let discovery = HIDDiscovery()

/// Instância única: o loop de leitura (`init`) e a cena (menu e ícone) precisam enxergar o mesmo objeto. Como
/// `@State` lido no `init`, o loop atualizava uma cópia e o menu ficava no snapshot restaurado (#102).
@MainActor private let viewModel = DeviceListViewModel(
    scanner: LiveScanner(), restoring: SnapshotStore.appGroup?.read(),
    policy: SettingsModel.shared.values.readingPolicy, publish: publishSnapshot)

/// Descobre as interfaces a cada leitura: receptor ou aparelho conectado agora aparece sem reiniciar o app.
/// Soma a bateria do Mac e de qualquer periférico Bluetooth conectado no macOS, deduplicando com HID++ (#88).
private struct LiveScanner: DeviceScanning {
    func scan() async -> [Device] {
        let peripherals = await DeviceScanner(endpoints: discovery.endpoints()).scan()
        let system = await SystemBatteries.read(now: .now)
        return DeviceDeduplicator.merge(peripherals + system)
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
    let thresholds = SettingsModel.shared.values.thresholds
    let interval = SettingsModel.shared.values.intervalMinutes
    let policy = SettingsModel.shared.values.readingPolicy
    let previous = store.read()
    do {
        try HistoryStore.appGroup?.record(devices, at: now)
    } catch {
        // Sem nome nem série do aparelho no log.
        storageLog.error("history write failed: \(error.localizedDescription, privacy: .public)")
    }
    do {
        try store.write(devices, at: now, thresholds: thresholds, intervalMinutes: interval, policy: policy)
    } catch {
        storageLog.error("snapshot write failed: \(error.localizedDescription, privacy: .public)")
        return
    }
    let changed = previous?.needsWidgetReload(for: devices, at: now, thresholds: thresholds,
                                              intervalMinutes: interval, policy: policy) ?? true
    if changed { WidgetCenter.shared.reloadAllTimelines() }
}
