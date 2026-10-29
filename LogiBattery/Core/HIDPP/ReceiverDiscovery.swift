import Foundation
import IOKit.hid

/// Acha as interfaces HID++ dos receptores Logitech (vendor `0x046D`, página `0xFF00`, uso `0x01`).
final class ReceiverDiscovery: @unchecked Sendable {
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

    func receivers() -> [Receiver] {
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        return devices.compactMap { device in
            guard Self.int(device, kIOHIDPrimaryUsagePageKey) == Self.hidppUsagePage,
                  Self.int(device, kIOHIDPrimaryUsageKey) == Self.hidppUsage,
                  (IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String) == "USB"
            else { return nil }
            let id = "usb-\(String(Self.int(device, kIOHIDProductIDKey), radix: 16))"
            let transport = transports[id] ?? IOHIDTransport(device: device)
            transports[id] = transport
            return Receiver(id: id, transport: transport)
        }
    }

    private static func int(_ device: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0
    }
}
