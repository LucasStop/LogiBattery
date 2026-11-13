import CoreBluetooth
import Foundation

/// Cliente do canal de controle do fone QCY: escaneia por manufacturer data `0x521C`, conecta no serviço `A001`,
/// assina `00001002` (notificações) e lê `00000008` (bateria) e `00000007` (versão).
///
/// Lê o retrato e escreve os ajustes medidos (cena de ANC, LDAC e modo jogo). O fone aceita a conexão GATT com o
/// áudio A2DP ativo (medido em 2026-11-12), então o app não precisa derrubar o áudio para ler a bateria. Os
/// callbacks rodam na fila interna do cliente.
final class QCYClient: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {
    /// `CBUUID` não é `Sendable`, então as constantes ficam por instância (mesmo padrão do `BLEBatteryReader`).
    private let service = CBUUID(string: "A001")
    private let commandCharacteristic = CBUUID(string: "1001")
    private let notifyCharacteristic = CBUUID(string: "1002")
    private let batteryCharacteristic = CBUUID(string: "0008")
    private let versionCharacteristic = CBUUID(string: "0007")

    /// Chamado quando um advertising QCY aparece (com bateria e MACs já decodificados).
    var onAdvertisement: (@Sendable (QCYAdvertisement) -> Void)?
    /// Chamado quando o estado muda por notificação ou leitura de característica.
    var onState: (@Sendable (QCYState) -> Void)?
    /// Chamado uma vez por conexão, quando as características já foram descobertas (é quando dá para escrever).
    var onReady: (@Sendable () -> Void)?
    /// Chamado quando o link cai, limpo ou com erro. O cliente volta a escanear sozinho.
    var onDisconnect: (@Sendable () -> Void)?
    /// Bytes crus de cada notificação de `00001002`, para diagnóstico e para virar fixture.
    var onPacket: (@Sendable (Data) -> Void)?
    /// Falha de conexão, serviço ausente ou erro do CoreBluetooth.
    var onFailure: (@Sendable (String) -> Void)?

    private let queue = DispatchQueue(label: "com.lucasstop.LogiBattery.qcy")
    private var manager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var state = QCYState()
    private var isRunning = false

    /// Começa a escanear. Sem permissão de Bluetooth o `CBCentralManager` fica em `.unauthorized` e nada acontece.
    func start() {
        queue.async { self.begin() }
    }

    func stop() {
        queue.async {
            self.isRunning = false
            self.manager?.stopScan()
            if let peripheral = self.peripheral {
                self.manager?.cancelPeripheralConnection(peripheral)
            }
            self.peripheral = nil
        }
    }

    /// Pede de novo o retrato (bateria, cena, LDAC e jogo) sem derrubar a conexão.
    func refresh() {
        queue.async {
            guard let peripheral = self.peripheral else { return }
            self.requestState(peripheral)
        }
    }

    /// Escreve um pacote em `00001001`. Só é chamado por quem já decidiu escrever (modo, jogo, LDAC).
    func send(_ packet: QCYPacket) {
        queue.async {
            guard let peripheral = self.peripheral,
                  let characteristic = self.characteristic(self.commandCharacteristic, of: peripheral)
            else { return }
            // No MeloBuds Pro a `1001` só anuncia escrita sem resposta (props 4).
            let canWait = characteristic.properties.contains(.write)
            peripheral.writeValue(packet.encoded(), for: characteristic,
                                  type: canWait ? .withResponse : .withoutResponse)
        }
    }

    /// Pede o valor atual dos comandos de estado. É leitura (`0xFE`), não muda ajuste nenhum.
    private func requestState(_ peripheral: CBPeripheral) {
        let commands: [QCYCommand] = [.battery, .noiseCancelMode, .ancSetting, .ldac, .lowLatency]
        send(QCYPacket(commands.map { QCYPacket.Block(command: QCYCommand.requestData.rawValue,
                                                      parameters: [$0.rawValue]) }))
    }

    private func begin() {
        guard !isRunning else { return }
        isRunning = true
        if let manager, manager.state == .poweredOn {
            scan(manager)
        } else if manager == nil {
            manager = CBCentralManager(delegate: self, queue: queue)
        }
    }

    /// O advertising do QCY não traz UUID de serviço, só manufacturer data — filtrar por serviço não acharia o
    /// fone. O filtro é o company id, como no documento do protocolo. Antes de escanear, aproveita o link GATT que
    /// o macOS já mantém aberto: periférico conectado não anuncia, e era o caso do fone com áudio ativo.
    private func scan(_ manager: CBCentralManager) {
        guard isRunning else { return }
        let connected = manager.retrieveConnectedPeripherals(withServices: [service])
        if connected.contains(where: { attach($0) }) { return }
        manager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    /// Devolve `false` se já havia um periférico em uso.
    @discardableResult
    private func attach(_ peripheral: CBPeripheral) -> Bool {
        guard self.peripheral == nil else { return false }
        self.peripheral = peripheral
        // Nova conexão, retrato novo: sem o reset o estado antigo sobrevive a um link caído.
        state = QCYState()
        peripheral.delegate = self
        if peripheral.state == .connected {
            peripheral.discoverServices([service])
        } else {
            manager?.connect(peripheral)
        }
        return true
    }

    private func characteristic(_ uuid: CBUUID, of peripheral: CBPeripheral) -> CBCharacteristic? {
        peripheral.services?
            .flatMap { $0.characteristics ?? [] }
            .first { $0.uuid == uuid }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if isRunning { scan(central) }
        case .unauthorized:
            onFailure?("Bluetooth sem permissão")
        case .unsupported:
            onFailure?("Bluetooth indisponível nesta máquina")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard isRunning, self.peripheral == nil,
              let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              let advertisement = QCYAdvertisement(manufacturerData: data)
        else { return }
        onAdvertisement?(advertisement)
        central.stopScan()
        attach(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onFailure?("não conectou: \(error?.localizedDescription ?? "sem motivo informado")")
        self.peripheral = nil
        scan(central)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        state = QCYState()
        onDisconnect?()
        if error != nil { onFailure?("desconectou: \(error?.localizedDescription ?? "sem motivo informado")") }
        scan(central)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let main = peripheral.services?.first(where: { $0.uuid == service }) else {
            onFailure?("serviço A001 ausente")
            manager?.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.discoverCharacteristics(nil, for: main)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // A assinatura de `00001002` entrega o que muda; `0008` também notifica bateria. As leituras e o pedido
        // de estado cobrem o caso de o firmware ficar calado até alguém perguntar.
        for uuid in [notifyCharacteristic, batteryCharacteristic] {
            if let characteristic = characteristic(uuid, of: peripheral) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        for uuid in [batteryCharacteristic, versionCharacteristic] {
            if let characteristic = characteristic(uuid, of: peripheral) {
                peripheral.readValue(for: characteristic)
            }
        }
        requestState(peripheral)
        onReady?()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        if characteristic.uuid == notifyCharacteristic {
            onPacket?(data)
            guard let packet = QCYPacket(data: data) else { return }
            state.apply(packet)
        } else if characteristic.uuid == batteryCharacteristic {
            state.apply(QCYPacket.Block(command: QCYCommand.battery.rawValue, parameters: Array(data)))
        } else if characteristic.uuid == versionCharacteristic {
            state.apply(QCYPacket.Block(command: QCYCommand.version.rawValue, parameters: Array(data)))
        } else {
            return
        }
        onState?(state)
    }
}
