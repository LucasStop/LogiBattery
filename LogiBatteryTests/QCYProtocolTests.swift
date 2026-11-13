import XCTest
@testable import LogiBattery

/// Protocolo do fone QCY a partir do advertising e da notificação reais gravados em `Tests/Fixtures/qcy/`.
final class QCYProtocolTests: XCTestCase {
    // MARK: - Advertising

    func testReadsBatteryAndMACsFromRealAdvertisement() throws {
        let advertisement = try XCTUnwrap(QCYAdvertisement(manufacturerData: Data(try qcyFixture(
            "qcy-advertisement-melobuds-pro"))))
        XCTAssertEqual(advertisement.vendorID, 0x4D4A)
        XCTAssertEqual(advertisement.left, QCYBatteryLevel(raw: 0x5D))
        XCTAssertEqual(advertisement.right, QCYBatteryLevel(raw: 0x5E))
        XCTAssertNil(advertisement.caseBattery)
        XCTAssertEqual(advertisement.controlMAC, "84:AC:60:E9:90:6E")
        XCTAssertEqual(advertisement.otherMAC, "84:AC:60:E9:9D:2F")
    }

    func testChargingFlagComesFromHighBit() {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x1C
        bytes[1] = 0x52
        bytes[2 + 5] = 0x80 | 57
        bytes[2 + 6] = 0x80 | 60
        bytes[2 + 7] = 0x80 | 80
        let advertisement = QCYAdvertisement(manufacturerData: Data(bytes))
        XCTAssertEqual(advertisement?.left, QCYBatteryLevel(raw: 0x80 | 57))
        XCTAssertEqual(advertisement?.left.percent, 57)
        XCTAssertEqual(advertisement?.left.isCharging, true)
        XCTAssertEqual(advertisement?.right.percent, 60)
        XCTAssertEqual(advertisement?.caseBattery?.percent, 80)
        XCTAssertEqual(advertisement?.caseBattery?.isCharging, true)
    }

    func testForeignAndShortDataAreIgnored() throws {
        var foreign = try qcyFixture("qcy-advertisement-melobuds-pro")
        foreign[0] = 0xD6
        foreign[1] = 0x05 // company id dos relógios QCY, que não é fone
        XCTAssertNil(QCYAdvertisement(manufacturerData: Data(foreign)))
        XCTAssertNil(QCYAdvertisement(manufacturerData: Data(foreign.prefix(19))))
        XCTAssertNil(QCYAdvertisement(manufacturerData: Data()))
    }

    func testAdvertisingWithTwentyBytesStillReadsControlMAC() throws {
        let bytes = [UInt8](try qcyFixture("qcy-advertisement-melobuds-pro").prefix(20))
        let advertisement = QCYAdvertisement(manufacturerData: Data(bytes))
        XCTAssertEqual(advertisement?.controlMAC, "84:AC:60:E9:90:6E")
        XCTAssertNil(advertisement?.otherMAC)
    }

    // MARK: - Pacote

    func testDecodesRealSnapshotNotification() throws {
        let packet = try XCTUnwrap(QCYPacket(data: Data(try qcyFixture("qcy-snapshot-melobuds-pro"))))
        XCTAssertEqual(packet.blocks.map(\.command),
                       [0x2C, 0x08, 0x09, 0x17, 0x10, 0x16, 0x04, 0x23, 0x24, 0x1F, 0x1D, 0x19])
        XCTAssertEqual(packet.blocks.first { $0.command == 0x17 }?.parameters, [0x03, 0x02, 0x00])
        XCTAssertEqual(packet.blocks.first { $0.command == 0x09 }?.parameters, [0x02])
        XCTAssertEqual(packet.blocks.first { $0.command == 0x23 }?.parameters, [0x00])
        XCTAssertEqual(String(bytes: packet.blocks.last?.parameters ?? [], encoding: .utf8), "WQ00")
    }

    func testEncodesBatteryRequest() {
        XCTAssertEqual(Array(QCYPacket.request(.battery).encoded()), [0xFF, 0x03, 0xFE, 0x01, 0x2F])
        XCTAssertEqual(Array(QCYPacket.request(.version).encoded()), [0xFF, 0x03, 0xFE, 0x01, 0x30])
    }

    func testEncodesNoiseAndToggleCommands() {
        XCTAssertEqual(Array(QCYPacket.noiseCancelMode(0x01).encoded()), [0xFF, 0x03, 0x0C, 0x01, 0x01])
        XCTAssertEqual(Array(QCYPacket.ancSetting(mode: 0x02, subScene: 0x03, noiseValue: 0x0A).encoded()),
                       [0xFF, 0x05, 0x17, 0x03, 0x02, 0x03, 0x0A])
        XCTAssertEqual(Array(QCYPacket.setLowLatency(true).encoded()), [0xFF, 0x03, 0x09, 0x01, 0x01])
        XCTAssertEqual(Array(QCYPacket.setLowLatency(false).encoded()), [0xFF, 0x03, 0x09, 0x01, 0x02])
        XCTAssertEqual(Array(QCYPacket.setInEarDetection(false).encoded()), [0xFF, 0x03, 0x06, 0x01, 0x02])
        XCTAssertEqual(Array(QCYPacket.setLDAC(true).encoded()), [0xFF, 0x03, 0x23, 0x01, 0x01])
        XCTAssertEqual(Array(QCYPacket.setLDAC(false).encoded()), [0xFF, 0x03, 0x23, 0x01, 0x02])
    }

