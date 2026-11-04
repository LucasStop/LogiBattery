import Foundation

enum HIDPPError: Error, Equatable {
    case noDevice
    case timeout
    case malformed
    case unsupported
}

/// Long report HID++ 2.0 (ID `0x11`, 20 bytes): `11 índice feature função|sw params…`.
struct HIDPPFrame: Equatable, Sendable {
    static let reportID: UInt8 = 0x11
    static let length = 20
    /// Software id 1...15 por pedido: resposta atrasada de um pedido não casa com o seguinte (0 é dos eventos).
    static let softwareIDs: ClosedRange<UInt8> = 1...15
    static let defaultSoftwareID: UInt8 = 1

    let bytes: [UInt8]

    var deviceIndex: UInt8 { bytes[1] }
    var featureIndex: UInt8 { bytes[2] }
    var params: [UInt8] { Array(bytes[4...]) }

    init(deviceIndex: UInt8, featureIndex: UInt8, function: UInt8, params: [UInt8] = [],
         softwareID: UInt8 = HIDPPFrame.defaultSoftwareID) {
        var bytes: [UInt8] = [Self.reportID, deviceIndex, featureIndex, (function << 4) | softwareID] + params
        bytes += [UInt8](repeating: 0, count: Self.length - bytes.count)
        self.bytes = bytes
    }

    /// Descarta o que não é resposta HID++ 2.0 válida: report curto (menos de 20 bytes derrubava `params[2]`) e
    /// erros (`0x8F` do HID++ 1.0, `0xFF` do 2.0).
    init?(response bytes: [UInt8]) {
        guard bytes.count >= Self.length, bytes[0] == Self.reportID, bytes[2] != 0x8F, bytes[2] != 0xFF else {
            return nil
        }
        self.bytes = bytes
    }

    /// Mesmo pedido com outro software id, para a resposta atrasada de um pedido não casar com o seguinte (#116).
    func withSoftwareID(_ softwareID: UInt8) -> HIDPPFrame {
        var copy = bytes
        copy[3] = (copy[3] & 0xF0) | (softwareID & 0x0F)
        return HIDPPFrame(rawBytes: copy)
    }

    private init(rawBytes: [UInt8]) {
        bytes = rawBytes
    }

    /// Resposta casa com pedido por índice, feature e função+sw; eventos e respostas atrasadas não casam.
    func answers(_ request: HIDPPFrame) -> Bool {
        bytes[1...3] == request.bytes[1...3]
    }

    enum Match: Equatable {
        case response(HIDPPFrame)
        /// Erro HID++ 1.0 (`10 índice 8F`) ou 2.0 (`11 índice FF feature função|sw erro`) para este pedido: o aparelho
        /// recusou e a espera pelo timeout é desperdício (#116).
        case error
        case unrelated
    }

    /// Classifica um report recebido contra o pedido em andamento.
    static func match(_ report: [UInt8], for request: HIDPPFrame) -> Match {
        guard report.count >= 5, report[1] == request.deviceIndex else { return .unrelated }
        if report[0] == 0x10, report[2] == 0x8F { return .error }
        if report[0] == reportID, report[2] == 0xFF,
           report[3] == request.bytes[2], report[4] == request.bytes[3] {
            return .error
        }
        if let frame = HIDPPFrame(response: report), frame.answers(request) { return .response(frame) }
        return .unrelated
    }
}
