import Foundation

/// Interface HID++ do Mac: receptor (até 6 aparelhos, índices 1 a 6) ou aparelho Bluetooth (índice `0xFF`).
struct HIDEndpoint: Sendable {
    private static let bluetoothIndex: UInt8 = 0xFF

    let id: String
    let transport: any HIDPPTransport
    var path: DevicePath = .receiver

    var deviceIndexes: [UInt8] {
        path == .receiver ? Array(1...6) : [Self.bluetoothIndex]
    }
}

protocol DeviceScanning: Sendable {
    func scan() async -> [Device]
}

struct DeviceScanner: DeviceScanning {
    let endpoints: [HIDEndpoint]
    var now: @Sendable () -> Date = { Date() }

    func scan() async -> [Device] {
        let found = await withTaskGroup(of: [Device].self) { group in
            for endpoint in endpoints { group.addTask { await scan(endpoint) } }
            return await group.reduce(into: []) { $0 += $1 }
        }
        return found.sorted { ($0.percent ?? .max) < ($1.percent ?? .max) }
    }

    private func scan(_ endpoint: HIDEndpoint) async -> [Device] {
        var devices: [Device] = []
        for index in endpoint.deviceIndexes {
            let session = HIDPPSession(transport: endpoint.transport, deviceIndex: index)
            guard let reading = try? await session.readDevice() else { continue }
            devices.append(Device(id: "\(endpoint.id):\(index)", name: reading.name,
                                  kind: DeviceKind(name: reading.name), percent: reading.percent,
                                  chargeState: reading.chargeState, path: endpoint.path, readAt: now()))
        }
        return devices
    }
}
