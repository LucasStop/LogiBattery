import XCTest
@testable import LogiBattery

final class HIDPPBatteryTests: XCTestCase {
    func testReadsMouseOverBolt() async throws {
        let session = HIDPPSession(transport: try FixtureTransport(fixture: "bolt-mx-master-3s"), deviceIndex: 2)
        let reading = try await session.readDevice()
        XCTAssertEqual(reading.name, "MX Master 3S")
        XCTAssertEqual(reading.percent, 90)
        XCTAssertEqual(reading.chargeState, .discharging)
    }

    func testReadsKeyboardOverLightspeed() async throws {
        let session = HIDPPSession(transport: try FixtureTransport(fixture: "lightspeed-pro-x-tkl"), deviceIndex: 1)
        let reading = try await session.readDevice()
        XCTAssertEqual(reading.name, "PRO X TKL")
        XCTAssertEqual(reading.percent, 79)
    }

    func testIndexWithoutDeviceThrows() async throws {
        let session = HIDPPSession(transport: try FixtureTransport(fixture: "bolt-mx-master-3s"), deviceIndex: 5)
        do {
            _ = try await session.readDevice()
            XCTFail("esperava erro")
        } catch {
            XCTAssertEqual(error as? HIDPPError, .noDevice)
        }
    }

    func testFrameRejectsErrorAndShortReports() {
        let hidpp1Error: [UInt8] = [0x10, 0x03, 0x8F, 0x00, 0x01, 0x09, 0x00]
        XCTAssertNil(HIDPPFrame(response: hidpp1Error))
        let hidpp2Error = [0x11, 0x01, 0xFF, 0x00] + [UInt8](repeating: 0, count: 16)
        XCTAssertNil(HIDPPFrame(response: hidpp2Error))
        XCTAssertNil(HIDPPFrame(response: [0x11, 0x01]))
    }

    func testRequestFrameLayout() {
        let frame = HIDPPFrame(deviceIndex: 2, featureIndex: 0, function: 0, params: [0x10, 0x04])
        XCTAssertEqual(Array(frame.bytes.prefix(6)), [0x11, 0x02, 0x00, 0x01, 0x10, 0x04])
        XCTAssertEqual(frame.bytes.count, 20)
    }
}

/// Frames reais capturados com o Logi Options+ aberto: só evento do aparelho dispara releitura.
final class DeviceEventFilterTests: XCTestCase {
    func testDeviceEventsCount() {
        XCTAssertTrue(IOHIDTransport.isDeviceEvent([0x10, 0x01, 0x41, 0x11, 0xA1, 0xB0, 0x40]))
        XCTAssertTrue(IOHIDTransport.isDeviceEvent([0x11, 0x01, 0x07, 0x00, 0x4C, 0x08, 0x00, 0x00]))
        XCTAssertTrue(IOHIDTransport.isDeviceEvent([0x11, 0x01, 0x04, 0x00, 0x01, 0x01, 0x01, 0x00]))
    }

    func testErrorsAndAnswersToOtherRequestsDoNotCount() {
        XCTAssertFalse(IOHIDTransport.isDeviceEvent([0x10, 0xFF, 0x8F, 0x83, 0xB5, 0x09, 0x00]))
        XCTAssertFalse(IOHIDTransport.isDeviceEvent([0x11, 0x01, 0x07, 0x11, 0x4C, 0x08, 0x00, 0x00]))
        XCTAssertFalse(IOHIDTransport.isDeviceEvent([0x11, 0x01, 0xFF, 0x07, 0x11, 0x05, 0x00, 0x00]))
        XCTAssertFalse(IOHIDTransport.isDeviceEvent([0x02, 0x00, 0x01, 0x00, 0x00]))
    }
}
