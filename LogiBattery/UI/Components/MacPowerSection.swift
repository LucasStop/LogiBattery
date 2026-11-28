import AppKit
import SwiftUI

/// Seção dedicada de energia do Mac no popover (T15, US-17): fonte de energia, estado detalhado,
/// seletor de Modo de Energia no estilo Central de Controle, Usando energia significativa e Ajustes de Bateria.
struct MacPowerSection: View {
    let viewModel: MacPowerViewModel

    var body: some View {
        if let snapshot = viewModel.snapshot {
            VStack(alignment: .leading, spacing: 0) {
                headerBlock(snapshot)
                Divider()
                energyModeBlock(snapshot)
                Divider()
                significantEnergyBlock
                Divider()
                batterySettingsRow
            }
        }
    }

    private func headerBlock(_ snapshot: MacPowerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("macPower.title")
                .font(.headline)
            HStack(spacing: 4) {
                Text("macPower.source.prefix")
                Text(snapshot.powerSource.labelKey)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            detailText(snapshot.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func detailText(_ detail: MacBatteryDetail) -> Text {
        switch detail {
        case .fullyCharged:
            Text("macPower.detail.fullyCharged")
        case .charging(let minutes?):
            Text("macPower.detail.untilFull \(MacPowerSnapshot.formattedDuration(minutes: minutes))")
        case .charging(nil):
            Text("charge.charging")
        case .discharging(let minutes?):
            Text("macPower.detail.remaining \(MacPowerSnapshot.formattedDuration(minutes: minutes))")
        case .discharging(nil):
            Text("macPower.detail.estimating")
        case .notCharging:
            Text("macPower.detail.notCharging")
        }
    }

    private func energyModeBlock(_ snapshot: MacPowerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("macPower.mode.title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(snapshot.availableModes, id: \.self) { mode in
                    modeButton(mode: mode, isSelected: snapshot.energyMode == mode)
                }
            }
            if viewModel.needsApprovalNotice {
                approvalNotice
            } else if let error = viewModel.switchError {
                Text(verbatim: error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modeButton(mode: EnergyMode, isSelected: Bool) -> some View {
        Button {
            Task { await viewModel.selectMode(mode) }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        .frame(width: 26, height: 26)
                    modeSymbol(mode)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                Text(mode.labelKey)
                    .font(.body.weight(isSelected ? .medium : .regular))
                Spacer()
                if viewModel.isSwitchingMode && isSelected {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSwitchingMode)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func modeSymbol(_ mode: EnergyMode) -> some View {
        if mode.isCustomSymbol {
            Image(mode.symbolName)
        } else {
            Image(systemName: mode.symbolName)
        }
    }

    private var approvalNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("macPower.helper.approval.body")
                .font(.caption)
                .foregroundStyle(.primary)
            Button("macPower.helper.approval.action") {
                viewModel.openApprovalSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.top, 4)
    }

    private var significantEnergyBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("macPower.significant.title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if viewModel.significantItems.isEmpty {
                Text("macPower.significant.none")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.significantItems) { item in
                        significantRow(item)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func significantRow(_ item: SignificantEnergyItem) -> some View {
        switch item {
        case .displayBrightness:
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text("macPower.significant.brightness")
                    .font(.body)
            }
        case .app(let pid, let name, _, _):
            HStack(spacing: 8) {
                if let icon = NSRunningApplication(processIdentifier: pid)?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
                Text(verbatim: name)
                    .font(.body)
                    .lineLimit(1)
            }
        }
    }

    private var batterySettingsRow: some View {
        Button {
            MacPowerActions.openBatterySettings()
        } label: {
            HStack {
                Text("macPower.settings")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Adaptador e Alta Potência") {
    let model = MacPowerViewModel(
        powerReader: PreviewMacPowerReader(snapshot: Sample.macPowerAdapter),
        modeController: PreviewPowerModeController(status: .enabled),
        significantReader: PreviewSignificantEnergyReader(items: [.displayBrightness])
    )
    MacPowerSection(viewModel: model)
        .frame(width: 320)
        .task { model.startPopoverUpdates() }
}
#endif
