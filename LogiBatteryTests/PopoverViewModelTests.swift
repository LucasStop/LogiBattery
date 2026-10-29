import XCTest
@testable import LogiBattery

@MainActor
final class PopoverViewModelTests: XCTestCase {
    private func device(_ id: String, percent: Int?, state: ChargeState = .discharging) -> Device {
        Device(id: id, name: id, kind: .mouse, percent: percent, chargeState: state, path: .receiver,
               readAt: Date(timeIntervalSince1970: 0))
    }

    private func viewModel(_ devices: [Device]) async -> DeviceListViewModel {
        let viewModel = DeviceListViewModel(scanner: FixedScanner(devices: devices))
        await viewModel.refresh()
        return viewModel
    }

    func testMenuBarShowsLowestPercent() async {
        let viewModel = await viewModel([device("a", percent: 64), device("b", percent: 18), device("c", percent: nil)])
        XCTAssertEqual(viewModel.menuBarPercent, 18)
        XCTAssertEqual(viewModel.menuBarSymbol, "battery.25")
    }

    func testMenuBarWithoutReadingsShowsNoPercent() async {
        let viewModel = await viewModel([device("a", percent: nil)])
        XCTAssertNil(viewModel.menuBarPercent)
        XCTAssertEqual(viewModel.menuBarSymbol, "questionmark.circle")
    }

    func testSymbolFollowsLevelBuckets() {
        XCTAssertEqual(DeviceListViewModel.symbol(forPercent: 100), "battery.100")
        XCTAssertEqual(DeviceListViewModel.symbol(forPercent: 80), "battery.75")
        XCTAssertEqual(DeviceListViewModel.symbol(forPercent: 55), "battery.50")
        XCTAssertEqual(DeviceListViewModel.symbol(forPercent: 30), "battery.25")
        XCTAssertEqual(DeviceListViewModel.symbol(forPercent: 5), "battery.0")
    }

    func testListIsSortedLowestFirst() async {
        let viewModel = await viewModel([device("a", percent: 78), device("b", percent: 18), device("c", percent: 64)])
        XCTAssertEqual(viewModel.devices.map(\.id), ["b", "c", "a"])
    }

    func testLastRefreshIsSetAfterRefresh() async {
        let viewModel = DeviceListViewModel(scanner: FixedScanner(devices: []))
        XCTAssertNil(viewModel.lastRefresh)
        await viewModel.refresh()
        XCTAssertNotNil(viewModel.lastRefresh)
    }
}

private struct FixedScanner: DeviceScanning {
    let devices: [Device]
    func scan() async -> [Device] { devices }
}

@MainActor
final class RestoreOnLaunchTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(age: TimeInterval) -> Snapshot {
        let device = Device(id: "a", name: "PRO X TKL", kind: .keyboard, percent: 78, chargeState: .discharging,
                            path: .bluetooth, readAt: now.addingTimeInterval(-age))
        return Snapshot(schemaVersion: Snapshot.schemaVersion, generatedAt: now.addingTimeInterval(-age),
                        devices: [device])
    }

    func testFreshSnapshotShowsBeforeFirstReading() {
        let viewModel = DeviceListViewModel(scanner: StaticScanner(), restoring: snapshot(age: 60), now: now)
        XCTAssertEqual(viewModel.menuBarPercent, 78)
        XCTAssertEqual(viewModel.menuBarSymbol, "battery.75")
    }

    func testStaleOrMissingSnapshotShowsNeutralReadingSymbol() {
        let stale = DeviceListViewModel(scanner: StaticScanner(), restoring: snapshot(age: 3600), now: now)
        XCTAssertNil(stale.menuBarPercent)
        XCTAssertEqual(stale.menuBarSymbol, "ellipsis.circle")
        XCTAssertEqual(DeviceListViewModel(scanner: StaticScanner()).menuBarSymbol, "ellipsis.circle")
    }

    func testEmptyReadingAfterLoadKeepsQuestionMark() async {
        let viewModel = DeviceListViewModel(scanner: StaticScanner())
        await viewModel.refresh()
        XCTAssertEqual(viewModel.menuBarSymbol, "questionmark.circle")
    }
}

private struct StaticScanner: DeviceScanning {
    func scan() async -> [Device] { [] }
}
