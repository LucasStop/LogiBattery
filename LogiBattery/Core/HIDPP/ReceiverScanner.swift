import Foundation

struct Receiver: Sendable {
    let id: String
    let transport: any HIDPPTransport
}

protocol DeviceScanning: Sendable {
    func scan() async -> [Device]
}

/// Um receptor (Unifying, Bolt, Lightspeed) endereça até 6 aparelhos pareados, índices 1 a 6.
struct ReceiverScanner: DeviceScanning {
    let receivers: [Receiver]
    var now: @Sendable () -> Date = { Date() }

    func scan() async -> [Device] {
        let found = await withTaskGroup(of: [Device].self) { group in
            for receiver in receivers { group.addTask { await scan(receiver) } }
            return await group.reduce(into: []) { $0 += $1 }
        }
        return found.sorted { ($0.percent ?? .max) < ($1.percent ?? .max) }
    }

    private func scan(_ receiver: Receiver) async -> [Device] {
        var devices: [Device] = []
        for index in UInt8(1)...6 {
            let session = HIDPPSession(transport: receiver.transport, deviceIndex: index)
            guard let reading = try? await session.readDevice() else { continue }
            devices.append(Device(id: "\(receiver.id):\(index)", name: reading.name,
                                  kind: DeviceKind(name: reading.name), percent: reading.percent,
                                  chargeState: reading.chargeState, path: .receiver, readAt: now()))
        }
        return devices
    }
}
