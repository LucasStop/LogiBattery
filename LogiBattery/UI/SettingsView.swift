import AppKit
import SwiftUI

/// Janela de ajustes (T06, #67): visual dos Ajustes do Sistema (`Form(.grouped)`, seções com cabeçalho e ícone em
/// quadrado colorido por linha), sem botão salvar.
struct SettingsView: View {
    @State private var model = SettingsModel.shared
    @State private var login = LoginItemModel()
    @State private var confirmDelete = false
    @State private var pixCopied = false
    @AppStorage(SettingsModel.showMenuBarIconKey) private var showMenuBarIcon = true
    @AppStorage(SettingsModel.popoverWidthKey) private var popoverWidth = SettingsModel.defaultPopoverWidth

    var body: some View {
        Form {
            Section("settings.section.alerts") {
                stepper("settings.low", hint: "settings.low.hint", icon: "bell.fill", tint: .orange,
                        value: $model.values.lowThreshold, range: 5...50, step: 5) { "\($0)%" }
                stepper("settings.critical", hint: nil, icon: "exclamationmark.triangle.fill", tint: .red,
                        value: $model.values.criticalThreshold, range: 1...49, step: 1) { "\($0)%" }
                Toggle(isOn: $model.values.fullChargeAlert) {
                    label("settings.full", hint: "settings.full.hint", icon: "bolt.fill", tint: .green)
                }
            }
            Section("settings.section.reading") {
                stepper("settings.interval", hint: "settings.interval.hint", icon: "clock.fill", tint: .gray,
                        value: $model.values.intervalMinutes, range: 1...60, step: 1) { "\($0) min" }
            }
            Section("settings.section.unresponsive") {
                durationPicker("settings.grayAfter", icon: "moon.fill", tint: .gray,
                               selection: Binding(get: { model.values.grayAfterMinutes },
                                                  set: { model.setGrayAfter($0) }),
                               hint: model.values.grayAfterMinutes == 0
                                   ? "settings.grayAfter.hint.now" : "settings.grayAfter.hint",
                               note: note(for: .grayAfter))
                Picker(selection: Binding(get: { model.values.forgetScope }, set: { model.setForgetScope($0) })) {
                    Text("settings.forgetScope.gray").tag(ForgetScope.grayOnly)
                    Text("settings.forgetScope.all").tag(ForgetScope.anyKept)
                } label: {
                    label("settings.forgetScope", hint: forgetHint, icon: "eraser.fill", tint: .orange)
                }
                .pickerStyle(.menu)
                .disabled(model.values.keepForMinutes == 0)
                durationPicker("settings.keepFor", icon: "eye.slash.fill", tint: .red,
                               selection: Binding(get: { model.values.keepForMinutes },
                                                  set: { model.setKeepFor($0) }),
                               hint: model.values.keepForMinutes == 0
                                   ? "settings.keepFor.hint.now" : "settings.keepFor.hint",
                               note: note(for: .keepFor))
            }
            Section("settings.section.general") {
                Toggle(isOn: Binding(get: { login.isEnabled }, set: { login.setEnabled($0) })) {
                    label("settings.login", hint: login.failed ? "settings.login.error" : nil,
                          icon: "power", tint: .blue)
                }
                Toggle(isOn: $showMenuBarIcon) {
                    label("settings.menuBarIcon", hint: "settings.menuBarIcon.hint",
                          icon: "menubar.rectangle", tint: .purple)
                }
                stepper("settings.popoverWidth", hint: "settings.popoverWidth.hint",
                        icon: "arrow.left.and.right.square", tint: .blue,
                        value: $popoverWidth, range: SettingsModel.popoverWidthRange,
                        step: SettingsModel.popoverWidthStep) { "\($0) pt" }
            }
            Section("settings.section.history") {
                LabeledContent {
                    Button("settings.history.delete") { confirmDelete = true }
                } label: {
                    label("settings.history", hint: "settings.history.hint", icon: "trash.fill", tint: .red)
                }
            }
            Section("settings.section.about") {
                LabeledContent {
                    Text(AboutInfo.version).monospacedDigit().foregroundStyle(.secondary)
                } label: {
                    label("settings.version", hint: "settings.version.hint", icon: "info.circle.fill", tint: .gray)
                }
                LabeledContent {
                    Button("settings.github.open") { NSWorkspace.shared.open(AboutInfo.repositoryURL) }
                } label: {
                    label("settings.github", hint: "settings.github.hint",
                          icon: "chevron.left.forwardslash.chevron.right", tint: .gray)
                }
                LabeledContent {
                    Button(pixCopied ? "settings.pix.copied" : "settings.pix.copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(AboutInfo.pixKey, forType: .string)
                        pixCopied = true
                    }
                } label: {
                    label("settings.pix", hint: "settings.pix.hint", icon: "diamond.fill", tint: .green)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .confirmationDialog("settings.history.confirm", isPresented: $confirmDelete) {
            Button("settings.history.confirm.action", role: .destructive) {
                try? HistoryStore.appGroup?.deleteAll()
            }
            Button("settings.cancel", role: .cancel) {}
        }
    }

    private func label(_ title: LocalizedStringKey, hint: LocalizedStringKey?, note: String? = nil, icon: String,
                       tint: SettingsIconTint) -> some View {
        HStack(spacing: 10) {
            SettingsRowIcon(systemName: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                // Aviso de ajuste automático em cor principal; a dica normal fica em secundária (DESIGN.md §5).
                if let note {
                    Text(verbatim: note).font(.caption)
                } else if let hint {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var forgetHint: LocalizedStringKey {
        if model.values.keepForMinutes == 0 { return "settings.forgetScope.hint.off" }
        return model.values.forgetScope == .anyKept ? "settings.forgetScope.hint.all" : "settings.forgetScope.hint.gray"
    }

    /// Texto "Ajustado de X para Y" da linha que a tela puxou junto, ou nil.
    private func note(for field: SettingsAdjustment.Field) -> String? {
        guard let adjustment = model.adjustment, adjustment.field == field else { return nil }
        let before = Self.windowText(adjustment.before), after = Self.windowText(adjustment.after)
        switch field {
        case .grayAfter: return String(localized: "settings.adjusted.grayAfter \(before) \(after)")
        case .keepFor: return String(localized: "settings.adjusted.keepFor \(before) \(after)")
        }
    }

    /// "Na hora" para zero, senão a duração no idioma do sistema ("30 min", "24 h", "7 dias").
    static func windowText(_ minutes: Int, width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated) -> String {
        guard minutes > 0 else { return String(localized: "settings.window.now") }
        let units: Set<Duration.UnitsFormatStyle.Unit> = minutes >= 10_080 ? [.days] : [.hours, .minutes]
        return Duration.seconds(minutes * 60).formatted(.units(allowed: units, width: width, maximumUnitCount: 1))
    }

    // swiftlint:disable:next function_parameter_count
    private func durationPicker(_ title: LocalizedStringKey, icon: String, tint: SettingsIconTint,
                                selection: Binding<Int>, hint: LocalizedStringKey, note: String?) -> some View {
        Picker(selection: selection) {
            ForEach(AppSettings.windowOptions, id: \.self) { Text(Self.windowText($0)).tag($0) }
        } label: {
            label(title, hint: hint, note: note, icon: icon, tint: tint)
        }
        .pickerStyle(.menu)
        .accessibilityValue(Self.windowText(selection.wrappedValue, width: .wide))
        .onChange(of: note) { _, new in
            if let new { AccessibilityNotification.Announcement(new).post() }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func stepper(_ title: LocalizedStringKey, hint: LocalizedStringKey?, icon: String,
                         tint: SettingsIconTint, value: Binding<Int>, range: ClosedRange<Int>, step: Int,
                         format: @escaping (Int) -> String) -> some View {
        Stepper(value: value, in: range, step: step) {
            LabeledContent {
                Text(format(value.wrappedValue)).monospacedDigit()
            } label: {
                label(title, hint: hint, icon: icon, tint: tint)
            }
        }
    }
}

/// Dados da seção Sobre (#91). Links abrem no navegador padrão via `NSWorkspace`; o app não tem entitlement de rede.
enum AboutInfo {
    static let repositoryURL = URL(string: "https://github.com/LucasStop/LogiBattery")!
    /// Chave Pix aleatória pública, feita para ser divulgada.
    static let pixKey = "dd226f83-02f0-4c80-bd23-322c9f5fa7ee" // gitleaks:allow (chave pública de doação)
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

/// Cores dos ícones de linha dos Ajustes (DESIGN.md §4, #67).
private enum SettingsIconTint {
    case blue, orange, red, green, purple, gray

    var color: Color {
        switch self {
        case .blue: Color(light: 0x0A84FF, dark: 0x0A84FF)
        case .orange: Color(light: 0xFF9500, dark: 0xFF9F0A)
        case .red: Color(light: 0xFF3B30, dark: 0xFF453A)
        case .green: Color(light: 0x28A745, dark: 0x30B350)
        case .purple: Color(light: 0x8E5CD9, dark: 0x9D6BE0)
        case .gray: Color(light: 0x8E8E93, dark: 0x7C7C82)
        }
    }
}

/// Quadrado colorido de 24 pt com raio 6 (`r-sm`) e SF Symbol branco de 14 pt (DESIGN.md §4, #67).
private struct SettingsRowIcon: View {
    let systemName: String
    let tint: SettingsIconTint

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(tint.color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Ajustes") { SettingsView() }
#endif
