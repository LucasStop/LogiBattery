import SwiftUI

/// Janela de ajustes (T06): sem botão salvar. "Abrir no login" entra com a US-10.
struct SettingsView: View {
    @State private var model = SettingsModel.shared
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section {
                stepper("settings.low", hint: "settings.low.hint", value: $model.values.lowThreshold,
                        range: 5...50, step: 5) { "\($0)%" }
                stepper("settings.critical", hint: nil, value: $model.values.criticalThreshold,
                        range: 1...49, step: 1) { "\($0)%" }
                Toggle(isOn: $model.values.fullChargeAlert) {
                    label("settings.full", hint: "settings.full.hint")
                }
            }
            Section {
                stepper("settings.interval", hint: "settings.interval.hint", value: $model.values.intervalMinutes,
                        range: 1...60, step: 1) { "\($0) min" }
            }
            Section {
                LabeledContent {
                    Button("settings.history.delete") { confirmDelete = true }
                } label: {
                    label("settings.history", hint: "settings.history.hint")
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

    private func label(_ title: LocalizedStringKey, hint: LocalizedStringKey?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func stepper(_ title: LocalizedStringKey, hint: LocalizedStringKey?, value: Binding<Int>,
                         range: ClosedRange<Int>, step: Int, format: @escaping (Int) -> String) -> some View {
        Stepper(value: value, in: range, step: step) {
            LabeledContent {
                Text(format(value.wrappedValue)).monospacedDigit()
            } label: {
                label(title, hint: hint)
            }
        }
    }
}
