import XCTest
@testable import LogiBattery

/// Leitura da tabela de features (`0x0001`) a partir de frames reais gravados por `tools/hidpp-dump`.
final class HIDPPFeatureTableTests: XCTestCase {
    func testReadsEveryFeatureOfKeyboardOverLightspeed() async throws {
        let session = HIDPPSession(transport: try FixtureTransport(fixture: "features-lightspeed-pro-x-tkl"),
                                   deviceIndex: 1)
        let table = try await session.featureTable()
        XCTAssertEqual(table.entries.count, 33)
        XCTAssertEqual(table.slot(of: 0x1004), 7)
        XCTAssertEqual(table.slot(of: 0x8060), 18) // ReportRate
        XCTAssertEqual(table.slot(of: 0x8100), 17) // OnboardProfiles
        XCTAssertTrue(table.has(0x8071)) // RgbEffects
        XCTAssertTrue(table.has(0x8081)) // PerKeyLightingV2
        XCTAssertTrue(table.has(0x40A3)) // K375sFnInversion
        XCTAssertTrue(table.has(0x1E00)) // EnableHiddenFeatures
        XCTAssertFalse(table.has(0x8070)) // ColorLedEffects não existe neste firmware
    }

    func testReadsEveryFeatureOfMouseOverBolt() async throws {
        let session = HIDPPSession(transport: try FixtureTransport(fixture: "features-bolt-mx-master-3s"),
                                   deviceIndex: 2)
        let table = try await session.featureTable()
        XCTAssertEqual(table.entries.count, 35)
        XCTAssertEqual(table.slot(of: 0x2201), 13) // AdjustableDpi
        XCTAssertTrue(table.has(0x1B04)) // ReprogControlsV4
        XCTAssertTrue(table.has(0x2121)) // HiResWheel
        XCTAssertTrue(table.has(0x2250)) // XYStats
        XCTAssertTrue(table.has(0x2251)) // WheelStats
        XCTAssertFalse(table.has(0x8060)) // ReportRate é feature de teclado G
    }

    func testDecodesVersionAndTypeFromPackedByte() async throws {
        let session = HIDPPSession(transport: try FixtureTransport(fixture: "features-lightspeed-pro-x-tkl"),
                                   deviceIndex: 1)
        let table = try await session.featureTable()
        let deviceReset = try XCTUnwrap(table.entries.first { $0.id == 0x1802 })
        XCTAssertEqual(deviceReset.version, 7)
        XCTAssertEqual(deviceReset.type, 0)
        let hostFeature = try XCTUnwrap(table.entries.first { $0.id == 0x1890 })
        XCTAssertEqual(hostFeature.version, 6)
        XCTAssertEqual(hostFeature.type, 8)
    }

    func testTableOfIndexWithoutDeviceThrows() async throws {
        let session = HIDPPSession(transport: try FixtureTransport(fixture: "features-bolt-mx-master-3s"),
                                   deviceIndex: 5)
        do {
            _ = try await session.featureTable()
            XCTFail("esperava erro")
        } catch {
            XCTAssertEqual(error as? HIDPPError, .noDevice)
        }
    }

    func testUnknownFeatureKeepsHexInsteadOfGuessedName() {
        XCTAssertEqual(HIDPPFeatureCatalog.name(for: 0x9999), "0x9999")
        XCTAssertEqual(HIDPPFeatureCatalog.name(for: 0x8060), "ReportRate")
    }

    func testEmptyFeatureSetReturnsEmptyTable() async throws {
        let transport = EmptyFeatureSetTransport()
        let table = try await HIDPPSession(transport: transport, deviceIndex: 1).featureTable()
        XCTAssertTrue(table.entries.isEmpty)
        XCTAssertTrue(table.ids.isEmpty)
    }
}

/// FeatureSet com contagem zero: o Root acha a `0x0001` no slot 1, mas o aparelho não lista nada.
private struct EmptyFeatureSetTransport: HIDPPTransport {
    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame {
        let isRootLookup = request.featureIndex == 0x00
        var bytes = [UInt8](repeating: 0, count: HIDPPFrame.length)
        bytes[0] = HIDPPFrame.reportID
        bytes[1] = request.deviceIndex
        bytes[2] = request.featureIndex
        bytes[3] = request.bytes[3]
        if isRootLookup { bytes[4] = 0x01 } // slot da FeatureSet
        guard let frame = HIDPPFrame(response: bytes) else { throw HIDPPError.malformed }
        return frame
    }
}
