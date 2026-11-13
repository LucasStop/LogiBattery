import Foundation

/// Lê L/R/estojo do fone QCY por GATT (fone conectado como áudio não anuncia) ou por advertising, uma vez por scan.
/// Só leitura: nada é escrito no fone (ADR 0006). Sem Bluetooth, permissão ou fone, devolve `nil` no `timeout`.
protocol QCYReading: Sendable {
    func read() async -> [DeviceSide]?
}

final class QCYLiveReader: QCYReading, @unchecked Sendable {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 5) { self.timeout = timeout }

    func read() async -> [DeviceSide]? {
        let client = QCYClient()
        let once = Once()
        return await withCheckedContinuation { continuation in
            let finish: @Sendable ([DeviceSide]?) -> Void = { sides in
                guard once.take() else { return }
                client.onState = nil
                client.onAdvertisement = nil
                client.onFailure = nil
                client.stop()
                continuation.resume(returning: sides)
            }
            client.onState = { state in
                let sides = QCYSides.make(state)
                if sides.contains(where: { $0.side != .case }) { finish(sides) }
            }
            client.onAdvertisement = { advertisement in
                let sides = QCYSides.make(advertisement)
                if sides.contains(where: { $0.side != .case }) { finish(sides) }
            }
            client.onFailure = { _ in finish(nil) }
            client.start()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    /// Garante um único `resume` da continuação entre os callbacks do cliente e o timeout.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var taken = false

        func take() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if taken { return false }
            taken = true
            return true
        }
    }
}
