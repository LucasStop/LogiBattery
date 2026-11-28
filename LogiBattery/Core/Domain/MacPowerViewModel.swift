import Foundation
import Observation

/// Estado e ações da seção nativa de energia do Mac no popover (US-17).
@MainActor
@Observable
final class MacPowerViewModel {
    private(set) var snapshot: MacPowerSnapshot?
    private(set) var significantItems: [SignificantEnergyItem] = []
    private(set) var helperStatus: PowerHelperStatus
    private(set) var isSwitchingMode = false
    private(set) var needsApprovalNotice = false
    private(set) var switchError: String?

    @ObservationIgnored private let powerReader: any MacPowerReading
    @ObservationIgnored private let modeController: any PowerModeControlling
    @ObservationIgnored private let significantReader: any SignificantEnergyReading
    @ObservationIgnored private let sampleInterval: Duration
    @ObservationIgnored private var samplingTask: Task<Void, Never>?

    init(
        powerReader: any MacPowerReading,
        modeController: any PowerModeControlling,
        significantReader: any SignificantEnergyReading,
        sampleInterval: Duration = .seconds(3)
    ) {
        self.powerReader = powerReader
        self.modeController = modeController
        self.significantReader = significantReader
        self.sampleInterval = sampleInterval
        self.helperStatus = modeController.status()
    }

    func refresh() async {
        helperStatus = modeController.status()
        if helperStatus == .enabled {
            needsApprovalNotice = false
        }
        snapshot = await powerReader.read()
    }

    /// Inicia amostragem de brilho e apps enquanto o popover está visível (meta CPU ociosa < 1%).
    func startPopoverUpdates() {
        stopPopoverUpdates()
        samplingTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            await self.significantReader.reset()
            // Primeira amostra captura baseline de CPU + brilho imediato.
            self.significantItems = await self.significantReader.sample()
            while !Task.isCancelled {
                try? await Task.sleep(for: self.sampleInterval)
                if Task.isCancelled { break }
                self.snapshot = await self.powerReader.read()
                self.significantItems = await self.significantReader.sample()
            }
        }
    }

    func stopPopoverUpdates() {
        samplingTask?.cancel()
        samplingTask = nil
    }

    func selectMode(_ mode: EnergyMode) async {
        guard let current = snapshot, current.energyMode != mode, !isSwitchingMode else { return }
        switchError = nil
        helperStatus = modeController.status()
        if helperStatus != .enabled {
            do {
                helperStatus = try modeController.register()
            } catch {
                switchError = error.localizedDescription
                return
            }
            if helperStatus != .enabled {
                needsApprovalNotice = true
                return
            }
        }
        needsApprovalNotice = false
        isSwitchingMode = true
        defer { isSwitchingMode = false }
        do {
            try await modeController.setPowerMode(mode, scope: current.powerSource.pmsetScope)
            if let updated = await powerReader.read() {
                snapshot = updated
            } else {
                snapshot = MacPowerSnapshot(
                    powerSource: current.powerSource,
                    detail: current.detail,
                    energyMode: mode,
                    supportsHighPower: current.supportsHighPower
                )
            }
        } catch {
            switchError = error.localizedDescription
        }
    }

    func openApprovalSettings() {
        modeController.openApprovalSettings()
    }
}
