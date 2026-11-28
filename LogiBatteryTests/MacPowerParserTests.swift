import XCTest
@testable import LogiBattery

final class MacPowerParserTests: XCTestCase {
    func testParsesPowerAdapterFullyCharged() {
        let description: [String: Any] = [
            "Type": "InternalBattery",
            "Power Source State": "AC Power",
            "Is Charging": false,
            "Is Charged": true,
            "Time to Full Charge": 0,
            "Time to Empty": 0
        ]
        let parsed = MacPowerSnapshot.parsePowerSource(description: description)
        XCTAssertEqual(parsed?.0, .powerAdapter)
        XCTAssertEqual(parsed?.1, .fullyCharged)
    }

    func testParsesPowerAdapterChargingWithTimeUntilFull() {
        let description: [String: Any] = [
            "Type": "InternalBattery",
            "Power Source State": "AC Power",
            "Is Charging": true,
            "Is Charged": false,
            "Time to Full Charge": 75
        ]
        let parsed = MacPowerSnapshot.parsePowerSource(description: description)
        XCTAssertEqual(parsed?.0, .powerAdapter)
        XCTAssertEqual(parsed?.1, .charging(minutesUntilFull: 75))
    }

    func testParsesPowerAdapterNotChargingOnHold() {
        let description: [String: Any] = [
            "Type": "InternalBattery",
            "Power Source State": "AC Power",
            "Is Charging": false,
            "Is Charged": false
        ]
        let parsed = MacPowerSnapshot.parsePowerSource(description: description)
        XCTAssertEqual(parsed?.0, .powerAdapter)
        XCTAssertEqual(parsed?.1, .notCharging)
    }

    func testParsesBatteryDischargingWithRemainingTime() {
        let description: [String: Any] = [
            "Type": "InternalBattery",
            "Power Source State": "Battery Power",
            "Is Charging": false,
            "Is Charged": false,
            "Time to Empty": 402
        ]
        let parsed = MacPowerSnapshot.parsePowerSource(description: description)
        XCTAssertEqual(parsed?.0, .battery)
        XCTAssertEqual(parsed?.1, .discharging(minutesRemaining: 402))
        XCTAssertEqual(MacPowerSnapshot.formattedDuration(minutes: 402), "6:42")
    }

    func testParsesBatteryCalculatingTimeWhenNegative() {
        let description: [String: Any] = [
            "Type": "InternalBattery",
            "Power Source State": "Battery Power",
            "Is Charging": false,
            "Is Charged": false,
            "Time to Empty": -1
        ]
        let parsed = MacPowerSnapshot.parsePowerSource(description: description)
        XCTAssertEqual(parsed?.0, .battery)
        XCTAssertEqual(parsed?.1, .discharging(minutesRemaining: nil))
    }

    func testIgnoresNonInternalPowerSources() {
        let description: [String: Any] = [
            "Type": "UPS",
            "Power Source State": "AC Power"
        ]
        XCTAssertNil(MacPowerSnapshot.parsePowerSource(description: description))
    }

    func testParsesPmsetWithPowerModeAndHighPowerSupport() {
        let pmset = """
        Currently in use:
         standby              1
         powermode            2
         womp                 1
        """
        let custom = """
        Battery Power:
         powermode            1
        AC Power:
         powermode            2
        """
        let parsed = EnergyMode.parse(pmsetOutput: pmset, customOutput: custom)
        XCTAssertEqual(parsed?.current, .highPower)
        XCTAssertEqual(parsed?.supportsHighPower, true)
    }

    func testParsesPmsetWithLowPowerModeOnly() {
        let pmset = """
        Currently in use:
         standby              1
         lowpowermode         1
        """
        let custom = """
        Battery Power:
         lowpowermode         1
        AC Power:
         lowpowermode         0
        """
        let parsed = EnergyMode.parse(pmsetOutput: pmset, customOutput: custom)
        XCTAssertEqual(parsed?.current, .lowPower)
        XCTAssertEqual(parsed?.supportsHighPower, false)
    }

    func testProcessEnergyCalculatorRanksByCPUAndFiltersThreshold() {
        let previous: [Int32: ProcessEnergySample] = [
            10: ProcessEnergySample(pid: 10, name: "IdleApp", bundleIdentifier: "com.idle",
                                    cpuTimeNs: 1_000_000_000, wakeups: 10),
            20: ProcessEnergySample(pid: 20, name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
                                    cpuTimeNs: 5_000_000_000, wakeups: 100),
            30: ProcessEnergySample(pid: 30, name: "Chrome", bundleIdentifier: "com.google.Chrome",
                                    cpuTimeNs: 2_000_000_000, wakeups: 50)
        ]
        // Em 2 segundos: IdleApp usa 2% CPU; Xcode usa 80% CPU; Chrome usa 30% CPU.
        let current: [ProcessEnergySample] = [
            ProcessEnergySample(pid: 10, name: "IdleApp", bundleIdentifier: "com.idle",
                                cpuTimeNs: 1_040_000_000, wakeups: 12),
            ProcessEnergySample(pid: 20, name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
                                cpuTimeNs: 6_600_000_000, wakeups: 500),
            ProcessEnergySample(pid: 30, name: "Chrome", bundleIdentifier: "com.google.Chrome",
                                cpuTimeNs: 2_600_000_000, wakeups: 150)
        ]
        let items = ProcessEnergyCalculator.significantApps(
            previous: previous,
            current: current,
            elapsedSeconds: 2.0
        )
        XCTAssertEqual(items.count, 2)
        guard case .app(let firstPid, let firstName, _, _) = items[0],
              case .app(let secondPid, let secondName, _, _) = items[1] else {
            return XCTFail("Expected two app items")
        }
        XCTAssertEqual(firstPid, 20)
        XCTAssertEqual(firstName, "Xcode")
        XCTAssertEqual(secondPid, 30)
        XCTAssertEqual(secondName, "Chrome")
    }
}
