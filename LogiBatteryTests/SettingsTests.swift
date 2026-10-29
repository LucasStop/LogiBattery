import XCTest
@testable import LogiBattery

@MainActor
final class SettingsTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "LogiBatteryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testDefaultsMatchPRD() {
        let settings = AppSettings()
        XCTAssertEqual(settings.lowThreshold, 20)
        XCTAssertEqual(settings.criticalThreshold, 10)
        XCTAssertTrue(settings.fullChargeAlert)
        XCTAssertEqual(settings.intervalMinutes, 5)
    }

    func testChangesPersistAcrossRestart() {
        let defaults = defaults()
        let model = SettingsModel(defaults: defaults)
        model.values.lowThreshold = 30
        model.values.intervalMinutes = 15
        model.values.fullChargeAlert = false
        let reopened = SettingsModel(defaults: defaults)
        XCTAssertEqual(reopened.values.lowThreshold, 30)
        XCTAssertEqual(reopened.values.intervalMinutes, 15)
        XCTAssertFalse(reopened.values.fullChargeAlert)
    }

    func testCriticalStaysBelowLowAndValuesStayInRange() {
        var settings = AppSettings(lowThreshold: 20, criticalThreshold: 10, fullChargeAlert: true, intervalMinutes: 5)
        settings.criticalThreshold = 25
        XCTAssertEqual(settings.normalized().criticalThreshold, 19)
        settings = AppSettings(lowThreshold: 8, criticalThreshold: 10, fullChargeAlert: true, intervalMinutes: 5)
        XCTAssertEqual(settings.normalized().lowThreshold, 8)
        XCTAssertEqual(settings.normalized().criticalThreshold, 7)
        settings = AppSettings(lowThreshold: 90, criticalThreshold: 0, fullChargeAlert: true, intervalMinutes: 0)
        let normalized = settings.normalized()
        XCTAssertEqual(normalized.lowThreshold, 50)
        XCTAssertEqual(normalized.criticalThreshold, 1)
        XCTAssertEqual(normalized.intervalMinutes, 1)
    }

    func testCorruptStoredValueFallsBackToDefaults() {
        let defaults = defaults()
        defaults.set(Data("oops".utf8), forKey: "settings")
        XCTAssertEqual(SettingsModel(defaults: defaults).values, AppSettings())
    }

    func testSettingsAreAppliedOnNextReading() {
        let notifier = SettingsRecordingNotifier()
        let model = SettingsModel(defaults: defaults())
        let coordinator = AlertCoordinator(notifier: notifier, settings: model)
        let mouse = Device(id: "m", name: "MX", kind: .mouse, percent: 25, chargeState: .discharging,
                           path: .receiver, readAt: .now)
        coordinator.handle([mouse])
        XCTAssertEqual(notifier.alerts, [])
        model.values.lowThreshold = 30
        coordinator.handle([mouse])
        XCTAssertEqual(notifier.alerts.map(\.severity), [.low])
    }

    func testFullChargeAlertCanBeSwitchedOff() {
        let notifier = SettingsRecordingNotifier()
        let model = SettingsModel(defaults: defaults())
        model.values.fullChargeAlert = false
        let coordinator = AlertCoordinator(notifier: notifier, settings: model)
        func keyboard(_ state: ChargeState) -> Device {
            Device(id: "k", name: "K", kind: .keyboard, percent: 100, chargeState: state, path: .receiver, readAt: .now)
        }
        coordinator.handle([keyboard(.charging)])
        coordinator.handle([keyboard(.full)])
        XCTAssertEqual(notifier.alerts, [])
    }

    func testPollIntervalFollowsSettings() {
        let model = SettingsModel(defaults: defaults())
        XCTAssertEqual(model.values.interval, .seconds(300))
        model.values.intervalMinutes = 10
        XCTAssertEqual(model.values.interval, .seconds(600))
    }

    func testDeleteAllHistoryEmptiesStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let device = Device(id: "a", name: "A", kind: .mouse, percent: 50, chargeState: .discharging,
                            path: .receiver, readAt: .now)
        try store.record([device], at: .now)
        try store.deleteAll()
        XCTAssertEqual(store.points(since: .distantPast), [])
    }
}

private final class SettingsRecordingNotifier: AlertNotifying {
    var alerts: [BatteryAlert] = []
    func notify(_ alert: BatteryAlert) { alerts.append(alert) }
}
