import SwiftUI

/// Popover da barra de menu (T04, direção B, #66): faixa de anéis no topo, lista embaixo e seções em vidro
/// (`glassEffect` no macOS 26+, `.regularMaterial` antes).
struct DeviceList: View {
    let viewModel: DeviceListViewModel
    let permission: PermissionModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsModel.popoverWidthKey) private var popoverWidth = SettingsModel.defaultPopoverWidth

    private var thresholds: BatteryThresholds { SettingsModel.shared.values.thresholds }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if permission.needsAttention {
                PopoverSection { PermissionBanner(model: permission) }
            }
            if viewModel.devices.isEmpty {
                if viewModel.hasLoaded {
                    PopoverSection {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("popover.empty.title").font(.headline)
                            Text("popover.empty.body").font(.callout).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    PopoverSection {
                        PopoverRingStrip(devices: [], thresholds: thresholds, isLoading: true)
                    }
                }
            } else {
                PopoverSection {
                    PopoverRingStrip(devices: viewModel.devices, thresholds: thresholds, isLoading: false,
                                     isGray: viewModel.isGray)
                }
                PopoverSection {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.devices.enumerated()), id: \.element.id) { index, device in
                            if index > 0 { Divider() }
                            DeviceRow(device: device, gray: viewModel.isGray(device))
                                .contextMenu {
                                    if viewModel.canForget(device) {
                                        Button("popover.forget \(device.name)") { viewModel.forget(device) }
                                    }
                                }
                        }
                    }
                }
            }
            if let forgotten = viewModel.forgotten {
                PopoverSection {
                    HStack {
                        Text("popover.forgotten \(forgotten.name)").font(.callout).lineLimit(1)
                        Spacer()
                        Button("popover.undo") { viewModel.undoForget() }.buttonStyle(.link)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .task(id: forgotten.id) {
                    try? await Task.sleep(for: .seconds(8))
                    if !Task.isCancelled { viewModel.dismissForgotten() }
                }
            }
            PopoverSection {
                VStack(spacing: 0) {
                    actionRow("popover.history", chevron: true) {
                        openWindow(id: "history")
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                    Divider()
                    actionRow("popover.settings", chevron: true) {
                        openWindow(id: "settings")
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                    Divider()
                    actionRow("popover.quit", chevron: false) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
        .padding(8)
        .frame(width: CGFloat(SettingsModel.normalizedPopoverWidth(popoverWidth)))
        .task {
            permission.refresh()
            await viewModel.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("app.name").font(.headline)
            Spacer()
            Group {
                if permission.needsAttention {
                    Text("popover.permission.status")
                } else if !viewModel.hasLoaded && viewModel.devices.isEmpty {
                    Text("popover.reading")
                } else if let date = viewModel.lastRefresh, !viewModel.devices.isEmpty {
                    HStack(spacing: 3) {
                        Text("popover.updated")
                        Text(date, format: .relative(presentation: .named))
                    }
                } else {
                    Text("popover.empty.status")
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private func actionRow(_ title: LocalizedStringKey, chevron: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Seção do popover com `glassEffect` no macOS 26+ e `.regularMaterial` antes (DESIGN.md §3.7 e §4, #66).
private struct PopoverSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if #available(macOS 26, *) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: shape)
                .clipShape(shape)
        }
    }
}

/// Faixa de 4 anéis no topo do popover (DESIGN.md §4, direção B da #66). Oculta do VoiceOver porque a lista logo
/// abaixo já descreve cada aparelho.
private struct PopoverRingStrip: View {
    static let slots = 4
    private static let ringSize: CGFloat = 56
    private static let stroke: CGFloat = 6
    private static let iconSize: CGFloat = 22
    private static let percentSize: CGFloat = 15

    let devices: [Device]
    let thresholds: BatteryThresholds
    let isLoading: Bool
    var isGray: (Device) -> Bool = { _ in false }

    var body: some View {
        let filled = devices.prefix(Self.slots).map { Optional($0) }
        let slots = filled + Array(repeating: nil, count: Self.slots - filled.count)
        HStack(spacing: 0) {
            ForEach(0..<Self.slots, id: \.self) { index in
                slotView(slots[index])
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .accessibilityHidden(true)
    }

    private func slotView(_ device: Device?) -> some View {
        let gray = device.map(isGray) == true
        let fraction = CGFloat(min(max(device?.percent ?? 0, 0), 100)) / 100
        return VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: Self.stroke)
                if let device, !isLoading {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(gray ? .secondary : device.tint(thresholds),
                                style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    // `.font` explícito obrigatório para símbolos `lb.*` desenharem no MenuBarExtra (#77).
                    device.symbol
                        .font(.system(size: Self.iconSize))
                        .foregroundStyle(gray ? .secondary : .primary)
                }
            }
            .padding(Self.stroke / 2)
            .frame(width: Self.ringSize, height: Self.ringSize)

            if isLoading {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 34, height: 13)
                    .padding(.vertical, 2)
            } else {
                Text(device?.percent.map { "\($0)%" } ?? "—")
                    .font(.system(size: Self.percentSize, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(gray ? .secondary : .primary)
                    .opacity(device == nil ? 0 : 1)
            }
        }
    }
}
