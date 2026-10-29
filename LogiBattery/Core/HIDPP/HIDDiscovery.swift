import Foundation
import IOKit.hid

/// Acha as interfaces HID++ Logitech (vendor `0x046D`).
final class HIDDiscovery: @unchecked Sendable {
    private static let vendorID = 0x046D
    private static let hidppUsagePage = 0xFF00
    private static let hidppUsage = 0x01

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var transports: [String: IOHIDTransport] = [:]

    init() {
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: Self.vendorID] as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

    /// Receptores USB (interface HID++ `0xFF00`/`0x01`) e aparelhos Bluetooth (HID++ no próprio serviço HID).
    func endpoints() -> [HIDEndpoint] {
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        return devices.compactMap { device in
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
            let id = (path == .receiver ? "usb-" : "ble-") + product
            let transport = transports[id] ?? IOHIDTransport(device: device)
            transports[id] = transport
            return HIDEndpoint(id: id, transport: transport, path: path)
        }
    }

    private static func int(_ device: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0
    }
}
