import XCTest
@testable import LogiBattery

final class HistoryStoreTests: XCTestCase {
    private var directory: URL!
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func device(_ id: String, _ percent: Int?, _ state: ChargeState = .discharging) -> Device {
        Device(id: id, name: "Device \(id)", kind: .mouse, percent: percent, chargeState: state, path: .bluetooth,
               readAt: start)
    }

    func testRecordsFirstReadingAndSkipsUnchangedOnesWithinInterval() throws {
        let store = HistoryStore(directory: directory)
        try store.record([device("a", 80)], at: start)
        try store.record([device("a", 80)], at: start.addingTimeInterval(5 * 60))
        XCTAssertEqual(store.points(since: .distantPast).count, 1)
    }

    func testRecordsOnPercentOrChargeStateChange() throws {
        let store = HistoryStore(directory: directory)
        try store.record([device("a", 80)], at: start)
        try store.record([device("a", 79)], at: start.addingTimeInterval(300))
        try store.record([device("a", 79, .charging)], at: start.addingTimeInterval(600))
        XCTAssertEqual(store.points(since: .distantPast).map(\.percent), [80, 79, 79])
    }

    func testRecordsUnchangedReadingAfterHalfAnHour() throws {
        let store = HistoryStore(directory: directory)
        try store.record([device("a", 80)], at: start)
        try store.record([device("a", 80)], at: start.addingTimeInterval(31 * 60))
        XCTAssertEqual(store.points(since: .distantPast).count, 2)
    }

    func testIgnoresDevicesWithoutPercentAndKeepsDevicesSeparate() throws {
        let store = HistoryStore(directory: directory)
        try store.record([device("a", nil), device("b", 50), device("c", 60)], at: start)
        XCTAssertEqual(Set(store.points(since: .distantPast).map(\.deviceId)), ["b", "c"])
    }

    func testPointsSinceFiltersByTime() throws {
        let store = HistoryStore(directory: directory)
        try store.record([device("a", 80)], at: start)
        try store.record([device("a", 70)], at: start.addingTimeInterval(3600))
        XCTAssertEqual(store.points(since: start.addingTimeInterval(1800)).map(\.percent), [70])
    }

    func testCorruptFileReadsAsEmptyAndIsReplacedOnNextRecord() throws {
        try Data("oops".utf8).write(to: directory.appendingPathComponent("history.json"))
        let store = HistoryStore(directory: directory)
        XCTAssertEqual(store.points(since: .distantPast), [])
        try store.record([device("a", 80)], at: start)
        XCTAssertEqual(store.points(since: .distantPast).count, 1)
    }
}

final class HistoryRetentionTests: XCTestCase {
    func testRecordPrunesPointsOlderThanRetention() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = HistoryStore(directory: directory)
        func device(_ percent: Int) -> Device {
            Device(id: "a", name: "A", kind: .mouse, percent: percent, chargeState: .discharging, path: .receiver,
                   readAt: now)
        }
        try store.record([device(90)], at: now.addingTimeInterval(-91 * 86_400))
        try store.record([device(80)], at: now.addingTimeInterval(-89 * 86_400))
        try store.record([device(70)], at: now)
        XCTAssertEqual(store.points(since: .distantPast).map(\.percent), [80, 70])
    }
}

final class HistorySeriesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func point(_ id: String, _ percent: Int, hoursAgo: Double) -> HistoryPoint {
        HistoryPoint(deviceId: id, deviceName: "Device \(id)", percent: percent, chargeState: .discharging,
                     timestamp: now.addingTimeInterval(-hoursAgo * 3600))
    }

    func testPeriodWindows() {
        XCTAssertEqual(HistoryPeriod.day.interval, 86_400)
        XCTAssertEqual(HistoryPeriod.week.interval, 7 * 86_400)
        XCTAssertEqual(HistoryPeriod.month.interval, 30 * 86_400)
    }

    func testBuildsOneSeriesPerDeviceSortedByTimeWithinPeriod() {
        let points = [point("b", 50, hoursAgo: 1), point("a", 80, hoursAgo: 2), point("a", 70, hoursAgo: 10),
                      point("a", 90, hoursAgo: 30)]
        let series = HistorySeries.build(points, period: .day, now: now)
        XCTAssertEqual(series.map(\.deviceName), ["Device a", "Device b"])
        XCTAssertEqual(series[0].points.map(\.percent), [70, 80])
        XCTAssertEqual(series.map(\.index), [0, 1])
    }

    func testWeekIncludesOlderPointsAndEmptyWhenNothingInWindow() {
        let points = [point("a", 90, hoursAgo: 30)]
        XCTAssertEqual(HistorySeries.build(points, period: .week, now: now).count, 1)
        XCTAssertEqual(HistorySeries.build(points, period: .day, now: now), [])
    }
}
