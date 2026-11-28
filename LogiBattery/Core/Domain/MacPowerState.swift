import Foundation
import SwiftUI

/// Fonte de energia atual do Mac (US-17).
enum PowerSource: String, Equatable, Sendable {
    case powerAdapter
    case battery

    /// Flag do `pmset` correspondente à fonte atual (`-c` tomada, `-b` bateria).
    var pmsetScope: String {
        switch self {
        case .powerAdapter: "-c"
        case .battery: "-b"
        }
    }

    var labelKey: LocalizedStringKey {
        switch self {
        case .powerAdapter: "macPower.source.adapter"
        case .battery: "macPower.source.battery"
        }
    }
}

/// Estado detalhado da bateria interna do Mac (US-17).
enum MacBatteryDetail: Equatable, Sendable {
    case fullyCharged
    case charging(minutesUntilFull: Int?)
    case discharging(minutesRemaining: Int?)
    case notCharging
}

/// Modo de energia do macOS (`pmset powermode`: 0 Automático, 1 Pouca Energia, 2 Alta Potência).
enum EnergyMode: Int, CaseIterable, Equatable, Sendable {
    case automatic = 0
    case lowPower = 1
    case highPower = 2

    var labelKey: LocalizedStringKey {
        switch self {
        case .automatic: "macPower.mode.automatic"
        case .lowPower: "macPower.mode.lowPower"
        case .highPower: "macPower.mode.highPower"
        }
    }

    var symbolName: String {
        switch self {
        case .automatic: "battery.100percent"
        case .lowPower: "battery.25percent"
        case .highPower: "lb.battery.highpower"
        }
    }

    var isCustomSymbol: Bool {
        self == .highPower
    }

    /// Extrai o modo atual e se o hardware suporta Alta Potência a partir da saída de `pmset -g` e `pmset -g custom`.
    static func parse(pmsetOutput: String, customOutput: String) -> (current: EnergyMode, supportsHighPower: Bool)? {
        if let value = extractInt(named: "powermode", from: pmsetOutput),
           let mode = EnergyMode(rawValue: value) {
            return (mode, true)
        }
        if let value = extractInt(named: "lowpowermode", from: pmsetOutput) {
            let supportsHigh = extractInt(named: "powermode", from: customOutput) != nil
            return (value == 1 ? .lowPower : .automatic, supportsHigh)
        }
        return nil
    }

    private static func extractInt(named key: String, from output: String) -> Int? {
        for rawLine in output.split(separator: "\n") {
            let parts = rawLine.split(whereSeparator: \.isWhitespace)
            if parts.count >= 2, parts[0] == key, let value = Int(parts[1]) {
                return value
            }
        }
        return nil
    }
}

/// Fotografia do estado de energia do Mac (US-17).
struct MacPowerSnapshot: Equatable, Sendable {
    let powerSource: PowerSource
    let detail: MacBatteryDetail
    let energyMode: EnergyMode
    let supportsHighPower: Bool

    var availableModes: [EnergyMode] {
        supportsHighPower ? [.automatic, .lowPower, .highPower] : [.automatic, .lowPower]
    }

    /// Parser puro do dicionário retornado por `IOPSGetPowerSourceDescription`.
    static func parsePowerSource(description: [String: Any]) -> (PowerSource, MacBatteryDetail)? {
        guard description["Type"] as? String == "InternalBattery" else { return nil }
        let rawSource = description["Power Source State"] as? String ?? ""
        let source: PowerSource = rawSource == "Battery Power" ? .battery : .powerAdapter
        let isCharging = description["Is Charging"] as? Bool == true
        let isCharged = description["Is Charged"] as? Bool == true
        let timeToFull = positiveMinutes(description["Time to Full Charge"] as? Int)
        let timeToEmpty = positiveMinutes(description["Time to Empty"] as? Int)

        let detail: MacBatteryDetail
        if isCharging {
            detail = .charging(minutesUntilFull: timeToFull)
        } else if isCharged {
            detail = .fullyCharged
        } else if source == .battery {
            detail = .discharging(minutesRemaining: timeToEmpty)
        } else {
            detail = .notCharging
        }
        return (source, detail)
    }

    private static func positiveMinutes(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    /// Formata minutos como "H:MM" (ex.: 402 -> "6:42").
    static func formattedDuration(minutes: Int) -> String {
        let clamped = max(minutes, 0)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

/// Item listado em "Usando energia significativa" (US-17).
enum SignificantEnergyItem: Identifiable, Equatable, Sendable {
    case displayBrightness
    case app(pid: Int32, name: String, bundleIdentifier: String?, score: Double)

    var id: String {
        switch self {
        case .displayBrightness: "display-brightness"
        case .app(let pid, _, _, _): "app-\(pid)"
        }
    }
}

/// Amostra bruta de uso de CPU e wakeups de um processo de aplicativo.
struct ProcessEnergySample: Equatable, Sendable {
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let cpuTimeNs: UInt64
    let wakeups: UInt64
}

/// Cálculo puro de impacto energético por delta entre duas amostras consecutivas.
enum ProcessEnergyCalculator {
    static let defaultCPUThresholdPercent = 15.0
    static let defaultBrightnessThreshold: Float = 0.75
    static let defaultMaxApps = 5

    static func significantApps(
        previous: [Int32: ProcessEnergySample],
        current: [ProcessEnergySample],
        elapsedSeconds: Double,
        cpuThresholdPercent: Double = defaultCPUThresholdPercent,
        maxCount: Int = defaultMaxApps
    ) -> [SignificantEnergyItem] {
        guard elapsedSeconds > 0 else { return [] }
        let elapsedNs = elapsedSeconds * 1_000_000_000
        var scored: [(ProcessEnergySample, Double)] = []
        for sample in current {
            guard let prev = previous[sample.pid],
                  sample.cpuTimeNs >= prev.cpuTimeNs else { continue }
            let deltaCpu = Double(sample.cpuTimeNs - prev.cpuTimeNs)
            let cpuPercent = (deltaCpu / elapsedNs) * 100.0
            let deltaWakeups = sample.wakeups >= prev.wakeups ? Double(sample.wakeups - prev.wakeups) : 0
            let wakeupBonus = (deltaWakeups / elapsedSeconds) * 0.01
            let score = cpuPercent + wakeupBonus
            if score >= cpuThresholdPercent {
                scored.append((sample, score))
            }
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(maxCount)
            .map { .app(pid: $0.0.pid, name: $0.0.name, bundleIdentifier: $0.0.bundleIdentifier, score: $0.1) }
    }
}

/// Estado do helper privilegiado (`SMAppService.daemon`, ADR 0009).
enum PowerHelperStatus: Equatable, Sendable {
    case enabled
    case requiresApproval
    case notRegistered
    case unavailable
}

protocol MacPowerReading: Sendable {
    func read() async -> MacPowerSnapshot?
}

protocol PowerModeControlling: Sendable {
    func status() -> PowerHelperStatus
    func register() throws -> PowerHelperStatus
    func setPowerMode(_ mode: EnergyMode, scope: String) async throws
    @MainActor func openApprovalSettings()
}

protocol SignificantEnergyReading: Sendable {
    func sample() async -> [SignificantEnergyItem]
    func reset() async
}
