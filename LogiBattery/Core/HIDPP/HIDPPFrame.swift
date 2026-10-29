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
    static let softwareID: UInt8 = 1

    let bytes: [UInt8]

    var deviceIndex: UInt8 { bytes[1] }
    var featureIndex: UInt8 { bytes[2] }
    var params: [UInt8] { Array(bytes[4...]) }

    init(deviceIndex: UInt8, featureIndex: UInt8, function: UInt8, params: [UInt8] = []) {
        var bytes: [UInt8] = [Self.reportID, deviceIndex, featureIndex, (function << 4) | Self.softwareID] + params
        bytes += [UInt8](repeating: 0, count: Self.length - bytes.count)
        self.bytes = bytes
    }

    /// Descarta o que não é resposta HID++ 2.0 válida: report curto e erros (`0x8F` do HID++ 1.0, `0xFF` do 2.0).
    init?(response bytes: [UInt8]) {
        guard bytes.count >= 5, bytes[0] == Self.reportID, bytes[2] != 0x8F, bytes[2] != 0xFF else { return nil }
        self.bytes = bytes
    }

    /// Resposta casa com pedido por índice, feature e função+sw; eventos e respostas atrasadas não casam.
    func answers(_ request: HIDPPFrame) -> Bool {
        bytes[1...3] == request.bytes[1...3]
    }
}
