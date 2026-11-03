import Foundation
import Observation

struct AppSettings: Codable, Equatable, Sendable {
    var lowThreshold = 20
    var criticalThreshold = 10
    var fullChargeAlert = true
    var intervalMinutes = 1

    var interval: Duration { .seconds(intervalMinutes * 60) }
    var thresholds: BatteryThresholds { BatteryThresholds(low: lowThreshold, critical: criticalThreshold) }

    /// Mantém os valores em faixa e o limite crítico abaixo do baixo.
    func normalized() -> AppSettings {
        var result = self
        result.lowThreshold = min(max(lowThreshold, 5), 50)
        result.criticalThreshold = min(max(criticalThreshold, 1), result.lowThreshold - 1)
        result.intervalMinutes = min(max(intervalMinutes, 1), 60)
        return result
    }
}

/// Ajustes do usuário (US-11): sem botão salvar, cada mudança persiste na hora e vale na próxima leitura.
@MainActor
@Observable
final class SettingsModel {
    static let shared = SettingsModel(defaults: .standard)

    var values: AppSettings {
        didSet {
            let clean = values.normalized()
            if clean != values { values = clean; return }
            guard let data = try? JSONEncoder().encode(values) else { return }
            defaults.set(data, forKey: Self.key)
        }
    }

    /// Chave própria (`@AppStorage`) e não campo de `AppSettings`: campo novo ali quebra o decode dos ajustes
    /// já salvos, e o Codable sintetizado não usa o valor padrão para chave ausente.
    nonisolated static let showMenuBarIconKey = "showMenuBarIcon"
    nonisolated static let popoverWidthKey = "popoverWidth"
    nonisolated static let defaultPopoverWidth = 320
    nonisolated static let popoverWidthRange = 320...480
    nonisolated static let popoverWidthStep = 20

    nonisolated static func normalizedPopoverWidth(_ width: Int) -> Int {
        min(max(width, popoverWidthRange.lowerBound), popoverWidthRange.upperBound)
    }

    private static let key = "settings"
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        values = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) }?
            .normalized() ?? AppSettings()
    }
}
