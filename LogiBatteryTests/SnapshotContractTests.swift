import XCTest
@testable import LogiBattery

final class SnapshotContractTests: XCTestCase {
    private var directory: URL!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func device(_ id: String, percent: Int?, state: ChargeState = .discharging) -> Device {
        Device(id: id, name: "Device \(id)", kind: .mouse, percent: percent, chargeState: state,
               path: .bluetooth, readAt: now)
    }

    func testWriteThenReadRoundTrips() throws {
        let store = SnapshotStore(directory: directory)
        try store.write([device("a", percent: 18), device("b", percent: nil, state: .charging)], at: now)
        let snapshot = try XCTUnwrap(store.read())
        XCTAssertEqual(snapshot.devices.map(\.id), ["a", "b"])
        XCTAssertEqual(snapshot.devices[0].percent, 18)
        XCTAssertEqual(snapshot.devices[1].chargeState, .charging)
        XCTAssertEqual(snapshot.generatedAt, now)
    }

    /// Contrato de docs/API.md: o widget depende destes nomes de campo.
    func testJSONFieldNamesMatchContract() throws {
        let store = SnapshotStore(directory: directory)
        try store.write([device("a", percent: 50)], at: now)
        let data = try Data(contentsOf: directory.appendingPathComponent("snapshot.json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["schemaVersion"] as? Int, 1)
        XCTAssertNotNil(root["generatedAt"] as? String)
        let entry = try XCTUnwrap((root["devices"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(entry.keys), ["id", "name", "kind", "percent", "chargeState", "path", "updatedAt"])
        XCTAssertEqual(entry["kind"] as? String, "mouse")
        XCTAssertEqual(entry["chargeState"] as? String, "discharging")
        XCTAssertEqual(entry["path"] as? String, "bluetooth")
    }

    func testWriteReplacesPreviousSnapshot() throws {
        let store = SnapshotStore(directory: directory)
        try store.write([device("a", percent: 10)], at: now)
        try store.write([device("b", percent: 20)], at: now)
        XCTAssertEqual(store.read()?.devices.map(\.id), ["b"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["snapshot.json"])
    }

    func testMissingCorruptOrFutureVersionReadsAsNil() throws {
        let store = SnapshotStore(directory: directory)
        XCTAssertNil(store.read())
        let file = directory.appendingPathComponent("snapshot.json")
        try Data("{ not json".utf8).write(to: file)
        XCTAssertNil(store.read())
        try Data(#"{"schemaVersion":99,"generatedAt":"2027-01-01T00:00:00Z","devices":[]}"#.utf8).write(to: file)
        XCTAssertNil(store.read())
    }

    func testStaleAfterThirtyMinutes() throws {
        let store = SnapshotStore(directory: directory)
        try store.write([device("a", percent: 50)], at: now)
        let snapshot = try XCTUnwrap(store.read())
        XCTAssertFalse(snapshot.isStale(at: now.addingTimeInterval(29 * 60)))
        XCTAssertTrue(snapshot.isStale(at: now.addingTimeInterval(31 * 60)))
    }

    func testBatteryLevelThresholds() {
        XCTAssertEqual(BatteryLevel(percent: 50), .normal)
        XCTAssertEqual(BatteryLevel(percent: 20), .normal)
        XCTAssertEqual(BatteryLevel(percent: 19), .low)
        XCTAssertEqual(BatteryLevel(percent: 10), .low)
        XCTAssertEqual(BatteryLevel(percent: 9), .critical)
        XCTAssertEqual(BatteryLevel(percent: nil), .unknown)
    }

    func testWidgetOrderPutsLowestFirstAndUnknownLast() throws {
        let devices = [device("a", percent: 80), device("b", percent: nil), device("c", percent: 7)]
        let ordered = Snapshot.widgetOrder(devices)
        XCTAssertEqual(ordered.map(\.id), ["c", "a", "b"])
    }
}
