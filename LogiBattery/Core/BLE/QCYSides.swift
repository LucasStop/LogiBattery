import Foundation

/// Liga a leitura do fone QCY (`QCYState`/`QCYAdvertisement`) ao `Device` do popover (#142, ADR 0006).
enum QCYSides {
    /// Lado em 0% é "sem leitura" (fora do estojo, desligado), nunca 0%; estojo `nil` não entra.
    static func make(left: QCYBatteryLevel?, right: QCYBatteryLevel?, caseBattery: QCYBatteryLevel?) -> [DeviceSide] {
        [(DeviceSide.Part.left, left), (.right, right), (.case, caseBattery)].compactMap { part, level in
            guard let level, level.percent > 0 else { return nil }
            return DeviceSide(side: part, percent: level.percent, charging: level.isCharging)
        }
    }

    static func make(_ state: QCYState) -> [DeviceSide] {
        make(left: state.left, right: state.right, caseBattery: state.caseBattery)
    }

    static func make(_ advertisement: QCYAdvertisement) -> [DeviceSide] {
        make(left: advertisement.left, right: advertisement.right, caseBattery: advertisement.caseBattery)
    }
}

extension Device {
    /// O fone QCY chega do sistema como áudio Bluetooth ("QCY MeloBuds Pro - Lucas") sem nível confiável.
    var isQCYHeadset: Bool { kind == .headphones && name.lowercased().contains("qcy") }

    /// Troca o nível do sistema pelos lados medidos. Sem lado de fone (só estojo ou nada) devolve o aparelho como veio.
    func applying(qcy sides: [DeviceSide]) -> Device {
        let buds = sides.filter { $0.side != .case }
        guard let lowest = buds.map(\.percent).min() else { return self }
        var merged = Device(id: id, name: name, kind: kind, percent: lowest,
                            chargeState: buds.contains { $0.charging } ? .charging : .discharging,
                            path: path, readAt: readAt)
        merged.sides = sides
        return merged
    }
}
