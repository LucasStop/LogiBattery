// Escrita de configuração HID++ 2.0 (DPI e SmartShift) com --dry-run como padrão.
// Uso:
//   swiftc -O tools/hidpp-write/main.swift \
//     LogiBattery/Core/HIDPP/HIDPPFrame.swift \
//     LogiBattery/Core/HIDPP/HIDPPFeatures.swift \
//     LogiBattery/Core/HIDPP/HIDPPWrite.swift \
//     -o /tmp/hidpp-write
//   /tmp/hidpp-write --dpi 1600          # mostra o frame, não escreve
//   /tmp/hidpp-write --dpi 1600 --apply  # escreve e lê de volta para confirmar
// Não loga série nem nome do usuário.
import Foundation
import IOKit.hid

let hex: ([UInt8]) -> String = { $0.map { String(format: "%02x", $0) }.joined(separator: " ") }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("erro: " + message + "\n").utf8))
    exit(1)
}

let usageText = """
Uso: hidpp-write [--dpi N] [--smartshift free|ratchet] [--threshold N] [--apply]

  --dpi N                DPI do sensor (inteiro, dentro da faixa que o aparelho informa)
  --smartshift free|ratchet  modo da roda
  --threshold N          threshold do SmartShift (1...254, 255 = catraca permanente)
  --sensor N             sensor de DPI (padrão 0)
  --index N              índice HID++ do aparelho (receptor 1...6, Bluetooth 255)
  --apply                escreve de verdade; sem esta opção é dry-run e nada é enviado

Sem --apply o frame é montado e mostrado, mas não é enviado.
"""

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
        // Erro do HID++ 1.0 (`10 índice 8F`) é slot sem aparelho: esperar o timeout inteiro só atrasa.
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

func call(_ channel: Channel, _ frame: [UInt8]) -> [UInt8]? {
    valid(channel.send(frame))
}

func featureIndex(_ channel: Channel, _ index: UInt8, _ id: UInt16) -> UInt8? {
    guard let response = call(channel, long(index, 0x00, 0x00, [UInt8(id >> 8), UInt8(id & 0xFF)])),
          response[4] != 0
    else { return nil }
    return response[4]
}

func deviceName(_ channel: Channel, _ index: UInt8) -> String? {
    guard let feature = featureIndex(channel, index, HIDPPFeatureID.deviceName),
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

func readSensor(_ channel: Channel, _ index: UInt8, feature: UInt8, sensor: UInt8) -> HIDPPDPISensor? {
    guard let count = call(channel, long(index, feature, 0x0, [sensor])), count[4] > sensor,
          let list = call(channel, long(index, feature, 0x1, [sensor])),
          let current = call(channel, long(index, feature, 0x2, [sensor]))
    else { return nil }
    return try? HIDPPDPISensor(index: sensor, list: Array(list[4...]), current: Array(current[4...]))
}

func readShift(_ channel: Channel, _ index: UInt8, feature: UInt8) -> HIDPPSmartShift? {
    guard let response = call(channel, long(index, feature, 0x0)) else { return nil }
    return try? HIDPPSmartShift(params: Array(response[4...]))
}

func modeName(_ mode: HIDPPSmartShiftMode) -> String {
    mode == .freeSpin ? "free" : "ratchet"
}

// MARK: - argumentos

var apply = false
var dpi: UInt16?
var mode: HIDPPSmartShiftMode?
var threshold: UInt8?
var sensorIndex: UInt8 = 0
var forcedIndex: UInt8?
let arguments = Array(CommandLine.arguments.dropFirst())
var cursor = 0

func value(for flag: String) -> String {
    cursor += 1
    guard cursor < arguments.count else { fail("\(flag) precisa de um valor") }
    return arguments[cursor]
}

while cursor < arguments.count {
    switch arguments[cursor] {
    case "--apply":
        apply = true
    case "--dry-run":
        apply = false
    case "--dpi":
        let raw = value(for: "--dpi")
        guard let parsed = UInt16(raw), parsed > 0 else { fail("--dpi espera um inteiro positivo, veio \(raw)") }
        dpi = parsed
    case "--smartshift":
        let raw = value(for: "--smartshift").lowercased()
        switch raw {
        case "free", "freespin": mode = .freeSpin
        case "ratchet": mode = .ratchet
        default: fail("--smartshift aceita free ou ratchet, veio \(raw)")
        }
    case "--threshold":
        let raw = value(for: "--threshold")
        guard let parsed = UInt8(raw), parsed >= 1 else {
            fail("--threshold espera 1...254 (255 = permanente), veio \(raw)")
        }
        threshold = parsed
    case "--sensor":
        let raw = value(for: "--sensor")
        guard let parsed = UInt8(raw) else { fail("--sensor espera um inteiro 0...255, veio \(raw)") }
        sensorIndex = parsed
    case "--index":
        let raw = value(for: "--index")
        guard let parsed = UInt8(raw) else { fail("--index espera um inteiro 0...255, veio \(raw)") }
        forcedIndex = parsed
    case "--help", "-h":
        print(usageText)
        exit(0)
    default:
        fail("argumento desconhecido: \(arguments[cursor])")
    }
    cursor += 1
}

guard dpi != nil || mode != nil || threshold != nil else {
    fail("nada para fazer: use --dpi, --smartshift ou --threshold\n\n" + usageText)
}

// MARK: - aparelho

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x046D] as CFDictionary)
let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
if openStatus != kIOReturnSuccess {
    fail("IOHIDManagerOpen falhou: \(String(openStatus, radix: 16)) (e00002e2 = sem permissão)")
}
let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []

