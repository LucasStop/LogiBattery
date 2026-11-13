import SwiftUI

/// Janela do fone (T12): bateria por lado, controles e detalhes. Sem bateria de estojo (firmware 2.0.6 não expõe).
struct QCYView: View {
    @Bindable var model: QCYViewModel

    var body: some View {
        VStack(spacing: 12) {
            header
            batteryGroup
            banner
            controlsGroup
            detailsGroup
        }
        .padding(16)
        .frame(width: 468)
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 12) {
            Image(model.phase == .connected ? "lb.headphones.bluetooth" : "headphones")
                .resizable().scaledToFit().padding(9)
                .frame(width: 44, height: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("MeloBuds Pro").font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(badge).font(.caption.weight(.medium))
                .foregroundStyle(model.phase == .connected ? BatteryLevel.normal.color : .secondary)
        }
        .padding(.horizontal, 4)
    }

    private var subtitle: LocalizedStringKey {
        switch model.phase {
        case .loading: "qcy.status.reading"
        case .connected: "qcy.status.connected.detail"
        case .disconnected: "qcy.status.disconnected"
        }
    }

    private var badge: LocalizedStringKey {
        switch model.phase {
        case .loading: "qcy.badge.reading"
        case .connected: "qcy.badge.connected"
        case .disconnected: "qcy.badge.none"
        }
    }

    // MARK: - Bateria

    private var batteryGroup: some View {
        QCYGroup {
            VStack(spacing: 8) {
                HStack {
                    QCYRing(side: "qcy.side.left", level: model.state.left, phase: model.phase)
                    QCYRing(side: "qcy.side.right", level: model.state.right, phase: model.phase)
                }
                Text(model.phase == .connected ? "qcy.foot.polling" : "qcy.foot.none")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 16).padding(.horizontal, 12).padding(.bottom, 12)
        }
    }

    // MARK: - Avisos

    @ViewBuilder
    private var banner: some View {
        if model.writeFailed {
            QCYBanner(tint: BatteryLevel.critical.color, title: "qcy.error.title", detail: "qcy.error.detail",
                      action: ("qcy.error.retry", { model.retryAfterFailure() }))
                .accessibilityAddTraits(.isModal)
        } else if model.pending != nil {
            QCYBanner(tint: Color(light: 0x2B6CB0, dark: 0x63B3ED), title: "qcy.pending.title",
                      detail: "qcy.pending.detail", spinner: true)
        } else if model.phase == .disconnected {
            QCYBanner(tint: BatteryLevel.low.color, title: "qcy.offline.title", detail: "qcy.offline.detail",
                      action: ("qcy.offline.retry", { model.reconnect() }))
        } else if model.isReadOnly, model.phase == .connected {
            QCYBanner(tint: Color(light: 0x2B6CB0, dark: 0x63B3ED), title: "qcy.readonly.title",
                      detail: "qcy.readonly.detail")
        }
    }

    // MARK: - Controles

    private var controlsGroup: some View {
        QCYGroup {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    QCYLabel(title: "qcy.anc.title", hint: model.pending.isANC ? "qcy.pending.short" : "qcy.anc.hint")
                    Picker("qcy.anc.title", selection: Binding(
                        get: { model.ancSelection }, set: { if let choice = $0 { model.select(choice) } })) {
                        Text("qcy.anc.anc").tag(QCYANCChoice?.some(.anc))
                        Text("qcy.anc.normal").tag(QCYANCChoice?.some(.normal))
                        Text("qcy.anc.transparency").tag(QCYANCChoice?.some(.transparency))
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                .padding(12)
                Divider()
                Toggle(isOn: Binding(get: { model.isLDACOn }, set: { model.setLDAC($0) })) {
                    QCYLabel(title: "qcy.ldac.title", hint: "qcy.ldac.hint")
                }
                .toggleStyle(.switch).padding(12)
                Divider()
                Toggle(isOn: Binding(get: { model.isGameOn }, set: { model.setGame($0) })) {
                    QCYLabel(title: "qcy.game.title", hint: "qcy.game.hint")
                }
                .toggleStyle(.switch).padding(12)
            }
            .disabled(model.areControlsDisabled)
            .opacity(model.areControlsDisabled && model.pending == nil ? 0.55 : 1)
        }
    }

    // MARK: - Detalhes

    private var detailsGroup: some View {
        QCYGroup {
            VStack(spacing: 0) {
                HStack {
                    QCYLabel(title: "qcy.firmware.title", hint: "qcy.firmware.hint")
                    Spacer()
                    Text(firmware).monospacedDigit()
                }
                .padding(12)
                Divider()
                HStack {
                    QCYLabel(title: "qcy.address.title", hint: "qcy.address.hint")
                    Spacer()
                    Text(model.address ?? "—").monospacedDigit().foregroundStyle(.secondary)
                }
                .padding(12)
            }
        }
    }

    private var firmware: String {
        guard model.phase == .connected, let version = model.state.firmware else { return "—" }
        return [version.left, version.right].compactMap { $0 }.joined(separator: " / ")
    }
}

private extension Optional where Wrapped == QCYPending {
    var isANC: Bool {
        if case .anc? = self { return true }
        return false
    }
}

// MARK: - Componentes

/// Seção com `glassEffect` no macOS 26+ e `.regularMaterial` antes (DESIGN.md §3.7 e §4).
private struct QCYGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if #available(macOS 26, *) {
            content.frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(shape).glassEffect(.regular, in: shape)
        } else {
            content.frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: shape).clipShape(shape)
        }
    }
}

private struct QCYLabel: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(hint).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Anel de 54 pt por lado. Sem leitura mostra "—" (nunca 0%); carregando mostra um esqueleto.
private struct QCYRing: View {
    let side: LocalizedStringKey
    let level: QCYBatteryLevel?
    let phase: QCYViewModel.Phase

    private var percent: Int? { phase == .connected ? level?.percent : nil }
    private var tint: Color {
        level?.isCharging == true ? Color(light: 0x2B6CB0, dark: 0x63B3ED)
            : BatteryLevel(percent: percent).color
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 6)
                Circle().trim(from: 0, to: CGFloat(percent ?? 0) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(percent.map { "\($0)%" } ?? "—")
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(percent == nil ? .secondary : .primary)
            }
            .frame(width: 54, height: 54)
            VStack(spacing: 1) {
                Text(side).font(.system(size: 12, weight: .medium))
                Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(side))
        .accessibilityValue(percent.map { Text("\($0)%") } ?? Text("qcy.ring.none"))
    }

    private var caption: LocalizedStringKey {
        switch phase {
        case .loading: "qcy.status.reading"
        case .disconnected: "qcy.status.disconnected"
        case .connected:
            if percent == nil {
                "qcy.ring.none"
            } else if level?.isCharging == true {
                "charge.charging"
            } else if BatteryLevel(percent: percent) == .normal {
                "qcy.ring.battery"
            } else {
                "qcy.ring.low"
            }
        }
    }
}

private struct QCYBanner: View {
    let tint: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var spinner = false
    var action: (title: LocalizedStringKey, run: () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if spinner { ProgressView().controlSize(.small) }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            Text(detail).font(.caption).foregroundStyle(.secondary)
            if let action {
                Button(action.title, action: action.run).padding(.top, 6)
            }
        }
        .padding(12).padding(.leading, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
