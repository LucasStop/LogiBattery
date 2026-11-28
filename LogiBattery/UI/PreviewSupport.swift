#if DEBUG
import Foundation

/// Dados de exemplo e fakes só para os `#Preview` do canvas do Xcode.
enum Sample {
    static func device(_ name: String, _ kind: DeviceKind, _ percent: Int?, path: DevicePath = .receiver,
                       charge: ChargeState = .discharging, sides: [DeviceSide]? = nil) -> Device {
        Device(id: name, name: name, kind: kind, percent: percent, chargeState: charge, path: path,
               readAt: .now, sides: sides)
    }

    static let mouse = device("MX Master 3S", .mouse, 82)
    static let keyboard = device("G PRO X TKL", .keyboard, 14, charge: .charging)
    static let headphones = device("MeloBuds Pro", .headphones, 64, path: .bluetooth, sides: [
        DeviceSide(side: .left, percent: 90, charging: false),
        DeviceSide(side: .right, percent: 64, charging: true)
    ])
    static let all = [mouse, keyboard, headphones]
    static let macPowerAdapter = MacPowerSnapshot(
        powerSource: .powerAdapter,
        detail: .fullyCharged,
        energyMode: .highPower,
        supportsHighPower: true
    )
}

struct PreviewScanner: DeviceScanning {
    let devices: [Device]
    func scan() async -> [Device] { devices }
}

struct PreviewAccess: InputAccess {
    let status: InputAccessStatus
    func request() {}
    func openPrivacySettings() {}
}

struct PreviewMacPowerReader: MacPowerReading {
    let snapshot: MacPowerSnapshot?
    func read() async -> MacPowerSnapshot? { snapshot }
}

struct PreviewPowerModeController: PowerModeControlling {
    let statusValue: PowerHelperStatus
    init(status: PowerHelperStatus = .enabled) { self.statusValue = status }
    func status() -> PowerHelperStatus { statusValue }
    func register() throws -> PowerHelperStatus { statusValue }
    func setPowerMode(_ mode: EnergyMode, scope: String) async throws {}
    func revoke() throws {}
}

struct PreviewSignificantEnergyReader: SignificantEnergyReading {
    let items: [SignificantEnergyItem]
    func sample() async -> [SignificantEnergyItem] { items }
    func reset() async {}
}
#endif
