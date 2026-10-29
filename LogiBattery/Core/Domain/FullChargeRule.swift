import Foundation

/// Regra de aviso de carga completa (US-08): um aviso por ciclo, que só termina quando o aparelho descarrega.
struct FullChargeRule {
    private enum Cycle { case charging, notified }
    // ponytail: o estado fica só em memória; um aparelho que já abre cheio não avisa até o próximo ciclo.
    private var cycles: [String: Cycle] = [:]

    mutating func evaluate(_ devices: [Device]) -> [BatteryAlert] {
        devices.compactMap { device in
            switch device.chargeState {
            case .charging:
                if cycles[device.id] == nil { cycles[device.id] = .charging }
            case .discharging:
                cycles[device.id] = nil
            case .full:
                guard cycles[device.id] == .charging else { return nil }
                cycles[device.id] = .notified
                return BatteryAlert(deviceName: device.name, percent: device.percent ?? 100, severity: .full)
            case .unknown:
                break
            }
            return nil
        }
    }
}
