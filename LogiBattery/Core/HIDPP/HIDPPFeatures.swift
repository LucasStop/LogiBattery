import Foundation

/// Identificadores de feature HID++ 2.0 usados pelo app. Nome segue a tabela do Solaar (hidpp20.py).
enum HIDPPFeatureID {
    static let root: UInt16 = 0x0000
    static let featureSet: UInt16 = 0x0001
    static let deviceName: UInt16 = 0x0005
    static let batteryLevelStatus: UInt16 = 0x1000
    static let batteryVoltage: UInt16 = 0x1001
    static let unifiedBattery: UInt16 = 0x1004
    static let smartShift: UInt16 = 0x2110
    static let adjustableDpi: UInt16 = 0x2201
}

/// Entrada da tabela de features (`0x0001`): o `slot` é o índice usado no byte 2 dos frames,
/// o `id` é o identificador do protocolo e a `version` diz o que o firmware daquele aparelho implementa.
struct HIDPPFeature: Equatable, Sendable {
    let slot: UInt8
    let id: UInt16
    let type: UInt8
    let version: UInt8

    var name: String { HIDPPFeatureCatalog.name(for: id) }
}

/// Tabela completa de um aparelho, na ordem em que o firmware devolve.
struct HIDPPFeatureTable: Equatable, Sendable {
    let entries: [HIDPPFeature]

    func slot(of id: UInt16) -> UInt8? {
        entries.first { $0.id == id }?.slot
    }

    func has(_ id: UInt16) -> Bool { slot(of: id) != nil }

    var ids: Set<UInt16> { Set(entries.map(\.id)) }
}

/// Nomes legíveis das features que aparecem nos aparelhos do projeto. ID fora da lista sai como hex:
/// nome errado é pior que hex, porque sugere capacidade que o firmware pode não ter.
enum HIDPPFeatureCatalog {
    private static let names: [UInt16: String] = [
        0x0000: "Root",
        0x0001: "FeatureSet",
        0x0003: "DeviceFWVersion",
        0x0005: "DeviceName",
        0x0007: "DeviceFriendlyName",
        0x0020: "Reset",
        0x0021: "CryptoID",
        0x00D0: "DFU",
        0x1000: "BatteryLevelStatus",
        0x1001: "BatteryVoltage",
        0x1004: "UnifiedBattery",
        0x1802: "DeviceReset",
        0x1805: "OOBState",
        0x1806: "ConfigDeviceProps",
        0x1814: "ChangeHost",
        0x1815: "HostsInfo",
        0x1981: "Backlight",
        0x1982: "Backlight2",
        0x1B04: "ReprogControlsV4",
        0x1BC0: "ReportHIDUsage",
        0x1D4B: "WirelessDeviceStatus",
        0x1E00: "EnableHiddenFeatures",
        0x2110: "SmartShift",
        0x2111: "SmartShiftEnhanced",
        0x2121: "HiResWheel",
        0x2150: "ThumbWheel",
        0x2200: "MousePointer",
        0x2201: "AdjustableDpi",
        0x2202: "ExtendedAdjustableDpi",
        0x2205: "PointerSpeed",
        0x2250: "XYStats",
        0x2251: "WheelStats",
        0x40A0: "FnInversion",
        0x40A2: "NewFnInversion",
        0x40A3: "K375sFnInversion",
        0x4521: "KeyboardDisableKeys",
        0x4522: "KeyboardDisableByUsage",
        0x4530: "DualPlatform",
        0x4531: "MultiPlatform",
        0x4540: "KeyboardLayout2",
        0x8010: "GKey",
        0x8020: "MKeys",
        0x8030: "MR",
        0x8040: "BrightnessControl",
        0x8060: "ReportRate",
        0x8061: "ExtendedAdjustableReportRate",
        0x8070: "ColorLedEffects",
        0x8071: "RgbEffects",
        0x8080: "PerKeyLighting",
        0x8081: "PerKeyLightingV2",
        0x8100: "OnboardProfiles",
        0x8110: "MouseButtonSpy",
        0x8111: "LatencyMonitoring",
        0x8300: "Sidetone",
        0x8310: "Equalizer"
    ]

    static func name(for id: UInt16) -> String {
        names[id] ?? String(format: "0x%04X", id)
    }
}
