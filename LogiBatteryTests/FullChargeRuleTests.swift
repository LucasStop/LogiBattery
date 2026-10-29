import XCTest
@testable import LogiBattery

final class FullChargeRuleTests: XCTestCase {
    private func device(_ state: ChargeState, id: String = "a", percent: Int? = 100) -> Device {
        Device(id: id, name: "Device \(id)", kind: .keyboard, percent: percent, chargeState: state, path: .receiver,
               readAt: Date(timeIntervalSince1970: 0))
    }

    func testAlertsWhenChargingBecomesFull() {
        var rule = FullChargeRule()
        XCTAssertEqual(rule.evaluate([device(.charging, percent: 90)]), [])
        let alerts = rule.evaluate([device(.full)])
        XCTAssertEqual(alerts, [BatteryAlert(deviceName: "Device a", percent: 100, severity: .full)])
    }

    func testAlertsOnlyOncePerCycleEvenIfStateFlapsBetweenFullAndCharging() {
        var rule = FullChargeRule()
        _ = rule.evaluate([device(.charging, percent: 99)])
        XCTAssertEqual(rule.evaluate([device(.full)]).count, 1)
        XCTAssertEqual(rule.evaluate([device(.full)]), [])
        XCTAssertEqual(rule.evaluate([device(.charging, percent: 99)]), [])
        XCTAssertEqual(rule.evaluate([device(.full)]), [])
    }

    func testNewCycleAfterDischargingAlertsAgain() {
        var rule = FullChargeRule()
        _ = rule.evaluate([device(.charging, percent: 99)])
        _ = rule.evaluate([device(.full)])
        _ = rule.evaluate([device(.discharging, percent: 95)])
        _ = rule.evaluate([device(.charging, percent: 96)])
        XCTAssertEqual(rule.evaluate([device(.full)]).count, 1)
    }

    func testAlreadyFullAtLaunchDoesNotAlert() {
        var rule = FullChargeRule()
        XCTAssertEqual(rule.evaluate([device(.full)]), [])
    }

    func testDevicesAreIndependent() {
        var rule = FullChargeRule()
        _ = rule.evaluate([device(.charging, id: "a", percent: 99), device(.charging, id: "b", percent: 50)])
        let alerts = rule.evaluate([device(.full, id: "a"), device(.charging, id: "b", percent: 51)])
        XCTAssertEqual(alerts.map(\.deviceName), ["Device a"])
    }
}