    func testRoundTripKeepsBlocks() throws {
        let packet = QCYPacket([.init(command: 0x2F, parameters: [0x5C, 0x5D, 0x00]),
                                .init(command: 0x30, parameters: [0x02, 0x00, 0x06])])
        let decoded = try XCTUnwrap(QCYPacket(data: packet.encoded()))
        XCTAssertEqual(decoded, packet)
    }

    func testRejectsTruncatedOrUnframedPacket() throws {
        let bytes = try qcyFixture("qcy-snapshot-melobuds-pro")
        XCTAssertNil(QCYPacket(data: Data(bytes.dropLast())))
        XCTAssertNil(QCYPacket(data: Data([0xFE] + bytes.dropFirst())))
        XCTAssertNil(QCYPacket(data: Data()))
        XCTAssertEqual(QCYPacket(data: Data([0xFF, 0x00]))?.blocks, [])
    }

    // MARK: - Estado

    func testAppliesBatteryReadFromCharacteristic() {
        var state = QCYState()
        state.apply(QCYPacket.Block(command: 0x2F, parameters: [0x5C, 0x5D, 0x00]))
        XCTAssertEqual(state.left?.percent, 92)
        XCTAssertEqual(state.right?.percent, 93)
        XCTAssertNil(state.caseBattery)
    }

    func testAppliesFirmwareFromSixByteVersion() {
        var state = QCYState()
        state.apply(QCYPacket.Block(command: 0x30, parameters: [0x02, 0x00, 0x06, 0x02, 0x01, 0x03]))
        XCTAssertEqual(state.firmware, QCYFirmware(left: "2.0.6", right: "2.1.3"))
    }

    func testKeepsEarlierValuesWhenNotificationIsPartial() throws {
        var state = QCYState()
        state.apply(QCYPacket.Block(command: 0x2F, parameters: [0x5D, 0x5E, 0x80 | 40]))
        state.apply(try XCTUnwrap(QCYPacket(data: Data(try qcyFixture("qcy-snapshot-melobuds-pro")))))
        XCTAssertEqual(state.left?.percent, 93)
        XCTAssertEqual(state.caseBattery?.percent, 40)
        XCTAssertEqual(state.isLDACEnabled, false)
        XCTAssertEqual(state.isLowLatencyEnabled, false)
        XCTAssertEqual(state.ancScene, QCYANScene(mode: 0x03, subScene: 0x02, noiseValue: 0x00))
        XCTAssertNil(state.noiseCancelMode) // o retrato não traz 0x0C
        XCTAssertNil(state.isInEarDetectionEnabled) // o retrato não traz 0x06
    }

    func testNoiseCancelModeUsesTheSimpleTable() {
        XCTAssertEqual(QCYNoiseCancelMode(rawValue: 0x00)?.name, "Desligado")
        XCTAssertEqual(QCYNoiseCancelMode(rawValue: 0x01)?.name, "ANC")
        XCTAssertEqual(QCYNoiseCancelMode(rawValue: 0x02)?.name, "ANC externo")
        XCTAssertEqual(QCYNoiseCancelMode(rawValue: 0x03)?.name, "Transparência")
        XCTAssertNil(QCYNoiseCancelMode(rawValue: 0x7F))
    }

    /// Regressão do bug que a escrita expôs: `0x0C` (modo atual) e `0x17` (cena) vêm na mesma conexão e,
    /// guardados num campo só, o estado oscilava conforme a ordem das respostas.
    func testNoiseModeAndSceneDoNotOverwriteEachOther() {
        var state = QCYState()
        state.apply(QCYPacket.Block(command: 0x0C, parameters: [0x02]))
        state.apply(QCYPacket.Block(command: 0x17, parameters: [0x03, 0x02, 0x00]))
        XCTAssertEqual(state.noiseCancelMode, .outdoor)
        XCTAssertEqual(state.ancScene, QCYANScene(mode: 3, subScene: 2, noiseValue: 0))

        var reversed = QCYState()
        reversed.apply(QCYPacket.Block(command: 0x17, parameters: [0x03, 0x02, 0x00]))
        reversed.apply(QCYPacket.Block(command: 0x0C, parameters: [0x02]))
        XCTAssertEqual(reversed, state)
    }
}
