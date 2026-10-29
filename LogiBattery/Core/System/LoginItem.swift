import Observation
import ServiceManagement

/// Registro do app como item de login; atrás de protocolo para o teste não mexer no sistema.
protocol LoginItemService {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginService: LoginItemService {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

/// Estado do "Abrir no login" (US-10): sempre o do sistema, nunca um valor guardado à parte.
@MainActor
@Observable
final class LoginItemModel {
    private(set) var isEnabled: Bool
    private(set) var failed = false
    @ObservationIgnored private let service: any LoginItemService

    init(service: any LoginItemService = SystemLoginService()) {
        self.service = service
        isEnabled = service.isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try service.register() } else { try service.unregister() }
            failed = false
        } catch {
            failed = true
        }
        isEnabled = service.isEnabled
    }
}
