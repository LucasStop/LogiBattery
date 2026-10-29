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

    /// Mais recente vence; empate fica com o Bluetooth, que é o caminho direto.
    private static func wins(_ candidate: Device, over current: Device) -> Bool {
        if candidate.readAt != current.readAt { return candidate.readAt > current.readAt }
        return candidate.path == .bluetooth && current.path != .bluetooth
    }
}
