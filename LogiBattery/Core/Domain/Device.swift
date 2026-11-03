import Foundation
import SwiftUI

enum ChargeState: String, Codable, Equatable, Sendable {
    case discharging, charging, full, unknown

    /// Status da feature `0x1004`: 0 descarregando, 1 e 2 carregando, 3 carga completa.
    init(unifiedBatteryStatus status: UInt8) {
        switch status {
        case 0: self = .discharging
        case 1, 2: self = .charging
        case 3: self = .full
        default: self = .unknown
        }
    }

    /// Status da feature `0x1000` (`BatteryUnifiedLevelStatus`): 0 descarregando, 1..3 carregando, 4 cheio (#89).
    init(batteryLevelStatus status: UInt8) {
        switch status {
        case 0: self = .discharging
        case 1, 2, 3: self = .charging
        case 4: self = .full
        default: self = .unknown
        }
    }

    /// Flags da feature `0x1001` (`BatteryVoltage`): bit `0x80` em carga, `flags & 0x07 == 2` carga completa (#89).
    init(voltageFlags flags: UInt8) {
        guard flags & 0x80 != 0 else {
            self = .discharging
            return
        }
        self = (flags & 0x07 == 2) ? .full : .charging
    }
}

extension ChargeState {
    /// Chave em `Localizable.xcstrings`; descarregando não tem texto (é o estado normal).
    var labelKey: LocalizedStringKey? {
        switch self {
        case .charging: "charge.charging"
        case .full: "charge.full"
        case .discharging, .unknown: nil
        }
    }
}

/// Por onde o app leu a bateria; `internal` é a bateria do próprio Mac.
enum DevicePath: String, Codable, Equatable, Sendable {
    case receiver, bluetooth, `internal`
}

extension DevicePath {
    var labelKey: LocalizedStringKey {
        switch self {
        case .receiver: "path.receiver"
        case .bluetooth: "path.bluetooth"
        case .internal: "path.internal"
        }
    }
}

enum DeviceKind: String, Codable, Equatable, Sendable {
    case mouse, keyboard, laptop, headphones, other

    private static let keyboardHints = ["key", "tkl", "k380", "k780", "nuphy", "keychron"]
    private static let mouseHints = ["mouse", "master", "mx anywhere", "g502", "g pro", "pebble m", "trackpad", "ergo"]

    init(name: String) {
        let lower = name.lowercased()
        if Self.keyboardHints.contains(where: lower.contains) {
            self = .keyboard
        } else if Self.mouseHints.contains(where: lower.contains) {
            self = .mouse
        } else {
            self = .other
        }
    }

    /// Tipo informado pela feature HID++ `0x0005` (`getDeviceType`, função 2, #89); cai no nome se desconhecido.
    init(hidppType: UInt8?, name: String) {
        switch hidppType {
        case 0, 1, 2: self = .keyboard
        case 3, 4, 5, 6: self = .mouse
        case 8: self = .headphones
        default: self.init(name: name)
        }
    }
}

struct DeviceReading: Equatable, Sendable {
    private static let minMillivolts = 3_500
    private static let maxMillivolts = 4_200

    let name: String
    let percent: Int
    let chargeState: ChargeState
    var kind: DeviceKind?

    /// Curva linear LiPo padrão (3500..4200 mV -> 0..100%) para aparelhos que só expõem `0x1001` (#89).
    static func percent(fromMillivolts millivolts: Int) -> Int {
        let clamped = min(max(millivolts, minMillivolts), maxMillivolts)
        return (clamped - minMillivolts) * 100 / (maxMillivolts - minMillivolts)
    }
}

struct Device: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let kind: DeviceKind
    let percent: Int?
    let chargeState: ChargeState
    let path: DevicePath
    let readAt: Date

    /// `readAt` vai como `updatedAt` no `snapshot.json` (docs/API.md).
    enum CodingKeys: String, CodingKey {
        case id, name, kind, percent, chargeState, path
        case readAt = "updatedAt"
    }
}

/// Identidade estável do aparelho entre receptor e Bluetooth: o id muda a cada reconexão, o nome não.
enum DeviceIdentity {
    static func key(_ name: String) -> String {
        name.lowercased().split(separator: " ").joined(separator: " ")
    }

    static func isPrintable(_ name: String) -> Bool {
        !name.isEmpty && name.unicodeScalars.allSatisfy {
            $0.value >= 0x20 && $0.value != 0x7F && $0.value != 0xFFFD
        }
    }
}

extension Device {
    var identity: String { DeviceIdentity.key(name) }

    /// Leitura mantida de aparelho que dorme ou saiu de alcance; widget e popover mostram em cinza (DESIGN.md).
    func isOld(at date: Date) -> Bool {
        date.timeIntervalSince(readAt) > Snapshot.staleAfter
    }
}

/// Limites de nível dos Ajustes (US-11). Vão no snapshot porque o widget não lê os ajustes do app.
struct BatteryThresholds: Codable, Equatable, Sendable {
    var low = 20
    var critical = 10
}

enum BatteryLevel: Equatable, Sendable {
    case normal, low, critical, unknown

    init(percent: Int?, thresholds: BatteryThresholds = BatteryThresholds()) {
        switch percent {
        case nil: self = .unknown
        case let value? where value < thresholds.critical: self = .critical
        case let value? where value < thresholds.low: self = .low
        default: self = .normal
        }
    }
}
