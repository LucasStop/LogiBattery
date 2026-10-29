import AppKit
import IOKit.hid
import Observation

enum InputAccessStatus: Equatable, Sendable {
    case granted, denied, unknown
}

/// Monitoramento de Entrada do macOS, sem o qual o IOHIDManager não entrega os frames HID++.
protocol InputAccess {
    var status: InputAccessStatus { get }
    func request()
    func openPrivacySettings()
}

struct SystemInputAccess: InputAccess {
    var status: InputAccessStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: .granted
        case kIOHIDAccessTypeDenied: .denied
        default: .unknown
        }
    }

    func request() {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
@Observable
final class PermissionModel {
    private(set) var status: InputAccessStatus
    private var dismissed = false
    @ObservationIgnored private let access: any InputAccess

    init(access: any InputAccess = SystemInputAccess()) {
        self.access = access
        status = access.status
    }

    /// Janela de guia (T07): some com "Agora não" ou quando a permissão chega.
    var needsGuide: Bool { status != .granted && !dismissed }

    /// Faixa no popover (T04, erro de permissão): continua enquanto faltar a permissão.
    var needsAttention: Bool { status != .granted }

    func refresh() {
        status = access.status
    }

    func dismiss() {
        dismissed = true
    }

    /// Sem pedido anterior o app nem aparece na lista do painel; pedir primeiro o registra.
    func openPrivacy() {
        if status == .unknown { access.request() }
        access.openPrivacySettings()
    }
}
