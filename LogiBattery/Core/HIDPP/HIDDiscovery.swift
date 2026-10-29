import Foundation
import IOKit.hid

/// Acha as interfaces HID++ Logitech (vendor `0x046D`).
final class HIDDiscovery: @unchecked Sendable {
    private static let vendorID = 0x046D
    private static let hidppUsagePage = 0xFF00
    private static let hidppUsage = 0x01

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    // Manager à parte só para eventos: os dispositivos do `manager` usam fila própria (IOHIDTransport) e o IOKit
    // recusa agendar o mesmo dispositivo em run loop e em fila.
    private let watcher = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var transports: [String: IOHIDTransport] = [:]
    private let continuation: AsyncStream<Void>.Continuation

    /// Um valor a cada aparelho que conecta ou desconecta e a cada frame HID++ espontâneo.
    let changes: AsyncStream<Void>

    init() {
        (changes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: Self.vendorID] as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(watcher, [kIOHIDVendorIDKey: Self.vendorID] as CFDictionary)
        let onChange: IOHIDDeviceCallback = { context, _, _, _ in
            guard let context else { return }
            Unmanaged<HIDDiscovery>.fromOpaque(context).takeUnretainedValue().continuation.yield()
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(watcher, onChange, context)
        IOHIDManagerRegisterDeviceRemovalCallback(watcher, onChange, context)
        IOHIDManagerScheduleWithRunLoop(watcher, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(watcher, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit {
        IOHIDManagerUnscheduleFromRunLoop(watcher, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(watcher, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    /// Receptores USB (interface HID++ `0xFF00`/`0x01`) e aparelhos Bluetooth (HID++ no próprio serviço HID).
    func endpoints() -> [HIDEndpoint] {
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        let found: [HIDEndpoint] = devices.compactMap { device in
            let transportName = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
            let product = String(Self.int(device, kIOHIDProductIDKey), radix: 16)
            let path: DevicePath
            if transportName == "USB", Self.int(device, kIOHIDPrimaryUsagePageKey) == Self.hidppUsagePage,
               Self.int(device, kIOHIDPrimaryUsageKey) == Self.hidppUsage {
                path = .receiver
            } else if transportName.contains("Bluetooth") {
                path = .bluetooth
            } else {
                return nil
            }
            // Um aparelho Bluetooth expõe várias interfaces HID com o mesmo produto; cada uma vira um endpoint e só
            // a que fala HID++ responde, o resto cai no timeout e some na deduplicação.
            let id = (path == .receiver ? "usb-" : "ble-") + product + "-" + Self.registryID(device)
            let transport = transports[id] ?? IOHIDTransport(device: device) { [continuation] in continuation.yield() }
            transports[id] = transport
            return HIDEndpoint(id: id, transport: transport, path: path)
        }
        // Solta o transporte de aparelho que saiu (ex.: trocou de receptor para Bluetooth).
        transports = transports.filter { entry in found.contains { $0.id == entry.key } }
        return found.sorted { $0.id < $1.id }
    }

    private static func registryID(_ device: IOHIDDevice) -> String {
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entryID)
        return String(entryID, radix: 16)
    }

    private static func int(_ device: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0
    }
}
