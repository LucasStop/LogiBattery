import Foundation
import IOBluetooth
import IOKit
import IOKit.ps

/// Bateria que o próprio macOS já conhece: a do Mac (`IOPowerSources`) e a de qualquer periférico Bluetooth
/// conectado que informe nível por `IORegistry` (`BatteryPercent`, GATT `0x180F` / Apple HID) ou `IOBluetooth` (#88).
enum SystemBatteries {
    private static let bleReader = BLEBatteryReader()

    /// IOBluetooth sem garantia de thread: lê na main, junto da UI. Só a espera do processo filho sai da main (#116).
    @MainActor
    static func read(now: Date) async -> [Device] {
        let paired = await pairedBluetooth(now: now)
        let ble = await bleReader.read().compactMap { bleDevice(name: $0.key, level: $0.value, now: now) }
        return macs(now: now) + DeviceDeduplicator.merge(ioRegistryBluetooth(now: now) + paired + ble)
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

    /// Fone de nível único usa `single`; fone de dois lados sem nível único usa o lado mais fraco.
    /// Zero é "sem dado": sem nível sai com `percent` nil e a lista guarda a última leitura (issue #70).
    static func headset(name: String, single: Int, combined: Int, buds: [Int], now: Date) -> Device {
        let percent = [single, combined].first(where: { $0 > 0 }) ?? buds.filter({ $0 > 0 }).min()
        return Device(id: "bt-audio-\(name)", name: name, kind: .headphones, percent: percent,
                      chargeState: .unknown, path: .bluetooth, readAt: now)
    }

    /// Aparelho pareado e conectado via `IOBluetoothDevice` (áudio ou periférico com nível nas chaves KVC, #88).
    static func bluetoothDevice(name: String, major: UInt32, minor: UInt32 = 0,
                                levels: [Int], now: Date) -> Device? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard DeviceIdentity.isPrintable(trimmed) else { return nil }
        let percent = levels.first(where: { $0 > 0 })
        if major == UInt32(kBluetoothDeviceClassMajorAudio) {
            return Device(id: "bt-audio-\(trimmed)", name: trimmed, kind: .headphones, percent: percent,
                          chargeState: .unknown, path: .bluetooth, readAt: now)
        }
        guard let percent else { return nil }
        let kind = kindFromBluetoothClass(major: major, minor: minor, name: trimmed)
        return Device(id: "bt-dev-\(trimmed)", name: trimmed, kind: kind, percent: percent,
                      chargeState: .unknown, path: .bluetooth, readAt: now)
    }

    /// Periférico Bluetooth no `IORegistry` (`AppleDeviceManagementHIDEventService` / `IOHIDDevice`) com
    /// `BatteryPercent` (Magic Mouse/Keyboard/Trackpad, Keychron, NuPhy, mouses/teclados BLE GATT `0x180F`, #88).
    static func hidBluetoothDevice(properties: [String: Any], now: Date) -> Device? {
        let transport = (properties["Transport"] as? String ?? "").lowercased()
        let isBluetooth = transport.contains("bluetooth")
            || (properties["BluetoothDevice"] as? Bool == true)
            || properties["BD_ADDR"] != nil
        guard isBluetooth,
              let percent = properties["BatteryPercent"] as? Int, (1...100).contains(percent),
              let rawName = properties["Product"] as? String else { return nil }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard DeviceIdentity.isPrintable(name) else { return nil }
        let kind = kindFromHIDProperties(properties, name: name)
        let isCharging = (properties["IsCharging"] as? Bool == true)
            || ((properties["BatteryStatusFlags"] as? Int ?? 0) & 0x02 != 0)
        return Device(id: "bt-hid-\(name)", name: name, kind: kind, percent: percent,
                      chargeState: isCharging ? .charging : .discharging, path: .bluetooth, readAt: now)
    }

    private static func kindFromBluetoothClass(major: UInt32, minor: UInt32, name: String) -> DeviceKind {
        if major == UInt32(kBluetoothDeviceClassMajorAudio) { return .headphones }
        if major == UInt32(kBluetoothDeviceClassMajorPeripheral) {
            switch minor & 0x30 {
            case 0x10, 0x30: return .keyboard
            case 0x20: return .mouse
            default: break
            }
        }
        return DeviceKind(name: name)
    }

