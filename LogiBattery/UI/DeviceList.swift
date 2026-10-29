import SwiftUI

/// Popover da barra de menu (T04). Login entra com a US-10.
struct DeviceList: View {
    let viewModel: DeviceListViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if viewModel.devices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.hasLoaded ? "popover.empty.title" : "popover.reading").font(.headline)
                    if viewModel.hasLoaded {
                        Text("popover.empty.body").font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(viewModel.devices) { DeviceRow(device: $0) }
            Divider()
            HStack {
                Button("popover.history") {
                    openWindow(id: "history")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                Button("popover.settings") {
                    openWindow(id: "settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("popover.quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 320)
        .task { await viewModel.refresh() }
    }

    private var header: some View {
        HStack {
            Text("app.name").font(.headline)
            Spacer()
            if let date = viewModel.lastRefresh {
                HStack(spacing: 3) {
                    Text("popover.updated")
                    Text(date, format: .relative(presentation: .named))
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
