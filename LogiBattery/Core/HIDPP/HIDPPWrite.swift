import Foundation

/// Modo da roda em `0x2110` (`SmartShift`). O valor é exatamente o byte que vai no frame.
enum HIDPPSmartShiftMode: UInt8, Equatable, Sendable {
    case freeSpin = 0x01
    case ratchet = 0x02
}

/// Escrita de configuração HID++ 2.0 sem transporte: feature, função e parâmetros.
/// Montar o frame separado do envio é o que permite `--dry-run` mostrar o que sairia sem tocar no aparelho.
enum HIDPPWrite: Equatable, Sendable {
    /// `0x2201` função 3 (`setSensorDpi`): `[sensor, dpi hi, dpi lo]`.
    case dpi(sensor: UInt8, dpi: UInt16)
    /// `0x2110` função 1 (`setRatchetControlMode`): `[modo, threshold, threshold padrão]`.
    /// `mode` nil escreve 0 = preserva o modo; threshold 0 preserva o valor atual e `0xFF` é catraca permanente.
    case smartShift(mode: HIDPPSmartShiftMode?, threshold: UInt8, defaultThreshold: UInt8 = 0)

    var featureID: UInt16 {
        switch self {
        case .dpi: return HIDPPFeatureID.adjustableDpi
        case .smartShift: return HIDPPFeatureID.smartShift
        }
    }

    /// Função no nibble alto do byte 3 do frame.
    var function: UInt8 {
        switch self {
        case .dpi: return 0x3
        case .smartShift: return 0x1
        }
    }

    var params: [UInt8] {
        switch self {
        case let .dpi(sensor, dpi):
            return [sensor, UInt8(dpi >> 8), UInt8(dpi & 0xFF)]
        case let .smartShift(mode, threshold, defaultThreshold):
            return [mode?.rawValue ?? 0, threshold, defaultThreshold]
        }
    }

    func frame(deviceIndex: UInt8, featureIndex: UInt8) -> HIDPPFrame {
        HIDPPFrame(deviceIndex: deviceIndex, featureIndex: featureIndex, function: function, params: params)
    }
}

/// Sensor de DPI lido de `0x2201`: valor atual, padrão de fábrica e faixa que o firmware aceita.
struct HIDPPDPISensor: Equatable, Sendable {
    let index: UInt8
    let current: UInt16
    let defaultDPI: UInt16
    let minimum: UInt16
    let maximum: UInt16
    let steps: UInt16
}

extension HIDPPDPISensor {
    /// `list` é a resposta da função 1 (`getSensorDpiList`): eco do sensor e pares big-endian até um 0.
    /// Valor acima de `0xE000` é o passo do firmware, não um DPI da lista (mesma leitura do libratbag).
    init(index: UInt8, list: [UInt8], current: [UInt8]) throws {
        guard current.count >= 5 else { throw HIDPPError.malformed }
        var minimum = UInt16.max
        var maximum: UInt16 = 0
        var steps: UInt16 = 0
        var offset = 1
        while offset + 1 < list.count {
            let value = UInt16(list[offset]) << 8 | UInt16(list[offset + 1])
            offset += 2
            guard value != 0 else { break }
            if value > 0xE000 {
                steps = value - 0xE000
            } else {
                minimum = min(minimum, value)
                maximum = max(maximum, value)
            }
        }
        guard maximum > 0 else { throw HIDPPError.malformed }
        self.init(index: index,
                  current: UInt16(current[1]) << 8 | UInt16(current[2]),
                  defaultDPI: UInt16(current[3]) << 8 | UInt16(current[4]),
                  minimum: minimum, maximum: maximum, steps: steps)
    }
}

/// Estado do `SmartShift` lido de `0x2110` função 0.
struct HIDPPSmartShift: Equatable, Sendable {
    let mode: HIDPPSmartShiftMode
    let threshold: UInt8
    let defaultThreshold: UInt8
}

extension HIDPPSmartShift {
    /// `params` da função 0 (`getRatchetControlMode`): modo, threshold atual e o padrão de fábrica.
    init(params: [UInt8]) throws {
        guard params.count >= 3, let mode = HIDPPSmartShiftMode(rawValue: params[0]) else {
            throw HIDPPError.malformed
        }
        self.init(mode: mode, threshold: params[1], defaultThreshold: params[2])
    }
}
