import XCTest
@testable import LogiBattery

@MainActor
final class SettingsTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "LogiBatteryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testDefaultsMatchPRD() {
        let settings = AppSettings()
        XCTAssertEqual(settings.lowThreshold, 20)
        XCTAssertEqual(settings.criticalThreshold, 10)
        XCTAssertTrue(settings.fullChargeAlert)
        XCTAssertEqual(settings.intervalMinutes, 1)
    }

    func testChangesPersistAcrossRestart() {
        let defaults = defaults()
        let model = SettingsModel(defaults: defaults)
        model.values.lowThreshold = 30
        model.values.intervalMinutes = 15
        model.values.fullChargeAlert = false
        let reopened = SettingsModel(defaults: defaults)
        XCTAssertEqual(reopened.values.lowThreshold, 30)
        XCTAssertEqual(reopened.values.intervalMinutes, 15)
        XCTAssertFalse(reopened.values.fullChargeAlert)
    }

    func testCriticalStaysBelowLowAndValuesStayInRange() {
        var settings = AppSettings(lowThreshold: 20, criticalThreshold: 10, fullChargeAlert: true, intervalMinutes: 1)
        settings.criticalThreshold = 25
        XCTAssertEqual(settings.normalized().criticalThreshold, 19)
        settings = AppSettings(lowThreshold: 8, criticalThreshold: 10, fullChargeAlert: true, intervalMinutes: 1)
        XCTAssertEqual(settings.normalized().lowThreshold, 8)
        XCTAssertEqual(settings.normalized().criticalThreshold, 7)
        settings = AppSettings(lowThreshold: 90, criticalThreshold: 0, fullChargeAlert: true, intervalMinutes: 0)
        let normalized = settings.normalized()
        XCTAssertEqual(normalized.lowThreshold, 50)
        XCTAssertEqual(normalized.criticalThreshold, 1)
        XCTAssertEqual(normalized.intervalMinutes, 1)
    }

    func testCorruptStoredValueFallsBackToDefaults() {
        let defaults = defaults()
        defaults.set(Data("oops".utf8), forKey: "settings")
        XCTAssertEqual(SettingsModel(defaults: defaults).values, AppSettings())
    }

    func testSettingsAreAppliedOnNextReading() {
        let notifier = SettingsRecordingNotifier()
        let model = SettingsModel(defaults: defaults())
        let coordinator = AlertCoordinator(notifier: notifier, settings: model)
        let mouse = Device(id: "m", name: "MX", kind: .mouse, percent: 25, chargeState: .discharging,
                           path: .receiver, readAt: .now)
        coordinator.handle([mouse])
        XCTAssertEqual(notifier.alerts, [])
        model.values.lowThreshold = 30
        coordinator.handle([mouse])
        XCTAssertEqual(notifier.alerts.map(\.severity), [.low])
    }

    func testFullChargeAlertCanBeSwitchedOff() {
        let notifier = SettingsRecordingNotifier()
        let model = SettingsModel(defaults: defaults())
        model.values.fullChargeAlert = false
        let coordinator = AlertCoordinator(notifier: notifier, settings: model)
        func keyboard(_ state: ChargeState) -> Device {
            Device(id: "k", name: "K", kind: .keyboard, percent: 100, chargeState: state, path: .receiver, readAt: .now)
        }
        coordinator.handle([keyboard(.charging)])
        coordinator.handle([keyboard(.full)])
        XCTAssertEqual(notifier.alerts, [])
    }

    func testPollIntervalFollowsSettings() {
        let model = SettingsModel(defaults: defaults())
        XCTAssertEqual(model.values.interval, .seconds(60))
        model.values.intervalMinutes = 10
        XCTAssertEqual(model.values.interval, .seconds(600))
    }

    /// #115: os padrões da seção "Aparelhos sem resposta" são as regras que valiam antes (30 min, só cinza, 24 h).
    func testUnresponsiveDefaultsKeepTheOldRules() {
        let settings = AppSettings()
        XCTAssertEqual(settings.grayAfterMinutes, 30)
        XCTAssertEqual(settings.keepForMinutes, 24 * 60)
        XCTAssertEqual(settings.forgetScope, .grayOnly)
        XCTAssertEqual(settings.readingPolicy, ReadingPolicy())
    }

    /// Ajuste salvo antes da #115 não tem as chaves novas: o decode tem de manter o que já estava e usar os padrões.
    func testSettingsSavedBeforeTheUnresponsiveSectionKeepTheirValues() throws {
        let defaults = defaults()
        let old = #"{"lowThreshold":30,"criticalThreshold":12,"fullChargeAlert":false,"intervalMinutes":5}"#
        defaults.set(Data(old.utf8), forKey: "settings")
        let values = SettingsModel(defaults: defaults).values
        XCTAssertEqual(values.lowThreshold, 30)
        XCTAssertEqual(values.criticalThreshold, 12)
        XCTAssertFalse(values.fullChargeAlert)
        XCTAssertEqual(values.intervalMinutes, 5)
        XCTAssertEqual(values.readingPolicy, ReadingPolicy())
    }

    func testUnresponsiveSettingsPersistAcrossRestartAndBecomeSeconds() {
        let defaults = defaults()
        let model = SettingsModel(defaults: defaults)
        model.setKeepFor(7 * 24 * 60)
        model.setGrayAfter(5)
        model.setForgetScope(.anyKept)
        let reopened = SettingsModel(defaults: defaults).values
        XCTAssertEqual(reopened.readingPolicy,
                       ReadingPolicy(grayAfter: 5 * 60, keepFor: 7 * 24 * 3600, forgetScope: .anyKept))
    }

    /// Cinza nunca passa de sumir: o último valor mexido vale e o outro é puxado junto, com o aviso "de X para Y".
    func testRaisingGrayAfterPastKeepForPullsKeepForUp() {
        let model = SettingsModel(defaults: defaults())
        model.setKeepFor(60)
        model.setGrayAfter(120)
        XCTAssertEqual(model.values.grayAfterMinutes, 120)
        XCTAssertEqual(model.values.keepForMinutes, 120)
        XCTAssertEqual(model.adjustment, SettingsAdjustment(field: .keepFor, before: 60, after: 120))
    }

    func testLoweringKeepForBelowGrayAfterPullsGrayAfterDown() {
        let model = SettingsModel(defaults: defaults())
        model.setKeepFor(15)
        XCTAssertEqual(model.values.grayAfterMinutes, 15)
        XCTAssertEqual(model.values.keepForMinutes, 15)
        XCTAssertEqual(model.adjustment, SettingsAdjustment(field: .grayAfter, before: 30, after: 15))
    }

    /// Sumir "na hora" não mantém leitura nenhuma, então o cinza vai junto para "na hora".
    func testKeepForZeroPullsGrayAfterToZero() {
        let model = SettingsModel(defaults: defaults())
        model.setKeepFor(0)
        XCTAssertEqual(model.values.grayAfterMinutes, 0)
        XCTAssertEqual(model.adjustment, SettingsAdjustment(field: .grayAfter, before: 30, after: 0))
    }

    func testAdjustmentNoticeGoesAwayOnTheNextChangeOfTheSection() {
        let model = SettingsModel(defaults: defaults())
        model.setKeepFor(15)
        XCTAssertNotNil(model.adjustment)
        model.setForgetScope(.anyKept)
        XCTAssertNil(model.adjustment)
        model.setKeepFor(5)
        XCTAssertNotNil(model.adjustment)
        model.setGrayAfter(0)
        XCTAssertNil(model.adjustment)
    }

    func testChangeInsideTheRuleDoesNotAdjustAnything() {
        let model = SettingsModel(defaults: defaults())
        model.setGrayAfter(5)
        model.setKeepFor(60)
        XCTAssertNil(model.adjustment)
        XCTAssertEqual(model.values.grayAfterMinutes, 5)
        XCTAssertEqual(model.values.keepForMinutes, 60)
    }

    /// Valor salvo à mão fora da lista do menu vai para o mais próximo, e o cinza continua dentro do sumir.
    func testSavedValueOutsideTheMenuSnapsToTheNearestOption() {
        let defaults = defaults()
        let odd = #"{"grayAfterMinutes":100,"keepForMinutes":99999}"#
        defaults.set(Data(odd.utf8), forKey: "settings")
        let values = SettingsModel(defaults: defaults).values
        XCTAssertEqual(values.grayAfterMinutes, 120)
        XCTAssertEqual(values.keepForMinutes, 10_080)
        let inverted = #"{"grayAfterMinutes":720,"keepForMinutes":60}"#
        defaults.set(Data(inverted.utf8), forKey: "settings")
        XCTAssertEqual(SettingsModel(defaults: defaults).values.grayAfterMinutes, 60)
    }

    /// B3 da revisão #116: mudar um ajuste tem de avisar quem não observa o modelo (lista e snapshot do widget).
    func testEveryChangeNotifiesTheAppWithTheCleanValues() {
        let model = SettingsModel(defaults: defaults())
        var received: [AppSettings] = []
        model.onChange = { received.append($0) }
        model.setKeepFor(15)
        model.values.lowThreshold = 30
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.first?.readingPolicy.keepFor, 15 * 60)
        XCTAssertEqual(received.last?.lowThreshold, 30)
    }

    func testPopoverWidthNormalization() {
        XCTAssertEqual(SettingsModel.defaultPopoverWidth, 320)
        XCTAssertEqual(SettingsModel.normalizedPopoverWidth(280), 320)
        XCTAssertEqual(SettingsModel.normalizedPopoverWidth(380), 380)
        XCTAssertEqual(SettingsModel.normalizedPopoverWidth(600), 480)
    }

    func testDeleteAllHistoryEmptiesStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let device = Device(id: "a", name: "A", kind: .mouse, percent: 50, chargeState: .discharging,
                            path: .receiver, readAt: .now)
        try store.record([device], at: .now)
        try store.deleteAll()
        XCTAssertEqual(store.points(since: .distantPast), [])
    }
}

private final class SettingsRecordingNotifier: AlertNotifying {
    var alerts: [BatteryAlert] = []
    func notify(_ alert: BatteryAlert) { alerts.append(alert) }
}

final class AboutInfoTests: XCTestCase {
    func testPixKeyIsRandomKeyUUID() {
        XCTAssertNotNil(UUID(uuidString: AboutInfo.pixKey))
    }

    func testRepositoryURLIsHTTPSGitHub() {
        XCTAssertEqual(AboutInfo.repositoryURL.scheme, "https")
        XCTAssertEqual(AboutInfo.repositoryURL.host, "github.com")
    }
}
