import XCTest
@testable import LogiBattery

/// Smoke manual com receptor e aparelhos ligados: `LOGIBATTERY_HW=1 xcodebuild test ...`. Fora do CI.
final class HardwareSmokeTests: XCTestCase {
    func testReadsRealDevicesFromReceivers() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LOGIBATTERY_HW"] == "1", "sem hardware")
        let discovery = ReceiverDiscovery()
        let devices = await ReceiverScanner(receivers: discovery.receivers()).scan()
        print("HW devices: \(devices.map { "\($0.name) \($0.percent ?? -1)%" })")
        XCTAssertFalse(devices.isEmpty)
        XCTAssertTrue(devices.allSatisfy { ($0.percent ?? -1) >= 0 })
    }
}
