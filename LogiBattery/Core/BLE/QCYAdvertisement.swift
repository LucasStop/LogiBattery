import Foundation

/// Nível de um componente do fone. Bit 7 do byte cru é a flag de carga; os 7 bits baixos são a porcentagem.
struct QCYBatteryLevel: Equatable, Sendable {
    let percent: Int
    let isCharging: Bool

    init(raw: UInt8) {
        percent = Int(raw & 0x7F)
        isCharging = raw & 0x80 != 0
    }
}

/// Advertising do fone QCY: company id `0x521C` e, no payload, bateria de cada lado, do estojo e os MACs.
///
/// Formato do projeto Quicky (`docs/protocol.md`), conferido nos bytes reais do MeloBuds Pro. Os offsets do
/// documento contam a partir do primeiro byte **depois** do company id; o `CoreBluetooth` entrega o company id
/// nos dois primeiros bytes, em little-endian.
struct QCYAdvertisement: Equatable, Sendable {
    static let companyID: UInt16 = 0x521C

    let vendorID: UInt16
    let colorIndex: Int
    let left: QCYBatteryLevel
    let right: QCYBatteryLevel
    /// `nil` quando o estojo reporta `0x00`, que é "sem leitura" (fora do alcance ou desligado), não 0%.
    let caseBattery: QCYBatteryLevel?
    let controlMAC: String?
    let otherMAC: String?

    /// 20 bytes é o mínimo para vendor id e bateria; 26 para os dois MACs (24 de payload).
    init?(manufacturerData data: Data) {
        let bytes = Array(data)
        guard bytes.count >= 20 else { return nil }
        guard UInt16(bytes[0]) | UInt16(bytes[1]) << 8 == Self.companyID else { return nil }
        let payload = Array(bytes.dropFirst(2))
        guard payload.count >= 18 else { return nil }

        vendorID = UInt16(payload[0]) << 8 | UInt16(payload[1])
        colorIndex = Int((payload[3] & 0x18) >> 1)
        left = QCYBatteryLevel(raw: payload[5])
        right = QCYBatteryLevel(raw: payload[6])
        caseBattery = payload[7] == 0 ? nil : QCYBatteryLevel(raw: payload[7])
        let control = payload.count >= 17 ? Self.mac(Array(payload[11...16])) : nil
        let other = payload.count >= 24 ? Self.mac(Array(payload[18...23])) : nil
        controlMAC = control
        // O documento manda tratar MAC zerado como "o mesmo do controle".
        otherMAC = other == "00:00:00:00:00:00" ? control : other
    }

    /// Ordem embaralhada no advertising: `[12]:[11]:[13]:[16]:[15]:[14]` a partir do primeiro byte do MAC.
    private static func mac(_ field: [UInt8]) -> String {
        let order = [1, 0, 2, 5, 4, 3]
        return order.map { String(format: "%02X", field[$0]) }.joined(separator: ":")
    }
}
