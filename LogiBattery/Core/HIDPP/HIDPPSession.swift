import Foundation

/// Leitura de um aparelho por HID++ 2.0 (nome e bateria). Um índice de receptor, uma sessão.
struct HIDPPSession: Sendable {
    // Features usadas: Root `0x0000`, DeviceName `0x0005`, UnifiedBattery `0x1004`.
    // ponytail: só `0x1004` (os dois aparelhos do Lucas usam); `0x1000`/`0x1001` quando aparecer aparelho que precise.
    private static let deviceNameFeature: UInt16 = 0x0005
    private static let unifiedBatteryFeature: UInt16 = 0x1004

    let transport: any HIDPPTransport
    let deviceIndex: UInt8

    func readDevice() async throws -> DeviceReading {
        let name = try await readName()
        let battery = try await readBattery()
        return DeviceReading(name: name, percent: battery.percent, chargeState: battery.chargeState)
    }

    private func featureIndex(_ id: UInt16) async throws -> UInt8 {
        let request = HIDPPFrame(deviceIndex: deviceIndex, featureIndex: 0x00, function: 0,
                                 params: [UInt8(id >> 8), UInt8(id & 0xFF)])
        let index = try await transport.exchange(request).params[0]
        guard index != 0 else { throw HIDPPError.unsupported }
        return index
    }

    private func readName() async throws -> String {
        let feature = try await featureIndex(Self.deviceNameFeature)
        let count = Int(try await call(feature, function: 0).params[0])
        var name = [UInt8]()
        while name.count < count {
            let chunk = try await call(feature, function: 1, params: [UInt8(name.count)]).params
            let piece = chunk.prefix { $0 != 0 }
            guard !piece.isEmpty else { break }
            name += piece
        }
        guard let text = String(bytes: name.prefix(count), encoding: .utf8) else { throw HIDPPError.malformed }
        return text
    }

    private func readBattery() async throws -> (percent: Int, chargeState: ChargeState) {
        let feature = try await featureIndex(Self.unifiedBatteryFeature)
        let params = try await call(feature, function: 1).params
        return (Int(params[0]), ChargeState(unifiedBatteryStatus: params[2]))
    }

    private func call(_ feature: UInt8, function: UInt8, params: [UInt8] = []) async throws -> HIDPPFrame {
        try await transport.exchange(HIDPPFrame(deviceIndex: deviceIndex, featureIndex: feature,
                                                function: function, params: params))
    }
}
