import Foundation
import IOBluetooth
import IOKit.ps

/// Bateria que o próprio macOS já conhece: a do Mac (`IOPowerSources`) e a de fone Bluetooth (`IOBluetooth`).
enum SystemBatteries {
    /// IOBluetooth sem garantia de thread: lê na main, junto da UI.
    @MainActor
    static func read(now: Date) -> [Device] {
        macs(now: now) + headsets(now: now)
    }

    /// Dicionário de `IOPSGetPowerSourceDescription`; só a bateria interna (no-break e afins ficam de fora).
    static func mac(description: [String: Any], name: String, now: Date) -> Device? {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 else { return nil }
        let state: ChargeState
        if description[kIOPSIsChargingKey] as? Bool == true {
            state = .charging
        } else if description[kIOPSIsChargedKey] as? Bool == true {
            state = .full
        } else {
            state = .discharging
        }
        return Device(id: "mac-internal", name: name, kind: .laptop, percent: current * 100 / max,
                      chargeState: state, path: .internal, readAt: now)
    }

    /// Fone de nível único usa `single`; fone de dois lados sem nível único usa o lado mais fraco. Zero é "sem dado".
    static func headset(name: String, single: Int, combined: Int, buds: [Int], now: Date) -> Device? {
        guard let percent = [single, combined].first(where: { $0 > 0 }) ?? buds.filter({ $0 > 0 }).min()
        else { return nil }
        return Device(id: "bt-audio-\(name)", name: name, kind: .headphones, percent: percent,
                      chargeState: .unknown, path: .bluetooth, readAt: now)
    }

    private static func macs(now: Date) -> [Device] {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else { return [] }
        let name = Host.current().localizedName ?? "Mac"
        return sources.compactMap { source in
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
                as? [String: Any] else { return nil }
            return mac(description: description, name: name, now: now)
        }
    }

    // ponytail: `batteryPercent*` são chaves privadas do IOBluetoothDevice; se uma versão do macOS tirar, o fone só
    // some da lista. Trocar por API pública quando a Apple abrir uma.
    @MainActor
    private static func headsets(now: Date) -> [Device] {
        (IOBluetoothDevice.pairedDevices() ?? []).compactMap { item in
            guard let device = item as? IOBluetoothDevice, device.isConnected(),
                  device.deviceClassMajor == BluetoothDeviceClassMajor(kBluetoothDeviceClassMajorAudio)
            else { return nil }
            func level(_ key: String) -> Int {
                guard device.responds(to: NSSelectorFromString(key)) else { return 0 }
                return device.value(forKey: key) as? Int ?? 0
            }
            return headset(name: device.name ?? "Bluetooth", single: level("batteryPercentSingle"),
                           combined: level("batteryPercentCombined"),
                           buds: [level("batteryPercentLeft"), level("batteryPercentRight")], now: now)
        }
    }
}
