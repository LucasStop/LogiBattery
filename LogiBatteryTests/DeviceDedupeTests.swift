import XCTest
@testable import LogiBattery

final class DeviceDedupeTests: XCTestCase {
    private func device(_ name: String, _ percent: Int, _ path: DevicePath, at seconds: TimeInterval) -> Device {
        Device(id: "\(path):\(name)", name: name, kind: .mouse, percent: percent, chargeState: .discharging,
               path: path, readAt: Date(timeIntervalSince1970: seconds))
    }

    func testSameDeviceOnBothPathsKeepsMostRecentReading() {
        let receiver = device("MX Master 3S", 88, .receiver, at: 10)
        let bluetooth = device("MX Master 3S", 90, .bluetooth, at: 20)
        XCTAssertEqual(DeviceDeduplicator.merge([receiver, bluetooth]), [bluetooth])
        XCTAssertEqual(DeviceDeduplicator.merge([bluetooth, receiver]), [bluetooth])
    }

    func testTieKeepsBluetoothReading() {
        let receiver = device("MX Master 3S", 88, .receiver, at: 10)
        let bluetooth = device("MX Master 3S", 90, .bluetooth, at: 10)
        XCTAssertEqual(DeviceDeduplicator.merge([receiver, bluetooth]), [bluetooth])
    }

    func testNamesDifferingOnlyInCaseAndSpacesAreTheSameDevice() {
        let first = device("MX Master 3S", 88, .receiver, at: 10)
        let second = device(" mx  master 3s ", 90, .bluetooth, at: 5)
        XCTAssertEqual(DeviceDeduplicator.merge([first, second]).count, 1)
    }

    func testDifferentDevicesAreKept() {
        let mouse = device("MX Master 3S", 90, .receiver, at: 10)
        let keyboard = device("PRO X TKL", 79, .bluetooth, at: 10)
        XCTAssertEqual(DeviceDeduplicator.merge([mouse, keyboard]).count, 2)
    }

    func testScannerShowsOneItemWhenBothPathsRespond() async throws {
        let bolt = HIDEndpoint(id: "usb-c548", transport: try FixtureTransport(fixture: "bolt-mx-master-3s"))
        let ble = HIDEndpoint(id: "ble-b034", transport: try FixtureTransport(fixture: "bluetooth-mx-master-3s"),
                              path: .bluetooth)
        let devices = await DeviceScanner(endpoints: [bolt, ble]).scan()
        XCTAssertEqual(devices.map(\.name), ["MX Master 3S"])
    }
}
