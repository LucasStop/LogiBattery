import Foundation

struct BatteryAlert: Equatable, Sendable {
    enum Severity: Equatable, Sendable { case low, critical, full }

    let deviceName: String
    let percent: Int
    let severity: Severity
}

/// Regra de aviso de bateria baixa (US-07): um aviso por limite cruzado, rearmado ao recarregar acima dele.
struct LowBatteryRule {
    // ponytail: o estado fica só em memória; reabrir o app pode repetir um aviso. Persistir se incomodar.
    var thresholds: [Int]
    private var fired: [String: Set<Int>] = [:]

    init(thresholds: [Int] = [20, 10]) {
        self.thresholds = thresholds
    }

    mutating func evaluate(_ devices: [Device]) -> [BatteryAlert] {
        devices.compactMap { alert(for: $0) }
    }

    private mutating func alert(for device: Device) -> BatteryAlert? {
        guard let percent = device.percent else { return nil }
        // Acima do limite rearma, mesmo carregando.
        fired[device.id, default: []].subtract(thresholds.filter { percent >= $0 })
        guard device.chargeState != .charging, device.chargeState != .full else { return nil }

        let crossed = thresholds.filter { percent < $0 && !(fired[device.id]?.contains($0) ?? false) }
        guard let sharpest = crossed.min() else { return nil }
        fired[device.id, default: []].formUnion(crossed)
        let severity: BatteryAlert.Severity = sharpest == thresholds.min() && thresholds.count > 1 ? .critical : .low
        return BatteryAlert(deviceName: device.name, percent: percent, severity: severity)
    }
}

protocol AlertNotifying {
    func notify(_ alert: BatteryAlert)
}

@MainActor
final class AlertCoordinator {
    private var lowRule = LowBatteryRule()
    private var fullRule = FullChargeRule()
    private let notifier: any AlertNotifying
    private let settings: SettingsModel

    init(notifier: any AlertNotifying, settings: SettingsModel = .shared) {
        self.notifier = notifier
        self.settings = settings
    }

    func handle(_ devices: [Device]) {
        lowRule.thresholds = [settings.values.lowThreshold, settings.values.criticalThreshold]
        var alerts = lowRule.evaluate(devices)
        if settings.values.fullChargeAlert { alerts += fullRule.evaluate(devices) }
        alerts.forEach(notifier.notify)
    }
}
