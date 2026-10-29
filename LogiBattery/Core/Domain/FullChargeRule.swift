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
                if cycles[device.identity] == nil { cycles[device.identity] = .charging }
            case .discharging:
                cycles[device.identity] = nil
            case .full:
                guard cycles[device.identity] == .charging else { return nil }
                cycles[device.identity] = .notified
                return BatteryAlert(deviceName: device.name, percent: device.percent ?? 100, severity: .full)
            case .unknown:
                break
            }
            return nil
        }
    }
}
