import Foundation
import IOKit.hid

/// HID++ sobre um `IOHIDDevice` de receptor. Todo estado mutável vive em `queue`; um pedido por vez.
final class IOHIDTransport: HIDPPTransport, @unchecked Sendable {
    private static let timeout: TimeInterval = 1.0
    private static let reportBufferSize = 64
    private static let hidpp1ErrorReport: UInt8 = 0x10
    private static let errorFeature: UInt8 = 0x8F

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

    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.nextToken += 1
                let token = self.nextToken
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

    private func handle(_ report: [UInt8]) {
        guard report.count >= 5 else { return }
        guard let pending else { return notifyIfUnsolicited(report) }
        // Índice sem aparelho pareado responde erro HID++ 1.0 na hora; não esperar o timeout.
        if report[0] == Self.hidpp1ErrorReport, report[1] == pending.request.deviceIndex,
           report[2] == Self.errorFeature {
            return finish(pending.token, .failure(HIDPPError.noDevice))
        }
        if let frame = HIDPPFrame(response: report), frame.answers(pending.request) {
            finish(pending.token, .success(frame))
        } else {
            notifyIfUnsolicited(report)
        }
    }

    private func notifyIfUnsolicited(_ report: [UInt8]) {
        guard report[0] == 0x10 || report[0] == 0x11, report[2] != Self.errorFeature, report[2] != 0xFF else { return }
        onActivity()
    }

    private func finish(_ token: Int, _ result: Result<HIDPPFrame, Error>) {
        guard let current = pending, current.token == token else { return }
        pending = nil
        current.continuation.resume(with: result)
    }
}
