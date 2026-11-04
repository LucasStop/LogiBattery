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

    /// #116 (B1): com intervalo de 45 min o próximo snapshot só chega em 45 min; "app parado" espera duas leituras.
    func testStaleAfterTwoReadingsWhenTheIntervalIsLong() throws {
        let store = SnapshotStore(directory: directory)
        try store.write([device("a", percent: 50)], at: now, intervalMinutes: 45)
        let snapshot = try XCTUnwrap(store.read())
        XCTAssertEqual(snapshot.intervalMinutes, 45)
        XCTAssertFalse(snapshot.isStale(at: now.addingTimeInterval(80 * 60)))
        XCTAssertTrue(snapshot.isStale(at: now.addingTimeInterval(91 * 60)))
        XCTAssertFalse(snapshot.showsGray(device("a", percent: 50), at: now.addingTimeInterval(80 * 60)))
    }

    func testShortIntervalKeepsTheThirtyMinuteFloorAndOldSnapshotHasNoInterval() throws {
        let store = SnapshotStore(directory: directory)
        try store.write([device("a", percent: 50)], at: now, intervalMinutes: 5)
        XCTAssertFalse(try XCTUnwrap(store.read()).isStale(at: now.addingTimeInterval(29 * 60)))
        XCTAssertTrue(try XCTUnwrap(store.read()).isStale(at: now.addingTimeInterval(31 * 60)))
        let old = #"{"schemaVersion":1,"generatedAt":"2027-01-15T08:00:00Z","devices":[]}"#
        try Data(old.utf8).write(to: directory.appendingPathComponent("snapshot.json"))
        XCTAssertNil(try XCTUnwrap(store.read()).intervalMinutes)
    }

    func testBatteryLevelThresholds() {
        XCTAssertEqual(BatteryLevel(percent: 50), .normal)
        XCTAssertEqual(BatteryLevel(percent: 20), .normal)
        XCTAssertEqual(BatteryLevel(percent: 19), .low)
        XCTAssertEqual(BatteryLevel(percent: 10), .low)
        XCTAssertEqual(BatteryLevel(percent: 9), .critical)
        XCTAssertEqual(BatteryLevel(percent: nil), .unknown)
    }

    func testBatteryLevelFollowsConfiguredThresholds() {
        let thresholds = BatteryThresholds(low: 30, critical: 15)
        XCTAssertEqual(BatteryLevel(percent: 25, thresholds: thresholds), .low)
        XCTAssertEqual(BatteryLevel(percent: 14, thresholds: thresholds), .critical)
        XCTAssertEqual(BatteryLevel(percent: 30, thresholds: thresholds), .normal)
        XCTAssertEqual(AppSettings(lowThreshold: 30, criticalThreshold: 15).thresholds, thresholds)
    }

    func testThresholdsRoundTripAndOldSnapshotFallsBackToDefaults() throws {
        let store = SnapshotStore(directory: directory)
        try store.write([device("a", percent: 25)], at: now, thresholds: BatteryThresholds(low: 30, critical: 15))
        XCTAssertEqual(store.read()?.thresholds, BatteryThresholds(low: 30, critical: 15))
        let old = #"{"schemaVersion":1,"generatedAt":"2027-01-15T08:00:00Z","devices":[]}"#
        try Data(old.utf8).write(to: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(try XCTUnwrap(store.read()).levelThresholds, BatteryThresholds())
    }

    func testWidgetOrderPutsLowestFirstAndUnknownLast() throws {
        let devices = [device("a", percent: 80), device("b", percent: nil), device("c", percent: 7)]
        let ordered = Snapshot.widgetOrder(devices, scanAt: now)
        XCTAssertEqual(ordered.map(\.id), ["c", "a", "b"])
    }

    /// Como no widget da Apple, o Mac ocupa a primeira posição; o resto segue do menor nível para o maior.
    func testWidgetOrderPutsMacFirst() {
        let mac = Device(id: "mac", name: "MacBook", kind: .laptop, percent: 90, chargeState: .discharging,
                         path: .internal, readAt: now)
        let ordered = Snapshot.widgetOrder([device("a", percent: 80), mac, device("c", percent: 7)], scanAt: now)
        XCTAssertEqual(ordered.map(\.id), ["mac", "c", "a"])
    }

    /// #100: aparelho que não respondeu ao último scan (leitura mais velha que o resto) vai para o fim, mesmo com
    /// nível menor.
    func testWidgetOrderPutsUnseenDevicesLast() {
        let stale = Device(id: "g305", name: "G305", kind: .mouse, percent: 10, chargeState: .discharging,
                           path: .receiver, readAt: now.addingTimeInterval(-27 * 60))
        let ordered = Snapshot.widgetOrder([stale, device("a", percent: 80), device("b", percent: 50)], scanAt: now)
        XCTAssertEqual(ordered.map(\.id), ["b", "a", "g305"])
    }

    func testMacAndHeadphonesRoundTrip() throws {
        let store = SnapshotStore(directory: directory)
        let mac = Device(id: "mac", name: "MacBook", kind: .laptop, percent: 90, chargeState: .charging,
                         path: .internal, readAt: now)
        let headset = Device(id: "bt", name: "QCY", kind: .headphones, percent: 100, chargeState: .unknown,
                             path: .bluetooth, readAt: now)
        try store.write([mac, headset], at: now)
        XCTAssertEqual(store.read()?.devices, [mac, headset])
    }
}

/// O widget só recarrega quando muda o que ele mostra: recarregar a cada leitura esgota o orçamento do WidgetKit.
final class WidgetReloadTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func device(_ name: String, _ percent: Int?, _ path: DevicePath = .receiver,
                        minutesAgo: Double = 0) -> Device {
        Device(id: UUID().uuidString, name: name, kind: .mouse, percent: percent, chargeState: .discharging,
               path: path, readAt: now.addingTimeInterval(-minutesAgo * 60))
    }

    func testNewReadingTimeAloneDoesNotReload() {
        let old = [device("MX Master 3S", 90, minutesAgo: 1), device("PRO X TKL", 77, minutesAgo: 5)]
        let new = [device("PRO X TKL", 77, minutesAgo: 5), device("MX Master 3S", 90)]
        XCTAssertFalse(Snapshot.meaningfullyDiffers(old, new, at: now))
    }

    func testPercentPathOrDeviceSetChangeReloads() {
        let old = [device("MX Master 3S", 90)]
        XCTAssertTrue(Snapshot.meaningfullyDiffers(old, [device("MX Master 3S", 89)], at: now))
        XCTAssertTrue(Snapshot.meaningfullyDiffers(old, [device("MX Master 3S", 90, .bluetooth)], at: now))
        XCTAssertTrue(Snapshot.meaningfullyDiffers(old, old + [device("PRO X TKL", 77)], at: now))
        XCTAssertTrue(Snapshot.meaningfullyDiffers(old, [], at: now))
    }

    func testOldReadingTurningFreshReloads() {
        let old = [device("PRO X TKL", 77, minutesAgo: 40)]
        XCTAssertTrue(Snapshot.meaningfullyDiffers(old, [device("PRO X TKL", 77)], at: now))
    }

    /// #116: o cinza vale para leitura mantida (não veio no último scan) e só depois de `grayAfter`.
    func testKeptReadingTurnsGrayAfterThirtyMinutes() {
        XCTAssertFalse(device("PRO X TKL", 77, minutesAgo: 29).isGray(at: now, scanAt: now))
        XCTAssertTrue(device("PRO X TKL", 77, minutesAgo: 31).isGray(at: now, scanAt: now))
    }
}
