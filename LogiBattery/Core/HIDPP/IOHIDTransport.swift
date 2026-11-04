import Foundation
import IOKit.hid

/// HID++ sobre um `IOHIDDevice` de receptor. Todo estado mutável vive em `queue`; um pedido por vez.
final class IOHIDTransport: HIDPPTransport, @unchecked Sendable {
    private static let timeout: TimeInterval = 1.0
    private static let reportBufferSize = 64

    private let device: IOHIDDevice
    private let queue = DispatchQueue(label: "com.lucasstop.LogiBattery.hidpp")
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportBufferSize)
    private struct Pending {
        let token: Int
        let request: HIDPPFrame
        let continuation: CheckedContinuation<HIDPPFrame, Error>
    }

    private var pending: Pending?
    private var nextToken = 0
    private var nextSoftwareID = HIDPPFrame.softwareIDs.lowerBound
    private let onActivity: @Sendable () -> Void

    /// `onActivity` roda quando chega um frame HID++ que ninguém pediu (aviso de bateria, aparelho ligou).
    init(device: IOHIDDevice, onActivity: @escaping @Sendable () -> Void = {}) {
        self.device = device
        self.onActivity = onActivity
        IOHIDDeviceSetDispatchQueue(device, queue)
        let onReport: IOHIDReportCallback = { context, _, _, _, _, report, length in
            guard let context else { return }
            let transport = Unmanaged<IOHIDTransport>.fromOpaque(context).takeUnretainedValue()
            transport.handle(Array(UnsafeBufferPointer(start: report, count: length)))
        }
        IOHIDDeviceRegisterInputReportCallback(device, buffer, Self.reportBufferSize, onReport,
                                               Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDDeviceActivate(device)
    }

    deinit {
        IOHIDDeviceCancel(device)
        buffer.deallocate()
    }

    func exchange(_ original: HIDPPFrame) async throws -> HIDPPFrame {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.nextToken += 1
                let token = self.nextToken
                let request = original.withSoftwareID(self.rotateSoftwareID())
                self.pending = Pending(token: token, request: request, continuation: continuation)
                let status = IOHIDDeviceSetReport(self.device, kIOHIDReportTypeOutput,
                                                  CFIndex(request.bytes[0]), request.bytes, request.bytes.count)
                guard status == kIOReturnSuccess else { return self.finish(token, .failure(HIDPPError.noDevice)) }
                self.queue.asyncAfter(deadline: .now() + Self.timeout) {
                    self.finish(token, .failure(HIDPPError.timeout))
                }
            }
        }
    }

    private func rotateSoftwareID() -> UInt8 {
        let id = nextSoftwareID
        nextSoftwareID = id == HIDPPFrame.softwareIDs.upperBound ? HIDPPFrame.softwareIDs.lowerBound : id + 1
        return id
    }

    private func handle(_ report: [UInt8]) {
        guard report.count >= 5 else { return }
        guard let pending else { return notifyIfUnsolicited(report) }
        // Índice sem aparelho pareado (HID++ 1.0) ou feature recusada (HID++ 2.0) respondem erro na hora.
        switch HIDPPFrame.match(report, for: pending.request) {
        case .response(let frame): finish(pending.token, .success(frame))
        case .error: finish(pending.token, .failure(HIDPPError.noDevice))
        case .unrelated: notifyIfUnsolicited(report)
        }
    }

    private func notifyIfUnsolicited(_ report: [UInt8]) {
        if Self.isDeviceEvent(report) { onActivity() }
    }

    /// Frame que veio do aparelho sem pedido: notificação HID++ 1.0 (`0x40`...`0x7F`, ex.: `0x41` conexão) ou
    /// evento HID++ 2.0 (software id 0). Erro e resposta a pedido de outro app (Logi Options+ usa o software id
    /// dele) não contam.
    static func isDeviceEvent(_ report: [UInt8]) -> Bool {
        guard report.count >= 4, report[0] == 0x10 || report[0] == 0x11 else { return false }
        if (0x40..<0x80).contains(report[2]) { return true }
        return report[2] < 0x40 && report[3] & 0x0F == 0
    }

    private func finish(_ token: Int, _ result: Result<HIDPPFrame, Error>) {
        guard let current = pending, current.token == token else { return }
        pending = nil
        current.continuation.resume(with: result)
    }
}
