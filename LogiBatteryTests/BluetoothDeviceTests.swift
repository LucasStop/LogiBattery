import XCTest
@testable import LogiBattery

final class BluetoothDeviceTests: XCTestCase {
    func testReadsBluetoothDevicesAtBroadcastIndex() async throws {
        let mouse = HIDEndpoint(id: "ble-b034", transport: try FixtureTransport(fixture: "bluetooth-mx-master-3s"),
                                path: .bluetooth)
        let keyboard = HIDEndpoint(id: "ble-b382", transport: try FixtureTransport(fixture: "bluetooth-pro-x-tkl"),
                                   path: .bluetooth)
        let devices = await DeviceScanner(endpoints: [mouse, keyboard]).scan()
        XCTAssertEqual(devices.map(\.name), ["PRO X TKL", "MX Master 3S"])
        XCTAssertEqual(devices.map(\.percent), [79, 90])
        XCTAssertEqual(devices.map(\.path), [.bluetooth, .bluetooth])
    }

    func testBluetoothEndpointOnlyProbesBroadcastIndex() {
        XCTAssertEqual(HIDEndpoint(id: "x", transport: NoopTransport(), path: .bluetooth).deviceIndexes, [0xFF])
        XCTAssertEqual(HIDEndpoint(id: "x", transport: NoopTransport(), path: .receiver).deviceIndexes, Array(1...6))
    }
}

private struct NoopTransport: HIDPPTransport {
    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame { throw HIDPPError.noDevice }
}
