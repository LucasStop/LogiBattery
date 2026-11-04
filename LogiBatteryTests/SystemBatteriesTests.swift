import XCTest
@testable import LogiBattery

/// Bateria do Mac (dicionário do `IOPSGetPowerSourceDescription`, valores gravados num MacBook) e do fone Bluetooth.
final class SystemBatteriesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func battery(_ current: Int, charging: Bool = false, charged: Bool = false) -> [String: Any] {
        ["Type": "InternalBattery", "Name": "InternalBattery-0", "Current Capacity": current, "Max Capacity": 100,
         "Is Charging": charging, "Is Charged": charged, "Power Source State": "AC Power", "Is Present": true]
    }

    func testMacOnACNotChargingReadsPercentAsDischarging() throws {
        let mac = try XCTUnwrap(SystemBatteries.mac(description: battery(90), name: "MacBook", now: now))
        XCTAssertEqual(mac.name, "MacBook")
        XCTAssertEqual(mac.kind, .laptop)
        XCTAssertEqual(mac.path, .internal)
        XCTAssertEqual(mac.percent, 90)
        XCTAssertEqual(mac.chargeState, .discharging)
        XCTAssertEqual(mac.readAt, now)
    }

    func testMacChargingAndCharged() {
        XCTAssertEqual(SystemBatteries.mac(description: battery(40, charging: true), name: "M", now: now)?.chargeState,
                       .charging)
        XCTAssertEqual(SystemBatteries.mac(description: battery(100, charged: true), name: "M", now: now)?.chargeState,
                       .full)
    }

    func testMacPercentScalesByMaxCapacity() {
        var description = battery(2_000)
        description["Max Capacity"] = 4_000
        XCTAssertEqual(SystemBatteries.mac(description: description, name: "M", now: now)?.percent, 50)
    }

    func testUPSOrMissingCapacityIsNotAMac() {
        var ups = battery(50)
        ups["Type"] = "UPS"
        XCTAssertNil(SystemBatteries.mac(description: ups, name: "M", now: now))
        XCTAssertNil(SystemBatteries.mac(description: ["Type": "InternalBattery"], name: "M", now: now))
    }

    func testHeadsetUsesSingleLevel() {
        let headset = SystemBatteries.headset(name: "QCY MeloBuds Pro", single: 100, combined: 0, buds: [0, 0],
                                              now: now)
        XCTAssertEqual(headset.kind, .headphones)
        XCTAssertEqual(headset.path, .bluetooth)
        XCTAssertEqual(headset.percent, 100)
        XCTAssertEqual(headset.chargeState, .unknown)
    }

    func testEarbudsWithoutSingleUseLowestBud() {
        XCTAssertEqual(SystemBatteries.headset(name: "AirPods", single: 0, combined: 0, buds: [80, 60],
                                               now: now).percent, 60)
        XCTAssertEqual(SystemBatteries.headset(name: "AirPods", single: 0, combined: 0, buds: [0, 70],
                                               now: now).percent, 70)
        XCTAssertEqual(SystemBatteries.headset(name: "AirPods", single: 0, combined: 55, buds: [80, 60],
                                               now: now).percent, 55)
    }

    /// Fone conectado que o IOBluetooth devolve sem nível (issue #70) continua na lista, sem percentual.
    func testConnectedHeadsetWithoutAnyLevelStaysWithUnknownPercent() {
        let headset = SystemBatteries.headset(name: "X", single: 0, combined: 0, buds: [0, 0], now: now)
        XCTAssertEqual(headset.kind, .headphones)
        XCTAssertNil(headset.percent)
        XCTAssertEqual(headset.id, "bt-audio-X")
    }

    func testParseLevelsFromChildOutput() {
        let levels = SystemBatteries.parseLevels("QCY MeloBuds Pro - Lucas\t100\nMX Master 3S\t85\nruído\n")
        XCTAssertEqual(levels, ["QCY MeloBuds Pro - Lucas": 100, "MX Master 3S": 85])
    }

    func testHIDBluetoothKeyboardAndMouseFromIORegistry() throws {
        let keyboard = try XCTUnwrap(SystemBatteries.hidBluetoothDevice(properties: [
            "Transport": "Bluetooth Low Energy",
            "Product": "Keychron K2",
            "BatteryPercent": 74,
            "PrimaryUsagePage": 0x01,
            "PrimaryUsage": 0x06
        ], now: now))
        XCTAssertEqual(keyboard.name, "Keychron K2")
        XCTAssertEqual(keyboard.kind, .keyboard)
        XCTAssertEqual(keyboard.percent, 74)
        XCTAssertEqual(keyboard.chargeState, .discharging)
        XCTAssertEqual(keyboard.path, .bluetooth)

        let trackpad = try XCTUnwrap(SystemBatteries.hidBluetoothDevice(properties: [
            "Transport": "Bluetooth",
            "Product": "Magic Trackpad",
            "BatteryPercent": 58,
            "IsCharging": true,
            "DeviceUsagePairs": [["DeviceUsagePage": 0x0D, "DeviceUsage": 0x05]]
        ], now: now))
        XCTAssertEqual(trackpad.kind, .mouse)
        XCTAssertEqual(trackpad.chargeState, .charging)

        XCTAssertNil(SystemBatteries.hidBluetoothDevice(properties: [
            "Transport": "USB",
            "Product": "Wired Mouse",
            "BatteryPercent": 100
        ], now: now))
    }

    func testBluetoothPeripheralFromIOBluetoothClass() throws {
        let mouse = try XCTUnwrap(SystemBatteries.bluetoothDevice(
            name: "Magic Mouse", major: 0x05, minor: 0x20,
            levels: [82], now: now))
        XCTAssertEqual(mouse.kind, .mouse)
        XCTAssertEqual(mouse.percent, 82)

        XCTAssertNil(SystemBatteries.bluetoothDevice(
            name: "Magic Mouse", major: 0x05, minor: 0x20,
            levels: [], now: now))
    }

    /// #116 (B7): o processo filho que lê o nível do fone levava até 5 s dentro do `@MainActor`. Agora a espera é
    /// assíncrona: a main segue girando enquanto o processo roda.
    @MainActor
    func testChildProcessDoesNotBlockTheMainActor() async {
        let start = ContinuousClock.now
        let running = Task {
            await SystemBatteries.runLevels(executable: URL(fileURLWithPath: "/bin/sh"),
                                            arguments: ["-c", "sleep 1; printf 'Fone\\t42\\n'"], timeout: 5)
        }
        for _ in 0..<5 { try? await Task.sleep(for: .milliseconds(20)) }
        let mainWasFree = ContinuousClock.now - start
        let output = await running.value
        XCTAssertLessThan(mainWasFree, .milliseconds(600))
        XCTAssertEqual(SystemBatteries.parseLevels(output), ["Fone": 42])
    }

    func testChildProcessIsTerminatedAfterTheTimeout() async {
        let start = ContinuousClock.now
        let output = await SystemBatteries.runLevels(executable: URL(fileURLWithPath: "/bin/sleep"),
                                                     arguments: ["30"], timeout: 0.3)
        XCTAssertEqual(output, "")
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(5))
    }

    func testChildProcessThatCannotStartReturnsEmpty() async {
        let output = await SystemBatteries.runLevels(executable: URL(fileURLWithPath: "/nonexistent/levels"),
                                                     arguments: [], timeout: 1)
        XCTAssertEqual(output, "")
    }
}
