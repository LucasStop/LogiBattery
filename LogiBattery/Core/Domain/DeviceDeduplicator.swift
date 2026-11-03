import Foundation

/// Junta o mesmo aparelho visto por receptor e por Bluetooth, mantendo a leitura mais recente.
enum DeviceDeduplicator {
    // ponytail: identidade pelo nome; dois aparelhos iguais (ex.: dois MX Master 3S) viram um.
    // Trocar por número de série (hash, ver docs/DATA.md) quando houver aparelho repetido.
    static func merge(_ devices: [Device]) -> [Device] {
        var best: [String: Device] = [:]
        var order: [String] = []
        for device in devices {
            let key = device.identity
            guard let current = best[key] else {
                best[key] = device
                order.append(key)
                continue
            }
            if wins(device, over: current) { best[key] = device }
        }
        return order.compactMap { best[$0] }
    }

    /// Mais recente vence; no mesmo ciclo de leitura, HID++ direto vence leitura genérica do sistema (`bt-*`) e
    /// Bluetooth vence receptor. Leitura com percentual vence leitura sem percentual.
    private static func wins(_ candidate: Device, over current: Device) -> Bool {
        if (candidate.percent != nil) != (current.percent != nil) {
            return candidate.percent != nil
        }
        let candidateIsSystemBT = candidate.id.hasPrefix("bt-")
        let currentIsSystemBT = current.id.hasPrefix("bt-")
        if candidateIsSystemBT != currentIsSystemBT,
           abs(candidate.readAt.timeIntervalSince(current.readAt)) < 5 {
            return !candidateIsSystemBT
        }
        if candidate.readAt != current.readAt { return candidate.readAt > current.readAt }
        return candidate.path == .bluetooth && current.path != .bluetooth
    }
}
