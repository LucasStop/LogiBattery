// Spike descartável da #10: enumera HID Logitech e lê bateria por HID++ 2.0.
// Uso: swiftc -O main.swift -o /tmp/hidpp-spike && /tmp/hidpp-spike
// Não loga série nem nome do usuário; frames saem em hex para virar fixtures.
import Foundation
import IOKit.hid

let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(mgr, [kIOHIDVendorIDKey: 0x046D] as CFDictionary)
let open = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
print("IOHIDManagerOpen: \(String(open, radix: 16)) (0 = ok; e00002e2 = sem permissão)")
let devices = (IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>) ?? []
func prop(_ d: IOHIDDevice, _ k: String) -> Int { (IOHIDDeviceGetProperty(d, k as CFString) as? Int) ?? 0 }
func str(_ d: IOHIDDevice, _ k: String) -> String { (IOHIDDeviceGetProperty(d, k as CFString) as? String) ?? "?" }

final class Box { var reports: [[UInt8]] = [] }
let box = Box()
let hex: ([UInt8]) -> String = { $0.map { String(format: "%02x", $0) }.joined(separator: " ") }

func request(_ d: IOHIDDevice, _ frame: [UInt8], wait: TimeInterval = 1.0) -> [UInt8]? {
    box.reports.removeAll()
    var buf = [UInt8](repeating: 0, count: 64)
    IOHIDDeviceRegisterInputReportCallback(d, &buf, buf.count, { ctx, _, _, _, _, rep, len in
        let b = Unmanaged<Box>.fromOpaque(ctx!).takeUnretainedValue()
        b.reports.append(Array(UnsafeBufferPointer(start: rep, count: len)))
    }, Unmanaged.passUnretained(box).toOpaque())
    IOHIDDeviceScheduleWithRunLoop(d, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    let r = IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, CFIndex(frame[0]), frame, frame.count)
    guard r == kIOReturnSuccess else { print("  SetReport falhou: \(String(r, radix: 16))"); return nil }
    let end = Date().addingTimeInterval(wait)
    // Casa resposta com pedido (índice, feature, função+sw); eventos e respostas atrasadas são descartados.
    let match = { (r: [UInt8]) in r.count > 3 && r[1] == frame[1] && r[2] == frame[2] && r[3] == frame[3] }
    while Date() < end, !box.reports.contains(where: match) { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05)) }
    IOHIDDeviceUnscheduleFromRunLoop(d, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    let resp = box.reports.first(where: match)
    if ProcessInfo.processInfo.environment["HIDPP_TRACE"] != nil, let resp { print("TRACE > \(hex(frame))\nTRACE < \(hex(resp))") }
    return resp
}

// HID++ 2.0 long report: 11 idx feat fn|sw params(16)
func long(_ idx: UInt8, _ feat: UInt8, _ fn: UInt8, _ p: [UInt8] = []) -> [UInt8] {
    var f: [UInt8] = [0x11, idx, feat, (fn << 4) | 0x1] + p
    f += [UInt8](repeating: 0, count: 20 - f.count); return f
}

for d in devices.sorted(by: { prop($0, "ProductID") < prop($1, "ProductID") }) {
    let up = prop(d, kIOHIDPrimaryUsagePageKey), us = prop(d, kIOHIDPrimaryUsageKey)
    print(String(format: "PID 0x%04X  %@  usagePage 0x%04X usage 0x%02X  transport %@", prop(d, "ProductID"), str(d, "Product"), up, us, str(d, "Transport")))
    guard up == 0xFF00 || up == 0xFF43 else { continue }
    let isRecv = str(d, "Transport") == "USB"
    func ok(_ r: [UInt8]?) -> [UInt8]? { guard let r, r.count >= 5, r[0] == 0x11, r[2] != 0x8f, r[2] != 0xff else { return nil }; return r }
    func feature(_ idx: UInt8, _ id: UInt16) -> UInt8? {
        guard let r = ok(request(d, long(idx, 0x00, 0x0, [UInt8(id >> 8), UInt8(id & 0xFF)]))), r[4] != 0 else { return nil }
        return r[4]
    }
    for idx in (isRecv ? [UInt8](1...6) : [0xFF]) {
        guard let r0 = ok(request(d, long(idx, 0x00, 0x1))) else { continue } // ping (GetProtocolVersion)
        print("  idx \(idx) ping: \(hex(r0))")
        if let fi = feature(idx, 0x0005), let c = ok(request(d, long(idx, fi, 0x0))) {
            var name = [UInt8](); var off = 0
            while off < Int(c[4]), let n = ok(request(d, long(idx, fi, 0x1, [UInt8(off)]))) { name += n[4...].prefix { $0 != 0 }; off = name.count }
            print("  idx \(idx) nome: \(String(decoding: name, as: UTF8.self))")
        }
        for feat in [(UInt16(0x1004), "unified"), (0x1000, "level"), (0x1001, "voltage")] {
            guard let fi = feature(idx, feat.0) else { continue }
            let fn: UInt8 = feat.0 == 0x1004 ? 1 : 0
            print("  idx \(idx) feature \(feat.1) (0x\(String(feat.0, radix: 16))) index \(fi)")
            if let b = ok(request(d, long(idx, fi, fn))) { print("  idx \(idx) battery \(feat.1): \(hex(b))") }
            break
        }
    }
}
