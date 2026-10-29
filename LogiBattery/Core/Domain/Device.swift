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

enum DevicePath: String, Codable, Equatable, Sendable {
    case receiver, bluetooth
}

extension DevicePath {
    var labelKey: LocalizedStringKey {
        switch self {
        case .receiver: "path.receiver"
        case .bluetooth: "path.bluetooth"
        }
    }
}

enum DeviceKind: String, Codable, Equatable, Sendable {
    case mouse, keyboard, other

    // ponytail: o tipo vem do nome; a feature DeviceName (função 2) dá o tipo exato quando o nome enganar.
    private static let keyboardHints = ["key", "tkl", "k380", "k780"]
    private static let mouseHints = ["mouse", "master", "mx anywhere", "g502", "g pro", "pebble m"]

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
}

struct DeviceReading: Equatable, Sendable {
    let name: String
    let percent: Int
    let chargeState: ChargeState
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

enum BatteryLevel: Equatable, Sendable {
    case normal, low, critical, unknown

    // ponytail: limites fixos 20% e 10% (padrão do PRD); passam a vir dos ajustes na US-11.
    init(percent: Int?) {
        switch percent {
        case nil: self = .unknown
        case let value? where value < 10: self = .critical
        case let value? where value < 20: self = .low
        default: self = .normal
        }
    }
}
