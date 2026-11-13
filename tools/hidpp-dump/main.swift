// Dump HID++ 2.0 de features (somente leitura) dos aparelhos Logitech conectados.
// Uso: swiftc -O tools/hidpp-dump/main.swift LogiBattery/Core/HIDPP/HIDPPFeatures.swift \
//        -o /tmp/hidpp-dump && /tmp/hidpp-dump
// Fixture: HIDPP_RECORD=Tests/Fixtures/hidpp/<nome>.txt grava '> pedido' / '< resposta' no formato dos testes.
// Não loga série nem nome do usuário.
import Foundation
import IOKit.hid

let hex: ([UInt8]) -> String = { $0.map { String(format: "%02x", $0) }.joined(separator: " ") }

/// Um `IOHIDDevice` aberto com buffer de report próprio, agendado uma vez no run loop atual.
final class Channel {
    let device: IOHIDDevice
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private var reports: [[UInt8]] = []

    init(device: IOHIDDevice) {
        self.device = device
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { context, _, _, _, _, report, length in
            guard let context else { return }
            let channel = Unmanaged<Channel>.fromOpaque(context).takeUnretainedValue()
            channel.reports.append(Array(UnsafeBufferPointer(start: report, count: length)))
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit { buffer.deallocate() }

    func send(_ frame: [UInt8], wait: TimeInterval = 1.6) -> [UInt8]? {
        reports.removeAll()
        let status = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(frame[0]), frame, frame.count)
        guard status == kIOReturnSuccess else {
            print("    SetReport falhou: \(String(status, radix: 16))")
            return nil
        }
        let matches: ([UInt8]) -> Bool = { $0.count > 3 && $0[1] == frame[1] && $0[2] == frame[2] && $0[3] == frame[3] }
        // Erro do HID++ 1.0 (`10 índice 8F`) é slot sem aparelho: esperar o timeout inteiro só atrasa o dump.
        let rejected: ([UInt8]) -> Bool = { $0.count > 2 && $0[0] == 0x10 && $0[1] == frame[1] && $0[2] == 0x8F }
        let deadline = Date().addingTimeInterval(wait)
        while Date() < deadline, !reports.contains(where: matches), !reports.contains(where: rejected) {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        return reports.first(where: matches)
    }
}

func long(_ index: UInt8, _ feature: UInt8, _ function: UInt8, _ params: [UInt8] = []) -> [UInt8] {
    var frame: [UInt8] = [0x11, index, feature, (function << 4) | 0x1] + params
    frame += [UInt8](repeating: 0, count: 20 - frame.count)
    return frame
}

func valid(_ response: [UInt8]?) -> [UInt8]? {
    guard let response, response.count >= 20, response[0] == 0x11, response[2] != 0x8F, response[2] != 0xFF
    else { return nil }
    return response
}

func property(_ device: IOHIDDevice, _ key: String) -> Int {
    (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0
}

func string(_ device: IOHIDDevice, _ key: String) -> String {
    (IOHIDDeviceGetProperty(device, key as CFString) as? String) ?? "?"
}

var recording: [String] = []
var isRecording = false

func call(_ channel: Channel, _ frame: [UInt8]) -> [UInt8]? {
    let response = valid(channel.send(frame))
    if isRecording, let response {
        recording.append("> " + hex(frame))
        recording.append("< " + hex(response))
    }
    return response
}

func featureIndex(_ channel: Channel, _ index: UInt8, _ id: UInt16) -> UInt8? {
    guard let response = call(channel, long(index, 0x00, 0x00, [UInt8(id >> 8), UInt8(id & 0xFF)])),
          response[4] != 0
    else { return nil }
    return response[4]
}

func deviceName(_ channel: Channel, _ index: UInt8) -> String? {
    guard let feature = featureIndex(channel, index, 0x0005),
          let header = call(channel, long(index, feature, 0x00))
    else { return nil }
    var bytes: [UInt8] = []
    while bytes.count < Int(header[4]), let chunk = call(channel, long(index, feature, 0x01, [UInt8(bytes.count)])) {
        let piece = chunk[4...].prefix { $0 != 0 }
        guard !piece.isEmpty else { break }
        bytes += piece
    }
    guard !bytes.isEmpty else { return nil }
    return String(decoding: bytes, as: UTF8.self)
}

func dumpFeatures(_ channel: Channel, _ index: UInt8) {
    guard let featureSet = featureIndex(channel, index, 0x0001),
          let countResponse = call(channel, long(index, featureSet, 0x00))
    else {
        print("    features: FeatureSet (0x0001) indisponível")
        return
    }
    let count = Int(countResponse[4])
    print("    features: \(count) entradas")
    guard count > 0 else { return }
    for slot in 1...count {
        guard let response = call(channel, long(index, featureSet, 0x01, [UInt8(slot)])) else { continue }
        let id = UInt16(response[4]) << 8 | UInt16(response[5])
        guard id != 0 else { continue }
        print(String(format: "      %2d  0x%04X  %-30@ tipo 0x%X v%d",
                     slot, id, HIDPPFeatureCatalog.name(for: id) as NSString, Int(response[6] & 0x0F), Int(response[6] >> 4)))
    }
}

if let path = ProcessInfo.processInfo.environment["HIDPP_RECORD"] {
    isRecording = true
    recording = ["# Dump de features HID++ 2.0 gerado por tools/hidpp-dump. Sem série."]
    _ = path
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x046D] as CFDictionary)
let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("IOHIDManagerOpen: \(String(openStatus, radix: 16)) (0 = ok; e00002e2 = sem permissão)")
let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []

/// Mantém os canais vivos enquanto o processo roda: o callback agendado no run loop não pode apontar
/// para um canal já liberado (era o que estourava a alocação ao abrir o segundo receptor).
var channels: [Channel] = []

for device in devices.sorted(by: { property($0, "ProductID") < property($1, "ProductID") }) {
    let usagePage = property(device, kIOHIDPrimaryUsagePageKey)
    let transport = string(device, kIOHIDTransportKey)
    guard usagePage == 0xFF00 || transport.contains("Bluetooth") else { continue }
    let isReceiver = transport == "USB"
    print(String(format: "PID 0x%04X  %@  usagePage 0x%04X  transport %@",
                 property(device, "ProductID"), string(device, "Product"), usagePage, transport))
    let channel = Channel(device: device)
    channels.append(channel)
    for index in (isReceiver ? [UInt8](1...6) : [0xFF]) {
        guard let ping = call(channel, long(index, 0x00, 0x01)) else { continue }
        print("    índice \(index)  HID++ \(ping[4]).\(ping[5])")
        if let deviceName = deviceName(channel, index) { print("    nome: \(deviceName)") }
        dumpFeatures(channel, index)
    }
}

if let path = ProcessInfo.processInfo.environment["HIDPP_RECORD"] {
    try? (recording.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    print("gravado: \(path)")
}
