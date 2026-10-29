import XCTest
@testable import LogiBattery

/// Troca receptor <-> Bluetooth: o id do aparelho muda a cada reconexão, a identidade não.
@MainActor
final class ConnectionSwitchTests: XCTestCase {
    private var directory: URL!
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func device(_ name: String, _ percent: Int, _ path: DevicePath, id: String) -> Device {
        Device(id: id, name: name, kind: name.contains("Master") ? .mouse : .keyboard, percent: percent,
               chargeState: .discharging, path: path, readAt: start)
    }

    func testSwitchingConnectionKeepsOneRowOneSeriesAndRightMenuPercent() async throws {
        let mouse = "MX Master 3S"
        let keyboard = "PRO X TKL"
        let steps: [[Device]] = [
            [device(mouse, 90, .receiver, id: "usb-c548-1:2"), device(keyboard, 78, .receiver, id: "usb-c547-2:1")],
            [device(mouse, 90, .bluetooth, id: "ble-b034-3:255"), device(keyboard, 78, .receiver, id: "usb-c547-2:1")],
            [device(mouse, 90, .bluetooth, id: "ble-b034-3:255"),
             device(keyboard, 77, .bluetooth, id: "ble-b382-4:255")],
            [device(mouse, 89, .receiver, id: "usb-c548-5:2"), device(keyboard, 77, .receiver, id: "usb-c547-6:1")]
        ]
        let history = HistoryStore(directory: directory)
        let snapshots = SnapshotStore(directory: directory)
        var tick = 0
        let viewModel = DeviceListViewModel(scanner: ScriptedScanner(steps)) { devices in
            let now = self.start.addingTimeInterval(Double(tick) * 300)
            try? history.record(devices, at: now)
            try? snapshots.write(devices, at: now)
        }

        for (index, step) in steps.enumerated() {
            tick = index
            await viewModel.refresh()
            XCTAssertEqual(viewModel.devices.count, 2)
            XCTAssertEqual(viewModel.devices.map(\.path), step.sorted { $0.percent! < $1.percent! }.map(\.path))
            XCTAssertEqual(viewModel.menuBarPercent, step.compactMap(\.percent).min())
            XCTAssertEqual(snapshots.read()?.devices, viewModel.devices)
        }

        let series = HistorySeries.build(history.points(since: .distantPast), period: .day,
                                         now: start.addingTimeInterval(3600))
        XCTAssertEqual(series.map(\.deviceName), ["MX Master 3S", "PRO X TKL"])
        XCTAssertEqual(series[0].points.map(\.percent), [90, 89])
        XCTAssertEqual(series[1].points.map(\.percent), [78, 77])
    }

    func testHistoryMergesPointsRecordedUnderOlderIds() {
        let points = ["usb-c548-1:2", "ble-b034-3:255", "usb-c548-5:2"].enumerated().map { index, id in
            HistoryPoint(deviceId: id, deviceName: "MX Master 3S", percent: 90 - index, chargeState: .discharging,
                         timestamp: start.addingTimeInterval(Double(index) * 60))
        }
        XCTAssertEqual(HistorySeries.build(points, period: .day, now: start.addingTimeInterval(600)).count, 1)
    }

    func testSwitchingPathDoesNotDuplicateUnchangedHistoryPoint() throws {
        let history = HistoryStore(directory: directory)
        try history.record([device("PRO X TKL", 78, .receiver, id: "usb-c547-2:1")], at: start)
        let moved = device("PRO X TKL", 78, .bluetooth, id: "ble-b382-4:255")
        try history.record([moved], at: start.addingTimeInterval(60))
        XCTAssertEqual(history.points(since: .distantPast).count, 1)
    }

    func testAlertStateSurvivesConnectionSwitch() {
        var rule = LowBatteryRule()
        XCTAssertEqual(rule.evaluate([device("PRO X TKL", 15, .receiver, id: "usb-1")]).count, 1)
        XCTAssertEqual(rule.evaluate([device("PRO X TKL", 15, .bluetooth, id: "ble-2")]), [])
    }
}

private final class ScriptedScanner: DeviceScanning, @unchecked Sendable {
    private let lock = NSLock()
    private var steps: [[Device]]

    init(_ steps: [[Device]]) {
        self.steps = steps
    }

    func scan() async -> [Device] {
        lock.withLock { steps.isEmpty ? [] : steps.removeFirst() }
    }
}
