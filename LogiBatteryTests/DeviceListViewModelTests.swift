import XCTest
@testable import LogiBattery

@MainActor
final class DeviceListViewModelTests: XCTestCase {
    func testRefreshPublishesScannedDevices() async {
        let device = Device(id: "a", name: "MX Master 3S", kind: .mouse, percent: 90, chargeState: .discharging,
                            path: .receiver, readAt: Date(timeIntervalSince1970: 0))
        let viewModel = DeviceListViewModel(scanner: StubScanner(devices: [device]))
        XCTAssertFalse(viewModel.hasLoaded)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices, [device])
        XCTAssertTrue(viewModel.hasLoaded)
    }

    func testDeviceKindFromName() {
        XCTAssertEqual(DeviceKind(name: "MX Master 3S"), .mouse)
        XCTAssertEqual(DeviceKind(name: "PRO X TKL"), .keyboard)
        XCTAssertEqual(DeviceKind(name: "MX Keys"), .keyboard)
        XCTAssertEqual(DeviceKind(name: "Headset"), .other)
    }
}

private struct StubScanner: DeviceScanning {
    let devices: [Device]
    func scan() async -> [Device] { devices }
}

@MainActor
final class DeviceListPublishTests: XCTestCase {
    func testRefreshPublishesDevicesToSnapshotSink() async {
        let device = Device(id: "a", name: "MX Master 3S", kind: .mouse, percent: 90, chargeState: .discharging,
                            path: .receiver, readAt: Date(timeIntervalSince1970: 0))
        var published: [[Device]] = []
        let viewModel = DeviceListViewModel(scanner: StubScanner(devices: [device])) { published.append($0) }
        await viewModel.refresh()
        XCTAssertEqual(published, [[device]])
    }
}
