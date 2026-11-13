import Foundation

/// Modo de cancelamento de ruído. O canal simples (`0x0C`) manda só o modo; o avançado (`0x17`) manda
/// cena e profundidade junto, e numera diferente — por isso o nome só vale quando não há cena.
struct QCYNoiseMode: Equatable, Sendable {
    let mode: UInt8
    let subScene: UInt8
    let noiseValue: UInt8

    init(mode: UInt8, subScene: UInt8 = 0, noiseValue: UInt8 = 0) {
        self.mode = mode
        self.subScene = subScene
        self.noiseValue = noiseValue
    }

    /// Tabela do modo simples. Com cena o firmware do MeloBuds Pro usa outra numeração (mediu-se `3/2`, que o
    /// documento do Quicky chama de transparência no remapeamento e de "ambiente de trabalho nível 2" na tabela),
    /// então o valor sai em hex em vez de um nome inventado.
    var name: String {
        guard subScene == 0 else { return String(format: "cena 0x%02X/%02X", mode, subScene) }
        switch mode {
        case 0x00: return "Desligado"
        case 0x01: return "ANC"
        case 0x02: return "ANC externo"
        case 0x03: return "Transparência"
        default: return String(format: "0x%02X", mode)
        }
    }
}

/// Versão de firmware. O fone devolve 3 bytes (só o lado esquerdo) ou 6 (um conjunto por lado).
struct QCYFirmware: Equatable, Sendable {
    let left: String
    let right: String?
}

/// Estado montado a partir das notificações de `00001002`. Cada resposta traz só os blocos que mudaram,
/// então o estado é acumulativo: aplica o que chegou e mantém o resto.
struct QCYState: Equatable, Sendable {
    var left: QCYBatteryLevel?
    var right: QCYBatteryLevel?
    var caseBattery: QCYBatteryLevel?
    var firmware: QCYFirmware?
    var noiseMode: QCYNoiseMode?
    var isLowLatencyEnabled: Bool?
    var isInEarDetectionEnabled: Bool?
    var isLDACEnabled: Bool?

    mutating func apply(_ packet: QCYPacket) {
        for block in packet.blocks {
            apply(block)
        }
    }

    mutating func apply(_ block: QCYPacket.Block) {
        guard let command = QCYCommand(rawValue: block.command) else { return }
        switch command {
        case .battery: applyBattery(block.parameters)
        case .version: applyVersion(block.parameters)
        case .noiseCancelMode, .ancSetting: applyNoise(command, block.parameters)
        case .lowLatency, .inEarDetection, .ldac: applyToggle(command, block.parameters)
        case .requestData: break
        }
    }

    private mutating func applyBattery(_ parameters: [UInt8]) {
        guard parameters.count >= 3 else { return }
        left = QCYBatteryLevel(raw: parameters[0])
        right = QCYBatteryLevel(raw: parameters[1])
        caseBattery = parameters[2] == 0 ? nil : QCYBatteryLevel(raw: parameters[2])
    }

    private mutating func applyVersion(_ parameters: [UInt8]) {
        guard parameters.count >= 3 else { return }
        firmware = QCYFirmware(left: Self.text(parameters, from: 0),
                               right: parameters.count >= 6 ? Self.text(parameters, from: 3) : nil)
    }

    private static func text(_ parameters: [UInt8], from start: Int) -> String {
        "\(parameters[start]).\(parameters[start + 1]).\(parameters[start + 2])"
    }

    private mutating func applyNoise(_ command: QCYCommand, _ parameters: [UInt8]) {
        if command == .ancSetting {
            guard parameters.count >= 3 else { return }
            noiseMode = QCYNoiseMode(mode: parameters[0], subScene: parameters[1], noiseValue: parameters[2])
        } else if let mode = parameters.first {
            noiseMode = QCYNoiseMode(mode: mode)
        }
    }

    private mutating func applyToggle(_ command: QCYCommand, _ parameters: [UInt8]) {
        guard let value = parameters.first else { return }
        let isEnabled = value == 0x01
        switch command {
        case .lowLatency: isLowLatencyEnabled = isEnabled
        case .inEarDetection: isInEarDetectionEnabled = isEnabled
        case .ldac: isLDACEnabled = isEnabled
        default: break
        }
    }
}
