import CoreBluetooth
import Foundation

/// Bateria de qualquer teclado ou mouse BLE que exponha o Battery Service padrão (GATT `0x180F`, característica
/// `0x2A19`), de qualquer marca. É de onde o macOS tira o nível que mostra em Ajustes > Bluetooth (#121).
final class BLEBatteryReader: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {
    private let service = CBUUID(string: "180F")
    private let characteristic = CBUUID(string: "2A19")
    private static let timeout: TimeInterval = 4

    /// Tudo abaixo só é tocado nesta fila (é também a fila do `CBCentralManager`).
    private let queue = DispatchQueue(label: "com.lucasstop.LogiBattery.ble")
    private var manager: CBCentralManager?
    private var held: [UUID: CBPeripheral] = [:]
    private var pending = Set<UUID>()
    private var levels: [String: Int] = [:]
    private var continuation: CheckedContinuation<[String: Int], Never>?

    /// Nome -> nível dos periféricos conectados com Battery Service; vazio sem permissão, Bluetooth ou resposta.
    func read() async -> [String: Int] {
        await withCheckedContinuation { continuation in
            queue.async { self.begin(continuation) }
        }
    }

    private func begin(_ continuation: CheckedContinuation<[String: Int], Never>) {
        guard self.continuation == nil else { return continuation.resume(returning: [:]) }
        self.continuation = continuation
        levels = [:]
        pending = []
        queue.asyncAfter(deadline: .now() + Self.timeout) { self.finish() }
        if let manager, manager.state == .poweredOn {
            start(manager)
        } else if manager == nil {
            manager = CBCentralManager(delegate: self, queue: queue)
        }
    }

    private func start(_ manager: CBCentralManager) {
        for peripheral in manager.retrieveConnectedPeripherals(withServices: [service]) {
            held[peripheral.identifier] = peripheral
            peripheral.delegate = self
            pending.insert(peripheral.identifier)
            if peripheral.state == .connected {
                peripheral.discoverServices([service])
            } else {
                manager.connect(peripheral)
            }
        }
        if pending.isEmpty { finish() }
    }

    private func finish() {
        guard let continuation else { return }
        self.continuation = nil
        pending = []
        continuation.resume(returning: levels)
    }

    private func done(_ peripheral: CBPeripheral) {
        pending.remove(peripheral.identifier)
        if pending.isEmpty { finish() }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            finish()
        } else if continuation != nil {
            start(central)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        done(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == service }) else {
            return done(peripheral)
        }
        peripheral.discoverCharacteristics([characteristic], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristic }) else {
            return done(peripheral)
        }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let name = peripheral.name, let level = characteristic.value?.first { levels[name] = Int(level) }
        done(peripheral)
    }
}

extension SystemBatteries {
    /// Leitura pelo Battery Service BLE. Mesmo id `bt-*` das outras leituras do sistema: HID++ do mesmo aparelho vence
    /// no `DeviceDeduplicator`. Fora de 1...100 é "sem dado".
    static func bleDevice(name: String, level: Int, now: Date) -> Device? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard DeviceIdentity.isPrintable(trimmed), (1...100).contains(level) else { return nil }
        return Device(id: "bt-ble-\(trimmed)", name: trimmed, kind: DeviceKind(name: trimmed), percent: level,
                      chargeState: .unknown, path: .bluetooth, readAt: now)
    }
}
