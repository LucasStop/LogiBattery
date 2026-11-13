import Foundation

/// Modo atual de cancelamento de ruído (comando `0x0C`).
enum QCYNoiseCancelMode: UInt8, Equatable, Sendable {
    case off = 0x00
    case anc = 0x01
    case outdoor = 0x02
    case transparency = 0x03

    var name: String {
        switch self {
        case .off: return "Desligado"
        case .anc: return "ANC"
        case .outdoor: return "ANC externo"
        case .transparency: return "Transparência"
        }
    }
}

/// Cena de ANC configurada (comando `0x17`): modo de ambiente, nível e profundidade.
///
/// Não é o mesmo que o modo atual. No MeloBuds Pro os dois discordam: o `0x0C` responde `2` (ANC externo)
/// enquanto o `0x17` responde `3/2`. Guardar num campo só fazia o valor oscilar conforme a ordem das respostas.
struct QCYANScene: Equatable, Sendable {
    let mode: UInt8
    let subScene: UInt8
    let noiseValue: UInt8

    /// O documento do Quicky dá `0x02/0x01..03` como ambiente silencioso, `0x03/0x01..03` como ambiente de
    /// trabalho, `0x04/0x01..03` como ambiente ruidoso e `0x0A/0x01..07` como transparência — mas também diz
    /// que o app dele remapeia `0x03/0x01` para `0x03/0x02` no caso da transparência. Como as duas leituras se
    /// contradizem, nada de nome: sai o par em hex.
    var name: String {
        String(format: "%02X/%02X", mode, subScene)
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
    var noiseCancelMode: QCYNoiseCancelMode?
    var ancScene: QCYANScene?
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
        case .noiseCancelMode: applyNoiseCancelMode(block.parameters)
        case .ancSetting: applyANScene(block.parameters)
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

    private mutating func applyNoiseCancelMode(_ parameters: [UInt8]) {
        guard let raw = parameters.first else { return }
        noiseCancelMode = QCYNoiseCancelMode(rawValue: raw)
    }

    private mutating func applyANScene(_ parameters: [UInt8]) {
        guard parameters.count >= 3 else { return }
        ancScene = QCYANScene(mode: parameters[0], subScene: parameters[1], noiseValue: parameters[2])
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
