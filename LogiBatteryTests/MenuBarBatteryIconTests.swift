import XCTest
@testable import LogiBattery

final class MenuBarBatteryIconTests: XCTestCase {
    func testNormalStateProducesFixedSizeTemplateImage() {
        let style = MenuBarBatteryIcon.Style(
            percent: 78,
            isCharging: false,
            isPluggedFull: false,
            isLowPowerMode: false,
            level: .normal,
            hasLoaded: true
        )
        let image = MenuBarBatteryIcon.image(for: style)
        XCTAssertEqual(image.size, MenuBarBatteryIcon.size)
        XCTAssertEqual(MenuBarBatteryIcon.size, NSSize(width: 29, height: 14))
        XCTAssertTrue(image.isTemplate)
    }

    func testColoredStatesDisableTemplateToPreserveAppleColors() {
        let cases: [MenuBarBatteryIcon.Style] = [
            .init(percent: 60, isCharging: false, isPluggedFull: false, isLowPowerMode: true,
                  level: .normal, hasLoaded: true),
            .init(percent: 18, isCharging: false, isPluggedFull: false, isLowPowerMode: false,
                  level: .low, hasLoaded: true),
            .init(percent: 8, isCharging: false, isPluggedFull: false, isLowPowerMode: false,
                  level: .critical, hasLoaded: true)
        ]
        for style in cases {
            let image = MenuBarBatteryIcon.image(for: style)
            XCTAssertEqual(image.size, MenuBarBatteryIcon.size)
            XCTAssertFalse(image.isTemplate)
        }
    }

    func testChargingAndPluggedFullStayMonochromeTemplateLikeNative() {
        let cases: [MenuBarBatteryIcon.Style] = [
            .init(percent: 82, isCharging: true, isPluggedFull: false, isLowPowerMode: false,
                  level: .normal, hasLoaded: true),
            .init(percent: 100, isCharging: false, isPluggedFull: true, isLowPowerMode: false,
                  level: .normal, hasLoaded: true)
        ]
        for style in cases {
            XCTAssertTrue(style.showsBolt)
            XCTAssertTrue(MenuBarBatteryIcon.image(for: style).isTemplate)
        }
    }

    func testLoadingAndMissingStatesKeepFixedSizeTemplate() {
        let loading = MenuBarBatteryIcon.Style(
            percent: nil, isCharging: false, isPluggedFull: false, isLowPowerMode: false,
            level: .unknown, hasLoaded: false
        )
        let missing = MenuBarBatteryIcon.Style(
            percent: nil, isCharging: false, isPluggedFull: false, isLowPowerMode: false,
            level: .unknown, hasLoaded: true
        )
        for style in [loading, missing] {
            let image = MenuBarBatteryIcon.image(for: style)
            XCTAssertEqual(image.size, MenuBarBatteryIcon.size)
            XCTAssertTrue(image.isTemplate)
        }
    }

    func testEnergyModeSymbolsMatchAppleSpec() {
        XCTAssertEqual(EnergyMode.automatic.symbolName, "battery.100percent")
        XCTAssertFalse(EnergyMode.automatic.isCustomSymbol)
        XCTAssertEqual(EnergyMode.lowPower.symbolName, "battery.25percent")
        XCTAssertFalse(EnergyMode.lowPower.isCustomSymbol)
        XCTAssertEqual(EnergyMode.highPower.symbolName, "lb.battery.highpower")
        XCTAssertTrue(EnergyMode.highPower.isCustomSymbol)
    }
}
