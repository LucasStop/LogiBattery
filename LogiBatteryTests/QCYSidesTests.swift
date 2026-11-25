import QCYKit
import XCTest
@testable import LogiBattery

/// Fone QCY no popover (#142, ADR 0006): lados, menor lado como `percent`, fusão com a linha do sistema e contrato.
final class QCYSidesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func system(percent: Int? = 100, name: String = "QCY MeloBuds Pro - Lucas") -> Device {
        Device(id: "bt-audio-\(name)", name: name, kind: .headphones, percent: percent,
               chargeState: .unknown, path: .bluetooth, readAt: now)
    }

    func testLeftAndRightBecomeSidesAndZeroIsNoReading() {
        let sides = QCYSides.make(left: QCYBatteryLevel(raw: 90), right: QCYBatteryLevel(raw: 0),
                                  caseBattery: nil)
        XCTAssertEqual(sides, [DeviceSide(side: .left, percent: 90, charging: false)])
    }

    func testCaseOnlyEntersWithReadingAndChargeFlagIsKept() {
        let sides = QCYSides.make(left: QCYBatteryLevel(raw: 0x80 | 60), right: QCYBatteryLevel(raw: 85),
                                  caseBattery: QCYBatteryLevel(raw: 100))
        XCTAssertEqual(sides.map(\.side), [.left, .right, .case])
        XCTAssertEqual(sides[0], DeviceSide(side: .left, percent: 60, charging: true))
    }

    func testPercentIsTheLowestSideNotTheCase() {
        let sides = [DeviceSide(side: .left, percent: 90, charging: false),
                     DeviceSide(side: .right, percent: 85, charging: false),
                     DeviceSide(side: .case, percent: 10, charging: false)]
        let merged = system().applying(qcy: sides)
        XCTAssertEqual(merged.percent, 85)
        XCTAssertEqual(merged.sides, sides)
        XCTAssertEqual(merged.id, system().id)
        XCTAssertEqual(merged.name, system().name)
    }

    func testOneSideStillGivesPercentAndChargingSideMarksDevice() {
        let merged = system(percent: nil).applying(qcy: [DeviceSide(side: .right, percent: 40, charging: true)])
        XCTAssertEqual(merged.percent, 40)
        XCTAssertEqual(merged.chargeState, .charging)
    }

    func testOnlyCaseOrEmptyKeepsSystemReading() {
        let original = system(percent: nil)
        XCTAssertEqual(original.applying(qcy: []), original)
        XCTAssertEqual(original.applying(qcy: [DeviceSide(side: .case, percent: 80, charging: false)]), original)
    }

    func testOnlyHeadphonesNamedQCYAreMerged() {
        XCTAssertTrue(system().isQCYHeadset)
        XCTAssertFalse(system(name: "AirPods Pro").isQCYHeadset)
    }

    func testSidesAreOptionalAndAdditiveInTheSnapshotJSON() throws {
        let plain = try JSONEncoder().encode(system())
        XCTAssertNil((try JSONSerialization.jsonObject(with: plain) as? [String: Any])?["sides"])
        let merged = system().applying(qcy: [DeviceSide(side: .left, percent: 90, charging: false),
                                             DeviceSide(side: .right, percent: 85, charging: true)])
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(Device.self, from: JSONEncoder().encode(merged)), merged)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(merged)) as? [String: Any])
        let entry = try XCTUnwrap((json["sides"] as? [[String: Any]])?.last)
        XCTAssertEqual(entry["side"] as? String, "right")
        XCTAssertEqual(entry["charging"] as? Bool, true)
    }

    /// Regressão do "—" do fone: o sistema devolve sem nível e a leitura do QCY preenche.
    func testSystemRowWithoutPercentGetsReadingFromAdvertisement() throws {
        // Mesmos bytes da fixture `qcy-advertisement-melobuds-pro` do QCYKit (gravada em 2026-11-12).
        let bytes: [UInt8] = [0x1C, 0x52, 0x4D, 0x4A, 0x9D, 0x00, 0x6E, 0x5D, 0x5E, 0x00, 0xB6, 0x76, 0x48,
                              0xAC, 0x84, 0x60, 0x6E, 0x90, 0xE9, 0x01, 0xAC, 0x84, 0x60, 0x2F, 0x9D, 0xE9]
        let advertisement = try XCTUnwrap(QCYAdvertisement(manufacturerData: Data(bytes)))
        let merged = system(percent: nil).applying(qcy: QCYSides.make(advertisement))
        XCTAssertEqual(merged.sides?.map(\.percent), [93, 94])
        XCTAssertEqual(merged.percent, 93)
    }
}
