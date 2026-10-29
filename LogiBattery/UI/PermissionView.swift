import SwiftUI

/// Guia de permissão (T07): explica o Monitoramento de Entrada e leva ao painel de Privacidade.
struct PermissionView: View {
    let model: PermissionModel
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 12) {
            Text("permission.title").font(.title3.weight(.semibold))
            Text("permission.body").foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 4) {
                Text("permission.step1")
                Text("permission.step2")
                Text("permission.step3")
            }
            .foregroundStyle(.secondary)
            Button("permission.open") { model.openPrivacy() }
                .buttonStyle(.borderedProminent)
            Button("permission.later") {
                model.dismiss()
                dismissWindow(id: "permission")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 380)
        .task {
            // Fecha sozinho quando a permissão chega.
            while !Task.isCancelled, model.status != .granted {
                try? await Task.sleep(for: .seconds(2))
                model.refresh()
            }
            dismissWindow(id: "permission")
        }
    }
}

/// Faixa do popover enquanto faltar a permissão (T04, erro de permissão).
struct PermissionBanner: View {
    let model: PermissionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("permission.banner.title").font(.headline)
            Text("permission.banner.body").font(.callout).foregroundStyle(.secondary)
            Button("permission.open") { model.openPrivacy() }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
