import XCTest
@testable import LogiBattery

final class ReceiverEnumerationTests: XCTestCase {
    func testListsOnlyPairedDevicesSortedByLowestBattery() async throws {
        let bolt = HIDEndpoint(id: "bolt", transport: try FixtureTransport(fixture: "bolt-mx-master-3s"))
        let lightspeed = HIDEndpoint(id: "lightspeed", transport: try FixtureTransport(fixture: "lightspeed-pro-x-tkl"))
        let devices = await DeviceScanner(endpoints: [bolt, lightspeed]).scan()
        XCTAssertEqual(devices.map(\.name), ["PRO X TKL", "MX Master 3S"])
        XCTAssertEqual(devices.map(\.percent), [79, 90])
        XCTAssertEqual(devices.map(\.path), [.receiver, .receiver])
    }

    func testReceiverWithNoDevicesYieldsEmptyList() async {
        let devices = await DeviceScanner(endpoints: [HIDEndpoint(id: "vazio", transport: SilentTransport())]).scan()
        XCTAssertTrue(devices.isEmpty)
    }
}

private struct SilentTransport: HIDPPTransport {
    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame { throw HIDPPError.noDevice }
}
