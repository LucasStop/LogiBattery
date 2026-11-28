import XCTest
@testable import LogiBattery

private actor FakeMacPowerReader: MacPowerReading {
    var snapshot: MacPowerSnapshot?
    init(snapshot: MacPowerSnapshot?) { self.snapshot = snapshot }
    func setSnapshot(_ next: MacPowerSnapshot?) { snapshot = next }
    func read() async -> MacPowerSnapshot? { snapshot }
}

private final class FakePowerModeController: PowerModeControlling, @unchecked Sendable {
    var currentStatus: PowerHelperStatus
    var registerResult: PowerHelperStatus
    var appliedCalls: [(mode: EnergyMode, scope: String)] = []
    var revokeCount = 0

    init(status: PowerHelperStatus = .enabled, registerResult: PowerHelperStatus? = nil) {
        self.currentStatus = status
        self.registerResult = registerResult ?? status
    }

    func status() -> PowerHelperStatus { currentStatus }

    func register() throws -> PowerHelperStatus {
        currentStatus = registerResult
        return currentStatus
    }

    func setPowerMode(_ mode: EnergyMode, scope: String) async throws {
        appliedCalls.append((mode, scope))
    }

    func revoke() throws {
        revokeCount += 1
        currentStatus = .notRegistered
    }
}

private actor FakeSignificantEnergyReader: SignificantEnergyReading {
    var items: [SignificantEnergyItem]
    init(items: [SignificantEnergyItem] = []) { self.items = items }
    func sample() async -> [SignificantEnergyItem] { items }
    func reset() async {}
}

@MainActor
final class MacPowerViewModelTests: XCTestCase {
    func testSelectModeAppliesAdapterScopeWhenOnPowerAdapter() async {
        let initial = MacPowerSnapshot(
            powerSource: .powerAdapter,
            detail: .fullyCharged,
            energyMode: .automatic,
            supportsHighPower: true
        )
        let reader = FakeMacPowerReader(snapshot: initial)
        let controller = FakePowerModeController(status: .enabled)
        let significant = FakeSignificantEnergyReader(items: [.displayBrightness])
        let model = MacPowerViewModel(
            powerReader: reader,
            modeController: controller,
            significantReader: significant
        )

        await model.refresh()
        await reader.setSnapshot(MacPowerSnapshot(
            powerSource: .powerAdapter,
            detail: .fullyCharged,
            energyMode: .highPower,
            supportsHighPower: true
        ))
        await model.selectMode(.highPower)

        XCTAssertEqual(controller.appliedCalls.count, 1)
        XCTAssertEqual(controller.appliedCalls.first?.mode, .highPower)
        XCTAssertEqual(controller.appliedCalls.first?.scope, "-c")
        XCTAssertEqual(model.snapshot?.energyMode, .highPower)
    }

    func testSelectModeAppliesBatteryScopeWhenOnBattery() async {
        let initial = MacPowerSnapshot(
            powerSource: .battery,
            detail: .discharging(minutesRemaining: 300),
            energyMode: .automatic,
            supportsHighPower: false
        )
        let reader = FakeMacPowerReader(snapshot: initial)
        let controller = FakePowerModeController(status: .enabled)
        let model = MacPowerViewModel(
            powerReader: reader,
            modeController: controller,
            significantReader: FakeSignificantEnergyReader()
        )

        await model.refresh()
        await model.selectMode(.lowPower)

        XCTAssertEqual(controller.appliedCalls.first?.mode, .lowPower)
        XCTAssertEqual(controller.appliedCalls.first?.scope, "-b")
    }

    func testSelectModeStillSwitchesWithoutPasswordlessRule() async {
        let initial = MacPowerSnapshot(
            powerSource: .powerAdapter, detail: .fullyCharged, energyMode: .automatic, supportsHighPower: true
        )
        let controller = FakePowerModeController(status: .notRegistered)
        let model = MacPowerViewModel(
            powerReader: FakeMacPowerReader(snapshot: initial),
            modeController: controller,
            significantReader: FakeSignificantEnergyReader()
        )

        await model.refresh()
        await model.selectMode(.highPower)

        XCTAssertEqual(controller.appliedCalls.first?.mode, .highPower)
        XCTAssertEqual(model.helperStatus, .notRegistered)
    }

    func testEnableAndRevokePasswordlessUpdateStatus() async {
        let controller = FakePowerModeController(status: .notRegistered, registerResult: .enabled)
        let model = MacPowerViewModel(
            powerReader: FakeMacPowerReader(snapshot: nil),
            modeController: controller,
            significantReader: FakeSignificantEnergyReader()
        )

        model.enablePasswordless()
        XCTAssertEqual(model.helperStatus, .enabled)

        model.revokePasswordless()
        XCTAssertEqual(controller.revokeCount, 1)
        XCTAssertEqual(model.helperStatus, .notRegistered)
    }

    func testMenuBarSourceSwitchesBetweenLowestBatteryAndMacBattery() async {
        let devices = [
            Device(id: "mac-internal", name: "MacBook Pro", kind: .laptop, percent: 88,
                   chargeState: .charging, path: .internal, readAt: .now),
            Device(id: "mouse", name: "MX Master 3S", kind: .mouse, percent: 24,
                   chargeState: .discharging, path: .receiver, readAt: .now)
        ]
        let list = DeviceListViewModel(scanner: StubScanner(devices: devices))
        await list.refresh()

        XCTAssertEqual(list.menuBarPercent(for: .lowestBattery), 24)
        XCTAssertEqual(list.menuBarSymbol(for: .lowestBattery), "battery.25")
        XCTAssertEqual(list.menuBarPercent(for: .macBattery), 88)
        XCTAssertEqual(list.menuBarSymbol(for: .macBattery), "battery.100.bolt")
    }

    func testLegacyAppSettingsWithoutMenuBarSourceDefaultsToLowestBattery() throws {
        let legacyJSON = Data("""
        {"lowThreshold":20,"criticalThreshold":10,"fullChargeAlert":true,"intervalMinutes":1}
        """.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: legacyJSON)
        XCTAssertEqual(decoded.menuBarSource, .lowestBattery)
    }
}

private struct StubScanner: DeviceScanning {
    let devices: [Device]
    func scan() async -> [Device] { devices }
}
