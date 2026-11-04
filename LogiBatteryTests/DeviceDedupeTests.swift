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

    func testBluetoothRecordWithGarbledNameIsDroppedLeavingOneDevice() async throws {
        let good = HIDEndpoint(id: "ble-b034-a", transport: try FixtureTransport(fixture: "bluetooth-mx-master-3s"),
                               path: .bluetooth)
        let garbled = HIDEndpoint(id: "ble-b034-b", transport: try FixtureTransport(fixture: "bluetooth-mx-master-3s") {
            if $0[2] == 0x03, $0[3] == 0x11 { $0[4] = 0x01 }
        }, path: .bluetooth)
        let devices = await DeviceScanner(endpoints: [garbled, good]).scan()
        XCTAssertEqual(devices.map(\.name), ["MX Master 3S"])
        XCTAssertEqual(devices.map(\.kind), [.mouse])
    }

    @MainActor
    func testRestoredSnapshotDropsGarbledNameInsteadOfKeepingAsSleepingDevice() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let good = Device(id: "ble-b034-a:255", name: "MX Master 3S", kind: .mouse, percent: 85,
                          chargeState: .discharging, path: .bluetooth, readAt: now)
        let garbled = Device(id: "ble-b034-b:255", name: "Z\u{08}Z\u{08}Z", kind: .other, percent: 90,
                             chargeState: .discharging, path: .bluetooth, readAt: now)
        let snapshot = Snapshot(schemaVersion: Snapshot.schemaVersion, generatedAt: now, devices: [good, garbled])
        let viewModel = DeviceListViewModel(scanner: FixedScanner(devices: [good]), restoring: snapshot, now: { now })
        XCTAssertEqual(viewModel.devices.map(\.name), ["MX Master 3S"])
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices.map(\.name), ["MX Master 3S"])
    }

    func testHIDPPReadingBeatsGenericSystemBluetoothReading() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let hidpp = Device(id: "ble:255", name: "MX Master 3S", kind: .mouse, percent: 85,
                           chargeState: .charging, path: .bluetooth, readAt: now)
        let generic = Device(id: "bt-hid-MX Master 3S", name: "MX Master 3S", kind: .mouse, percent: 80,
                             chargeState: .discharging, path: .bluetooth, readAt: now.addingTimeInterval(1))
        let merged = DeviceDeduplicator.merge([generic, hidpp])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.id, "ble:255")
        XCTAssertEqual(merged.first?.chargeState, .charging)
    }

    /// #116: um receptor com aparelho dormindo leva 1 s por índice, então o carimbo do sistema passa dos 5 s e a
    /// leitura genérica ganhava da HID++ (perdia o estado de carga e o id trocava entre scans).
    func testHIDPPReadingBeatsGenericSystemReadingStampedSecondsLater() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let hidpp = Device(id: "ble:255", name: "MX Master 3S", kind: .mouse, percent: 85,
                           chargeState: .charging, path: .bluetooth, readAt: now)
        let generic = Device(id: "bt-hid-MX Master 3S", name: "MX Master 3S", kind: .mouse, percent: 80,
                             chargeState: .discharging, path: .bluetooth, readAt: now.addingTimeInterval(8))
        for order in [[generic, hidpp], [hidpp, generic]] {
            XCTAssertEqual(DeviceDeduplicator.merge(order).map(\.id), ["ble:255"])
        }
    }
}

private struct FixedScanner: DeviceScanning {
    let devices: [Device]
    func scan() async -> [Device] { devices }
}
