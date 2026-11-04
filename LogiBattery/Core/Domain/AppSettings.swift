import Foundation
import Observation

struct AppSettings: Codable, Equatable, Sendable {
    /// Minutos que o menu de "Aparelhos sem resposta" oferece (#115); 0 é "Na hora".
    static let windowOptions = [0, 5, 15, 30, 60, 120, 360, 720, 1440, 2880, 10080]

    var lowThreshold = 20
    var criticalThreshold = 10
    var fullChargeAlert = true
    var intervalMinutes = 1
    var grayAfterMinutes = 30
    var keepForMinutes = 24 * 60
    var forgetScope = ForgetScope.grayOnly

    var interval: Duration { .seconds(intervalMinutes * 60) }
    var thresholds: BatteryThresholds { BatteryThresholds(low: lowThreshold, critical: criticalThreshold) }
    var readingPolicy: ReadingPolicy {
        ReadingPolicy(grayAfter: Double(grayAfterMinutes) * 60, keepFor: Double(keepForMinutes) * 60,
                      forgetScope: forgetScope)
    }

    /// Mantém os valores em faixa, o limite crítico abaixo do baixo e o cinza dentro do tempo de sumir.
    func normalized() -> AppSettings {
        var result = self
        result.lowThreshold = min(max(lowThreshold, 5), 50)
        result.criticalThreshold = min(max(criticalThreshold, 1), result.lowThreshold - 1)
        result.intervalMinutes = min(max(intervalMinutes, 1), 60)
        result.keepForMinutes = Self.snapped(keepForMinutes)
        result.grayAfterMinutes = min(Self.snapped(grayAfterMinutes), result.keepForMinutes)
        return result
    }

    /// Valor do menu mais próximo: ajuste salvo à mão fora da lista não deixa o seletor sem opção marcada.
    static func snapped(_ minutes: Int) -> Int {
        windowOptions.min { abs($0 - minutes) < abs($1 - minutes) } ?? minutes
    }
}

/// `decodeIfPresent` nos campos da #115: o Codable sintetizado exige todas as chaves e perderia os ajustes já salvos.
/// Fica na extensão para manter o `init` memberwise.
extension AppSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        lowThreshold = try container.decodeIfPresent(Int.self, forKey: .lowThreshold) ?? defaults.lowThreshold
        criticalThreshold = try container.decodeIfPresent(Int.self, forKey: .criticalThreshold)
            ?? defaults.criticalThreshold
        fullChargeAlert = try container.decodeIfPresent(Bool.self, forKey: .fullChargeAlert)
            ?? defaults.fullChargeAlert
        intervalMinutes = try container.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? defaults.intervalMinutes
        grayAfterMinutes = try container.decodeIfPresent(Int.self, forKey: .grayAfterMinutes)
            ?? defaults.grayAfterMinutes
        keepForMinutes = try container.decodeIfPresent(Int.self, forKey: .keepForMinutes) ?? defaults.keepForMinutes
        forgetScope = try container.decodeIfPresent(ForgetScope.self, forKey: .forgetScope) ?? defaults.forgetScope
    }
}

/// Valor que a tela puxou junto para manter "cinza <= sumir" (#115): a dica da linha mostra de quanto para quanto.
struct SettingsAdjustment: Equatable, Sendable {
    enum Field: Sendable { case grayAfter, keepFor }
    let field: Field
    let before: Int
    let after: Int
}

/// Ajustes do usuário (US-11): sem botão salvar, cada mudança persiste na hora e vale na próxima leitura.
@MainActor
@Observable
final class SettingsModel {
    static let shared = SettingsModel(defaults: .standard)

    var values: AppSettings {
        didSet {
            let clean = values.normalized()
            if clean != values { values = clean }
            guard let data = try? JSONEncoder().encode(clean) else { return }
            defaults.set(data, forKey: Self.key)
            onChange?(clean)
        }
    }

    /// Último ajuste que a tela fez sozinha; some na próxima mudança de qualquer uma das três linhas.
    private(set) var adjustment: SettingsAdjustment?

    /// Liga os Ajustes aos consumidores que não observam o modelo (lista, snapshot do widget); o app define no `init`.
    @ObservationIgnored var onChange: (@MainActor (AppSettings) -> Void)?

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

    /// O último valor mexido vale e o outro é puxado junto: cinza nunca passa de sumir (#115).
    func setGrayAfter(_ minutes: Int) {
        var next = values
        next.grayAfterMinutes = minutes
        adjustment = nil
        if minutes > next.keepForMinutes {
            adjustment = SettingsAdjustment(field: .keepFor, before: next.keepForMinutes, after: minutes)
            next.keepForMinutes = minutes
        }
        values = next
    }

    func setKeepFor(_ minutes: Int) {
        var next = values
        next.keepForMinutes = minutes
        adjustment = nil
        if next.grayAfterMinutes > minutes {
            adjustment = SettingsAdjustment(field: .grayAfter, before: next.grayAfterMinutes, after: minutes)
            next.grayAfterMinutes = minutes
        }
        values = next
    }

    func setForgetScope(_ scope: ForgetScope) {
        adjustment = nil
        values.forgetScope = scope
    }

    private static let key = "settings"
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        values = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) }?
            .normalized() ?? AppSettings()
    }
}
