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

    private func label(_ title: LocalizedStringKey, hint: LocalizedStringKey?, icon: String,
                       tint: SettingsIconTint) -> some View {
        HStack(spacing: 10) {
            SettingsRowIcon(systemName: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
            }
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
