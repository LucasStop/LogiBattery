import XCTest
@testable import LogiBattery

final class ChargeStateTests: XCTestCase {
    func testMapsUnifiedBatteryStatus() {
        XCTAssertEqual(ChargeState(unifiedBatteryStatus: 0), .discharging)
        XCTAssertEqual(ChargeState(unifiedBatteryStatus: 1), .charging)
        XCTAssertEqual(ChargeState(unifiedBatteryStatus: 2), .charging)
        XCTAssertEqual(ChargeState(unifiedBatteryStatus: 3), .full)
        XCTAssertEqual(ChargeState(unifiedBatteryStatus: 4), .unknown)
    }

    /// Frames de bateria sintéticos: partem do real (`status` no byte 6 da resposta da feature de bateria).
    func testSessionReportsChargingAndFull() async throws {
        for (status, expected) in [(UInt8(1), ChargeState.charging), (3, .full)] {
            let transport = try FixtureTransport(fixture: "bolt-mx-master-3s") { reply in
                if reply[2] == 0x08, reply[3] == 0x11 { reply[6] = status }
            }
            let reading = try await HIDPPSession(transport: transport, deviceIndex: 2).readDevice()
            XCTAssertEqual(reading.chargeState, expected)
        }
    }
}
