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

    private func device(_ id: String, _ percent: Int?, _ state: ChargeState = .discharging,
                        minutes: Double = 0) -> Device {
        Device(id: id, name: "Device \(id)", kind: .mouse, percent: percent, chargeState: state, path: .bluetooth,
               readAt: start.addingTimeInterval(minutes * 60))
    }

    /// Grava como o app: o instante da gravação é o da leitura.
    private func record(_ store: HistoryStore, _ devices: [Device]) throws {
        try store.record(devices, at: devices.map(\.readAt).max() ?? start)
    }

    func testRecordsFirstReadingAndSkipsUnchangedOnesWithinInterval() throws {
        let store = HistoryStore(directory: directory)
        try record(store, [device("a", 80)])
        try record(store, [device("a", 80, minutes: 5)])
        XCTAssertEqual(store.points(since: .distantPast).count, 1)
    }

    func testRecordsOnPercentOrChargeStateChange() throws {
        let store = HistoryStore(directory: directory)
        try record(store, [device("a", 80)])
        try record(store, [device("a", 79, minutes: 5)])
        try record(store, [device("a", 79, .charging, minutes: 10)])
        XCTAssertEqual(store.points(since: .distantPast).map(\.percent), [80, 79, 79])
    }

    func testRecordsUnchangedReadingAfterHalfAnHour() throws {
        let store = HistoryStore(directory: directory)
        try record(store, [device("a", 80)])
        try record(store, [device("a", 80, minutes: 31)])
        XCTAssertEqual(store.points(since: .distantPast).count, 2)
    }

    /// Aparelho dormindo segue na lista com a leitura antiga; ela não vira ponto novo no histórico.
    func testKeptReadingOfSleepingDeviceIsNotRecordedAgain() throws {
        let store = HistoryStore(directory: directory)
        try record(store, [device("a", 80), device("b", 60)])
        try record(store, [device("a", 80), device("b", 59, minutes: 10)])
        try store.record([device("a", 80), device("b", 59, minutes: 10)], at: start.addingTimeInterval(40 * 60))
        XCTAssertEqual(store.points(since: .distantPast).map(\.percent), [80, 60, 59])
        XCTAssertEqual(store.points(since: .distantPast).map(\.timestamp).max(), start.addingTimeInterval(600))
    }

    func testIgnoresDevicesWithoutPercentAndKeepsDevicesSeparate() throws {
        let store = HistoryStore(directory: directory)
        try record(store, [device("a", nil), device("b", 50), device("c", 60)])
        XCTAssertEqual(Set(store.points(since: .distantPast).map(\.deviceId)), ["b", "c"])
    }

    func testPointsSinceFiltersByTime() throws {
        let store = HistoryStore(directory: directory)
        try record(store, [device("a", 80)])
        try record(store, [device("a", 70, minutes: 60)])
        XCTAssertEqual(store.points(since: start.addingTimeInterval(1800)).map(\.percent), [70])
    }

    func testCorruptFileReadsAsEmptyAndIsReplacedOnNextRecord() throws {
        try Data("oops".utf8).write(to: directory.appendingPathComponent("history.json"))
        let store = HistoryStore(directory: directory)
        XCTAssertEqual(store.points(since: .distantPast), [])
        try record(store, [device("a", 80)])
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
        func record(_ percent: Int, daysAgo: Double) throws {
            let readAt = now.addingTimeInterval(-daysAgo * 86_400)
            try store.record([Device(id: "a", name: "A", kind: .mouse, percent: percent, chargeState: .discharging,
                                     path: .receiver, readAt: readAt)], at: readAt)
        }
        try record(90, daysAgo: 91)
        try record(80, daysAgo: 89)
        try record(70, daysAgo: 0)
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
