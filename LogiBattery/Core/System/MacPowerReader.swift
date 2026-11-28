import Foundation
import IOKit.ps

/// Leitor de energia do Mac via `IOPowerSources` e `pmset` (US-17).
struct MacPowerReader: MacPowerReading {
    func read() async -> MacPowerSnapshot? {
        guard let (source, detail) = readPowerSource() else { return nil }
        let (mode, supportsHighPower) = await readEnergyMode()
        return MacPowerSnapshot(
            powerSource: source,
            detail: detail,
            energyMode: mode,
            supportsHighPower: supportsHighPower
        )
    }

    private func readPowerSource() -> (PowerSource, MacBatteryDetail)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
                as? [String: Any],
                  let parsed = MacPowerSnapshot.parsePowerSource(description: description) else { continue }
            return parsed
        }
        return nil
    }

    private func readEnergyMode() async -> (EnergyMode, Bool) {
        let pmsetURL = URL(fileURLWithPath: "/usr/bin/pmset")
        async let currentOutput = SystemBatteries.runLevels(executable: pmsetURL, arguments: ["-g"], timeout: 3)
        async let customOutput = SystemBatteries.runLevels(
            executable: pmsetURL, arguments: ["-g", "custom"], timeout: 3
        )
        let current = await currentOutput
        let custom = await customOutput
        if let parsed = EnergyMode.parse(pmsetOutput: current, customOutput: custom) {
            return parsed
        }
        let fallback: EnergyMode = ProcessInfo.processInfo.isLowPowerModeEnabled ? .lowPower : .automatic
        return (fallback, false)
    }
}
