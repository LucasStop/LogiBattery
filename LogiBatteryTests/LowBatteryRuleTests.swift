import XCTest
@testable import LogiBattery

final class LowBatteryRuleTests: XCTestCase {
    private func device(_ percent: Int?, id: String = "a", state: ChargeState = .discharging) -> Device {
        Device(id: id, name: "Device \(id)", kind: .mouse, percent: percent, chargeState: state, path: .bluetooth,
               readAt: Date(timeIntervalSince1970: 0))
    }

    func testNoAlertAboveThreshold() {
        var rule = LowBatteryRule()
        XCTAssertEqual(rule.evaluate([device(50), device(20, id: "b")]), [])
    }

    func testAlertsOnceWhenDroppingBelowLowThreshold() {
        var rule = LowBatteryRule()
        let first = rule.evaluate([device(19)])
        XCTAssertEqual(first, [BatteryAlert(deviceName: "Device a", percent: 19, severity: .low)])
        XCTAssertEqual(rule.evaluate([device(18)]), [])
        XCTAssertEqual(rule.evaluate([device(12)]), [])
    }

    func testCriticalAlertsSeparatelyAfterLow() {
        var rule = LowBatteryRule()
        _ = rule.evaluate([device(15)])
        let alerts = rule.evaluate([device(9)])
        XCTAssertEqual(alerts, [BatteryAlert(deviceName: "Device a", percent: 9, severity: .critical)])
        XCTAssertEqual(rule.evaluate([device(8)]), [])
    }

    func testJumpingPastBothThresholdsAlertsOnceAsCritical() {
        var rule = LowBatteryRule()
        XCTAssertEqual(rule.evaluate([device(25)]), [])
        let alerts = rule.evaluate([device(8)])
        XCTAssertEqual(alerts, [BatteryAlert(deviceName: "Device a", percent: 8, severity: .critical)])
        XCTAssertEqual(rule.evaluate([device(7)]), [])
    }

    func testChargingDeviceDoesNotAlertAndStaysArmed() {
        var rule = LowBatteryRule()
        XCTAssertEqual(rule.evaluate([device(15, state: .charging)]), [])
        XCTAssertEqual(rule.evaluate([device(14)]).count, 1)
    }

    func testRearmsOnlyAfterRechargingAboveThreshold() {
        var rule = LowBatteryRule()
        _ = rule.evaluate([device(15)])
        XCTAssertEqual(rule.evaluate([device(19)]), [])
        XCTAssertEqual(rule.evaluate([device(17)]), [])
        XCTAssertEqual(rule.evaluate([device(60)]), [])
        XCTAssertEqual(rule.evaluate([device(19)]).count, 1)
    }

    func testDevicesAreIndependentAndMissingReadingIsIgnored() {
        var rule = LowBatteryRule()
        let alerts = rule.evaluate([device(15, id: "a"), device(15, id: "b"), device(nil, id: "c")])
        XCTAssertEqual(alerts.map(\.deviceName), ["Device a", "Device b"])
    }

    func testCustomThresholds() {
        var rule = LowBatteryRule(thresholds: [30])
        XCTAssertEqual(rule.evaluate([device(25)]), [BatteryAlert(deviceName: "Device a", percent: 25, severity: .low)])
    }
}

@MainActor
final class AlertCoordinatorTests: XCTestCase {
    func testCoordinatorAlsoSendsFullChargeAlerts() {
        let notifier = RecordingNotifier()
        let coordinator = AlertCoordinator(notifier: notifier)
        func keyboard(_ state: ChargeState, _ percent: Int) -> Device {
            Device(id: "k", name: "MX Keys", kind: .keyboard, percent: percent, chargeState: state, path: .receiver,
                   readAt: Date(timeIntervalSince1970: 0))
        }
        coordinator.handle([keyboard(.charging, 98)])
        coordinator.handle([keyboard(.full, 100)])
        XCTAssertEqual(notifier.alerts, [BatteryAlert(deviceName: "MX Keys", percent: 100, severity: .full)])
    }

    func testCoordinatorSendsRuleAlertsToNotifier() {
        let notifier = RecordingNotifier()
        let coordinator = AlertCoordinator(notifier: notifier)
        let device = Device(id: "a", name: "MX Master 3S", kind: .mouse, percent: 15, chargeState: .discharging,
                            path: .receiver, readAt: Date(timeIntervalSince1970: 0))
        coordinator.handle([device])
        coordinator.handle([device])
        XCTAssertEqual(notifier.alerts, [BatteryAlert(deviceName: "MX Master 3S", percent: 15, severity: .low)])
    }
}

private final class RecordingNotifier: AlertNotifying {
    var alerts: [BatteryAlert] = []
    func notify(_ alert: BatteryAlert) { alerts.append(alert) }
}