    private static func kindFromHIDProperties(_ properties: [String: Any], name: String) -> DeviceKind {
        var pairs: [(page: Int, usage: Int)] = []
        if let page = properties["PrimaryUsagePage"] as? Int, let usage = properties["PrimaryUsage"] as? Int {
            pairs.append((page, usage))
        }
        if let list = properties["DeviceUsagePairs"] as? [[String: Any]] {
            for item in list {
                if let page = item["DeviceUsagePage"] as? Int, let usage = item["DeviceUsage"] as? Int {
                    pairs.append((page, usage))
                }
            }
        }
        if pairs.contains(where: { ($0.page == 0x01 && ($0.usage == 0x06 || $0.usage == 0x07)) }) {
            return .keyboard
        }
        if pairs.contains(where: {
            ($0.page == 0x01 && ($0.usage == 0x01 || $0.usage == 0x02)) || ($0.page == 0x0D && $0.usage == 0x05)
        }) {
            return .mouse
        }
        return DeviceKind(name: name)
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

    private static func ioRegistryBluetooth(now: Date) -> [Device] {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOHIDDevice")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var devices: [Device] = []
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let properties = unmanaged?.takeRetainedValue() as? [String: Any],
                  let device = hidBluetoothDevice(properties: properties, now: now) else { continue }
            devices.append(device)
        }
        return devices
    }

    // ponytail: `batteryPercent*` são chaves privadas do IOBluetoothDevice; se uma versão do macOS tirar, o fone só
    // some da lista. Trocar por API pública quando a Apple abrir uma.
    @MainActor
    private static func pairedBluetooth(now: Date) async -> [Device] {
        var fresh: [String: Int]?
        var devices: [Device] = []
        for case let device as IOBluetoothDevice in IOBluetoothDevice.pairedDevices() ?? [] where device.isConnected() {
            let name = device.name ?? "Bluetooth"
            var levels = kvcLevels(of: device)
            if levels.isEmpty, device.deviceClassMajor == kBluetoothDeviceClassMajorAudio {
                // Depois de reconectar, o processo em execução fica com nível 0 para sempre (#107).
                if fresh == nil { fresh = await levelsFromNewProcess() }
                levels = fresh?[name].map { [$0] } ?? []
            }
            if let paired = bluetoothDevice(name: name, major: UInt32(device.deviceClassMajor),
                                            minor: UInt32(device.deviceClassMinor), levels: levels, now: now) {
                devices.append(paired)
            }
        }
        return devices
    }

    @MainActor
    private static func kvcLevels(of device: IOBluetoothDevice) -> [Int] {
        func level(_ key: String) -> Int {
            guard device.responds(to: NSSelectorFromString(key)) else { return 0 }
            return device.value(forKey: key) as? Int ?? 0
        }
        return [level("batteryPercentSingle"), level("batteryPercentCombined"),
                level("batteryPercentLeft"), level("batteryPercentRight")].filter { $0 > 0 }
    }

    /// Argumento do processo filho que só imprime os níveis e sai.
    static let levelsArgument = "--bluetooth-levels"

    /// Modo filho: uma linha `nome<TAB>nível` por aparelho conectado com nível.
    @MainActor
    static func printLevels() {
        for case let device as IOBluetoothDevice in IOBluetoothDevice.pairedDevices() ?? [] where device.isConnected() {
            guard let level = kvcLevels(of: device).first else { continue }
            print("\(device.name ?? "Bluetooth")\t\(level)")
        }
    }

    static func parseLevels(_ output: String) -> [String: Int] {
        var result: [String: Int] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            if parts.count == 2, let level = Int(parts[1]) { result[String(parts[0])] = level }
        }
        return result
    }

    /// Um processo novo abre uma sessão nova com o Bluetooth e lê o nível atual (ver `printLevels`).
    private static func levelsFromNewProcess() async -> [String: Int] {
        guard let executable = Bundle.main.executableURL else { return [:] }
        return parseLevels(await runLevels(executable: executable, arguments: [levelsArgument], timeout: 5))
    }

    /// Roda o processo numa fila de fundo e devolve o que ele imprimiu; vazio se não abrir ou passar de `timeout`.
    /// A leitura do pipe é síncrona: na main ela travava a UI por até 5 s em todo scan com fone sem nível (#116).
    static func runLevels(executable: URL, arguments: [String], timeout: TimeInterval) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                guard (try? process.run()) != nil else {
                    continuation.resume(returning: "")
                    return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning { process.terminate() }
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: String(bytes: data, encoding: .utf8) ?? "")
            }
        }
    }
}
