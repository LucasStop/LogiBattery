import Foundation

/// Leitura de um aparelho por HID++ 2.0 (nome, tipo e bateria). Um índice de receptor, uma sessão.
struct HIDPPSession: Sendable {
    // Features usadas: Root `0x0000`, DeviceName `0x0005`, e bateria `0x1004`, `0x1000` ou `0x1001` (#89).
    let transport: any HIDPPTransport
    let deviceIndex: UInt8

    func readDevice() async throws -> DeviceReading {
        let identity = try await readIdentity()
        let battery = try await readBattery()
        return DeviceReading(name: identity.name, percent: battery.percent, chargeState: battery.chargeState,
                             kind: identity.kind)
    }

    private func featureIndex(_ id: UInt16) async throws -> UInt8 {
        let request = HIDPPFrame(deviceIndex: deviceIndex, featureIndex: 0x00, function: 0,
                                 params: [UInt8(id >> 8), UInt8(id & 0xFF)])
        let index = try await transport.exchange(request).params[0]
        guard index != 0 else { throw HIDPPError.unsupported }
        return index
    }

    private func readIdentity() async throws -> (name: String, kind: DeviceKind) {
        let feature = try await featureIndex(HIDPPFeatureID.deviceName)
        let count = Int(try await call(feature, function: 0).params[0])
        var name = [UInt8]()
        while name.count < count {
            let chunk = try await call(feature, function: 1, params: [UInt8(name.count)]).params
            let piece = chunk.prefix { $0 != 0 }
            guard !piece.isEmpty else { break }
            name += piece
        }
        guard let text = String(bytes: name.prefix(count), encoding: .utf8) else { throw HIDPPError.malformed }
        let rawType = (try? await call(feature, function: 2))?.params.first
        return (text, DeviceKind(hidppType: rawType, name: text))
    }

    private func readBattery() async throws -> (percent: Int, chargeState: ChargeState) {
        if let feature = try? await featureIndex(HIDPPFeatureID.unifiedBattery) {
            let params = try await call(feature, function: 1).params
            return (Int(params[0]), ChargeState(unifiedBatteryStatus: params[2]))
        }
        if let feature = try? await featureIndex(HIDPPFeatureID.batteryLevelStatus) {
            let params = try await call(feature, function: 0).params
            return (Int(params[0]), ChargeState(batteryLevelStatus: params[2]))
        }
        let feature = try await featureIndex(HIDPPFeatureID.batteryVoltage)
        let params = try await call(feature, function: 0).params
        let millivolts = Int(params[0]) << 8 | Int(params[1])
        return (DeviceReading.percent(fromMillivolts: millivolts), ChargeState(voltageFlags: params[2]))
    }

    /// Tabela de features do aparelho (`0x0001`): o que o firmware realmente expõe, com a versão de cada uma.
    /// Fora do ciclo de bateria de propósito — cada chamada custa uma troca por feature.
    func featureTable() async throws -> HIDPPFeatureTable {
        let featureSet = try await featureIndex(HIDPPFeatureID.featureSet)
        let count = Int(try await call(featureSet, function: 0).params[0])
        guard count > 0 else { return HIDPPFeatureTable(entries: []) }
        var entries: [HIDPPFeature] = []
        for slot in 1...UInt8(min(count, Int(UInt8.max))) {
            let params = try await call(featureSet, function: 1, params: [slot]).params
            let id = UInt16(params[0]) << 8 | UInt16(params[1])
            guard id != 0 else { continue }
            // Byte 2 = versão no nibble alto e tipo no baixo (hidpp20.py, FeatureSet.get_feature).
            entries.append(HIDPPFeature(slot: slot, id: id,
                                        type: params[2] & 0x0F, version: params[2] >> 4))
        }
        return HIDPPFeatureTable(entries: entries)
    }

    private func call(_ feature: UInt8, function: UInt8, params: [UInt8] = []) async throws -> HIDPPFrame {
        try await transport.exchange(HIDPPFrame(deviceIndex: deviceIndex, featureIndex: feature,
                                                function: function, params: params))
    }
}
