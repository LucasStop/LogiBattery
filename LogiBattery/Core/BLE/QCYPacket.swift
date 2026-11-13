import Foundation

/// Comando do canal principal do QCY (característica `00001001`). Só os que o projeto usa ou mede.
enum QCYCommand: UInt8, Equatable, Sendable {
    case inEarDetection = 0x06
    case lowLatency = 0x09
    case noiseCancelMode = 0x0C
    case ancSetting = 0x17
    case ldac = 0x23
    case battery = 0x2F
    case version = 0x30
    case requestData = 0xFE
}

/// Pacote do canal principal: `[0xFF, tamanho do corpo]` seguido de um ou mais blocos
/// `[comando, quantidade de parâmetros, parâmetros...]`. Várias respostas chegam num pacote só.
struct QCYPacket: Equatable, Sendable {
    struct Block: Equatable, Sendable {
        let command: UInt8
        let parameters: [UInt8]
    }

    var blocks: [Block]

    init(_ blocks: [Block]) {
        self.blocks = blocks
    }

    init(command: QCYCommand, parameters: [UInt8] = []) {
        blocks = [Block(command: command.rawValue, parameters: parameters)]
    }

    /// Lê o que chega em `00001002`. Devolve `nil` se não for `0xFF` ou se um bloco passar do corpo.
    init?(data: Data) {
        let bytes = Array(data)
        guard bytes.count >= 2, bytes[0] == 0xFF else { return nil }
        let bodyLength = Int(bytes[1])
        guard bodyLength <= bytes.count - 2 else { return nil }
        let end = 2 + bodyLength
        var blocks: [Block] = []
        var offset = 2
        while offset + 1 < end {
            let length = Int(bytes[offset + 1])
            guard offset + 2 + length <= end else { return nil }
            blocks.append(Block(command: bytes[offset], parameters: Array(bytes[(offset + 2)..<(offset + 2 + length)])))
            offset += 2 + length
        }
        self.blocks = blocks
    }

    func encoded() -> Data {
        var body: [UInt8] = []
        for block in blocks {
            body.append(block.command)
            body.append(UInt8(block.parameters.count))
            body.append(contentsOf: block.parameters)
        }
        return Data([0xFF, UInt8(body.count)] + body)
    }
}

extension QCYPacket {
    /// `0xFE` pede ao fone o valor atual de qualquer comando (`0x2F` bateria, `0x30` versão...).
    static func request(_ command: QCYCommand) -> QCYPacket {
        QCYPacket(command: .requestData, parameters: [command.rawValue])
    }

    /// Modo simples (`0x0C`): 0 desligado, 1 ANC, 2 ANC externo, 3 transparência.
    static func noiseCancelMode(_ mode: UInt8) -> QCYPacket {
        QCYPacket(command: .noiseCancelMode, parameters: [mode])
    }

    /// Cena de ANC (`0x17`) usada por quem tem nível por ambiente.
    static func ancSetting(mode: UInt8, subScene: UInt8, noiseValue: UInt8) -> QCYPacket {
        QCYPacket(command: .ancSetting, parameters: [mode, subScene, noiseValue])
    }

    /// `0x01` liga, `0x02` desliga — mesmo par para jogo, detecção de ouvido e LDAC.
    static func setLowLatency(_ enabled: Bool) -> QCYPacket {
        QCYPacket(command: .lowLatency, parameters: [enabled ? 0x01 : 0x02])
    }

    static func setInEarDetection(_ enabled: Bool) -> QCYPacket {
        QCYPacket(command: .inEarDetection, parameters: [enabled ? 0x01 : 0x02])
    }

    static func setLDAC(_ enabled: Bool) -> QCYPacket {
        QCYPacket(command: .ldac, parameters: [enabled ? 0x01 : 0x02])
    }
}