struct Target {
    let channel: Channel
    let index: UInt8
    let label: String
    let dpiFeature: UInt8?
    let smartShiftFeature: UInt8?
}

// Mantém os canais vivos enquanto o processo roda: o callback agendado no run loop aponta para eles.
var channels: [Channel] = []
var target: Target?
let wantsShift = mode != nil || threshold != nil

for device in devices.sorted(by: { property($0, "ProductID") < property($1, "ProductID") }) {
    let usagePage = property(device, kIOHIDPrimaryUsagePageKey)
    let transport = string(device, kIOHIDTransportKey)
    guard usagePage == 0xFF00 || transport.contains("Bluetooth") else { continue }
    let channel = Channel(device: device)
    channels.append(channel)
    for index in (transport == "USB" ? [UInt8](1...6) : [0xFF]) {
        if let forcedIndex, forcedIndex != index { continue }
        guard call(channel, long(index, 0x00, 0x01)) != nil else { continue }
        let dpiFeature = dpi == nil ? nil : featureIndex(channel, index, HIDPPFeatureID.adjustableDpi)
        let shiftFeature = wantsShift ? featureIndex(channel, index, HIDPPFeatureID.smartShift) : nil
        if dpi != nil && dpiFeature == nil { continue }
        if wantsShift && shiftFeature == nil { continue }
        let name = deviceName(channel, index) ?? string(device, "Product")
        target = Target(channel: channel, index: index, label: "\(name) · \(transport) · índice \(index)",
                        dpiFeature: dpiFeature, smartShiftFeature: shiftFeature)
        break
    }
    if target != nil { break }
}

guard let target else {
    let wanted = [dpi != nil ? "DPI (0x2201)" : nil, wantsShift ? "SmartShift (0x2110)" : nil]
        .compactMap { $0 }.joined(separator: " e ")
    fail("nenhum aparelho Logitech com \(wanted) respondeu")
}
print(target.label)

func send(_ frame: HIDPPFrame) -> [UInt8] {
    guard let response = target.channel.send(frame.bytes), valid(response) != nil else {
        fail("aparelho não respondeu ao frame \(hex(frame.bytes))")
    }
    return response
}

// MARK: - DPI

if let requested = dpi {
    guard let feature = target.dpiFeature else { fail("aparelho sem AdjustableDpi (0x2201)") }
    guard let before = readSensor(target.channel, target.index, feature: feature, sensor: sensorIndex) else {
        fail("não consegui ler o DPI do sensor \(sensorIndex)")
    }
    print("DPI: \(before.current) (padrão \(before.defaultDPI), faixa \(before.minimum)–\(before.maximum), "
          + "passo \(before.steps))")
    guard requested >= before.minimum, requested <= before.maximum else {
        fail("DPI \(requested) fora da faixa \(before.minimum)–\(before.maximum)")
    }
    let write = HIDPPWrite.dpi(sensor: sensorIndex, dpi: requested)
    let frame = write.frame(deviceIndex: target.index, featureIndex: feature)
    print("frame DPI: \(hex(frame.bytes))")
    if apply {
        let response = send(frame)
        let echo = UInt16(response[5]) << 8 | UInt16(response[6])
        if echo != 0 && echo != requested {
            fail("aparelho devolveu \(echo) em vez de \(requested)")
        }
        guard let after = readSensor(target.channel, target.index, feature: feature, sensor: sensorIndex),
              after.current == requested
        else { fail("leitura de confirmação não voltou \(requested)") }
        print("confirmado: DPI \(after.current)")
    }
}

// MARK: - SmartShift

if wantsShift {
    guard let feature = target.smartShiftFeature else { fail("aparelho sem SmartShift (0x2110)") }
    guard let before = readShift(target.channel, target.index, feature: feature) else {
        fail("não consegui ler o SmartShift")
    }
    print("SmartShift: \(modeName(before.mode)), threshold \(before.threshold) "
          + "(padrão \(before.defaultThreshold))")
    let write = HIDPPWrite.smartShift(mode: mode, threshold: threshold ?? 0)
    let frame = write.frame(deviceIndex: target.index, featureIndex: feature)
    print("frame SmartShift: \(hex(frame.bytes))")
    if apply {
        _ = send(frame)
        guard let after = readShift(target.channel, target.index, feature: feature) else {
            fail("não consegui reler o SmartShift depois da escrita")
        }
        if let mode, after.mode != mode { fail("modo não mudou: aparelho está em \(modeName(after.mode))") }
        if let threshold, after.threshold != threshold {
            fail("threshold não mudou: aparelho está em \(after.threshold)")
        }
        print("confirmado: \(modeName(after.mode)), threshold \(after.threshold)")
    }
}

if !apply {
    print("dry-run: nada foi escrito; use --apply para escrever")
}
