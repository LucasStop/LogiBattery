import AppKit
import Foundation
import OSLog
import ServiceManagement

enum PowerHelperError: LocalizedError {
    case connectionFailed
    case remoteError(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return String(localized: "macPower.helper.error.connection")
        case .remoteError(let message):
            return message
        }
    }
}

/// Cliente XPC + gerenciador do daemon `SMAppService.daemon` para troca de Modo de Energia (ADR 0009).
struct PowerHelperClient: PowerModeControlling {
    private static let log = Logger(subsystem: "com.lucasstop.LogiBattery", category: "power")

    private var service: SMAppService {
        SMAppService.daemon(plistName: PowerHelperConstants.plistName)
    }

    func status() -> PowerHelperStatus {
        switch service.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: .notRegistered
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func register() throws -> PowerHelperStatus {
        do {
            try service.register()
        } catch {
            // `register()` lança erro quando o sistema pede aprovação do usuário em Itens de Início; checar o status.
            let current = status()
            if current == .requiresApproval || current == .enabled {
                return current
            }
            Self.log.error("power helper register failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        return status()
    }

    func setPowerMode(_ mode: EnergyMode, scope: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = XPCModeRequest(continuation: continuation)
            request.send(mode: mode, scope: scope)
        }
    }

    @MainActor
    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Encapsula uma chamada XPC única com proteção de concorrência para Swift 6.
private final class XPCModeRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var connection: NSXPCConnection?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func send(mode: EnergyMode, scope: String) {
        let conn = NSXPCConnection(
            machServiceName: PowerHelperConstants.machServiceName,
            options: .privileged
        )
        conn.remoteObjectInterface = NSXPCInterface(with: PowerHelperProtocol.self)
        lock.lock()
        connection = conn
        lock.unlock()

        conn.invalidationHandler = { [weak self] in
            self?.finish(.failure(PowerHelperError.connectionFailed))
        }
        conn.interruptionHandler = { [weak self] in
            self?.finish(.failure(PowerHelperError.connectionFailed))
        }
        conn.resume()
        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ [weak self] error in
            self?.finish(.failure(error))
        }) as? PowerHelperProtocol else {
            finish(.failure(PowerHelperError.connectionFailed))
            return
        }
        proxy.setPowerMode(mode.rawValue, scope: scope) { [weak self] success, message in
            if success {
                self?.finish(.success(()))
            } else {
                self?.finish(.failure(PowerHelperError.remoteError(message ?? "Unknown error")))
            }
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let pending = continuation
        let conn = connection
        continuation = nil
        connection = nil
        lock.unlock()

        conn?.invalidate()
        pending?.resume(with: result)
    }
}

/// Ações nativas do sistema relacionadas à bateria do Mac.
enum MacPowerActions {
    private static let batterySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Battery-Settings.extension"
    )!

    @MainActor
    static func openBatterySettings() {
        NSWorkspace.shared.open(batterySettingsURL)
    }
}
