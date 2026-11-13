import XCTest
@testable import LogiBattery

/// Encoding das escritas e o caminho de leitura de confirmação, com transporte roteirizado (sem hardware).
final class HIDPPWriteTests: XCTestCase {
    func testDPIFrameEncodesSensorAndBigEndianValue() {
        let frame = HIDPPWrite.dpi(sensor: 0, dpi: 1600).frame(deviceIndex: 2, featureIndex: 13)
        XCTAssertEqual(frame.bytes[0], 0x11)
        XCTAssertEqual(frame.bytes[1], 2)
        XCTAssertEqual(frame.bytes[2], 13)
        XCTAssertEqual(frame.bytes[3], 0x31) // função 3 no nibble alto, software id 1
        XCTAssertEqual(Array(frame.bytes[4..<7]), [0x00, 0x06, 0x40])
        XCTAssertEqual(frame.params.count, 16)
    }

    func testSmartShiftFrameEncodesModeThresholdAndPreserveBytes() {
        let frame = HIDPPWrite.smartShift(mode: .ratchet, threshold: 0)
            .frame(deviceIndex: 2, featureIndex: 14)
        XCTAssertEqual(frame.bytes[3], 0x11)
        XCTAssertEqual(Array(frame.bytes[4..<7]), [0x02, 0x00, 0x00])

        let preserveMode = HIDPPWrite.smartShift(mode: nil, threshold: 16)
            .frame(deviceIndex: 2, featureIndex: 14)
        XCTAssertEqual(Array(preserveMode.bytes[4..<7]), [0x00, 0x10, 0x00])
    }

    func testSmartShiftWritesTheDefaultThresholdWhenGiven() {
        let frame = HIDPPWrite.smartShift(mode: .freeSpin, threshold: 255, defaultThreshold: 10)
            .frame(deviceIndex: 2, featureIndex: 14)
        XCTAssertEqual(Array(frame.bytes[4..<7]), [0x01, 0xFF, 0x0A])
    }

    func testWriteCarriesTheFeatureAndFunctionOfEachSetting() {
        let dpi = HIDPPWrite.dpi(sensor: 1, dpi: 8000)
        XCTAssertEqual(dpi.featureID, 0x2201)
        XCTAssertEqual(dpi.function, 0x3)
        XCTAssertEqual(dpi.params, [1, 0x1F, 0x40])

        let shift = HIDPPWrite.smartShift(mode: .freeSpin, threshold: 8)
        XCTAssertEqual(shift.featureID, 0x2110)
        XCTAssertEqual(shift.function, 0x1)
        XCTAssertEqual(shift.params, [0x01, 8, 0])
    }

    func testWriteFrameResolvesTheFeatureSlotWithoutSendingTheWrite() async throws {
        let transport = ScriptedTransport { request in
            request.featureIndex == 0x00 ? hidppReply(request, [13]) : nil
        }
        let session = HIDPPSession(transport: transport, deviceIndex: 2)

        let frame = try await session.writeFrame(.dpi(sensor: 0, dpi: 1600))
        XCTAssertEqual(frame.featureIndex, 13)
        XCTAssertEqual(frame.bytes[3], 0x31)

        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].featureIndex, 0x00)
    }

    func testDryRunIsTheDefaultAndDoesNotSendTheWrite() async throws {
        let transport = ScriptedTransport { request in
            request.featureIndex == 0x00 ? hidppReply(request, [14]) : nil
        }
        let session = HIDPPSession(transport: transport, deviceIndex: 2)

        let frame = try await session.apply(.smartShift(mode: .ratchet, threshold: 20))
        XCTAssertEqual(frame.featureIndex, 14)
        XCTAssertEqual(Array(frame.bytes[4..<6]), [0x02, 0x14])
        let sent = await transport.requests()
        XCTAssertEqual(sent.count, 1)
    }

    func testApplySendsTheWriteAndReturnsTheDeviceEcho() async throws {
        let transport = ScriptedTransport { request in
            if request.featureIndex == 0x00 { return hidppReply(request, [13]) }
            if request.featureIndex == 13, request.bytes[3] >> 4 == 0x3 {
                return hidppReply(request, Array(request.bytes[4...]))
            }
            return nil
        }
        let session = HIDPPSession(transport: transport, deviceIndex: 2)

        let echo = try await session.apply(.dpi(sensor: 0, dpi: 1600), dryRun: false)
        XCTAssertEqual(Array(echo.bytes[4..<7]), [0x00, 0x06, 0x40])

        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[1].featureIndex, 13)
        XCTAssertEqual(requests[1].bytes[3], 0x31)
    }

    func testApplyRefusesADeviceWithoutTheFeatureAndSendsNothing() async throws {
        let transport = ScriptedTransport { request in hidppReply(request, [0]) }
        let session = HIDPPSession(transport: transport, deviceIndex: 2)

        do {
            _ = try await session.apply(.dpi(sensor: 0, dpi: 1600), dryRun: false)
            XCTFail("esperava erro")
        } catch {
            XCTAssertEqual(error as? HIDPPError, .unsupported)
        }
        let sent = await transport.requests()
        XCTAssertEqual(sent.count, 1)
    }

    func testReadDPIParsesRangeCurrentAndDefault() async throws {
        let transport = ScriptedTransport { request in
            switch (request.featureIndex, request.bytes[3] >> 4) {
            case (0x00, 0x0):
                return hidppReply(request, [13])
            case (13, 0x0):
                return hidppReply(request, [1])
            case (13, 0x1):
                // eco do sensor, 200, 8000, passo 50, fim da lista
                return hidppReply(request, [0, 0x00, 0xC8, 0x1F, 0x40, 0xE0, 0x32, 0, 0])
            case (13, 0x2):
                // eco do sensor, atual 2000, padrão 1000
                return hidppReply(request, [0, 0x07, 0xD0, 0x03, 0xE8])
            default:
                return nil
            }
        }
        let session = HIDPPSession(transport: transport, deviceIndex: 2)

        let sensor = try await session.readDPISensor()
        XCTAssertEqual(sensor.index, 0)
        XCTAssertEqual(sensor.current, 2000)
        XCTAssertEqual(sensor.defaultDPI, 1000)
        XCTAssertEqual(sensor.minimum, 200)
        XCTAssertEqual(sensor.maximum, 8000)
        XCTAssertEqual(sensor.steps, 50)
    }

    func testReadDPIRefusesSensorBeyondTheCount() async throws {
        let transport = ScriptedTransport { request in
            switch (request.featureIndex, request.bytes[3] >> 4) {
            case (0x00, 0x0): return hidppReply(request, [13])
            case (13, 0x0): return hidppReply(request, [1])
            default: return nil
            }
        }
        let session = HIDPPSession(transport: transport, deviceIndex: 2)

        do {
            _ = try await session.readDPISensor(1)
            XCTFail("esperava erro")
        } catch {
            XCTAssertEqual(error as? HIDPPError, .unsupported)
        }
    }

    func testReadSmartShiftParsesModeThresholdAndDefault() async throws {
        let transport = ScriptedTransport { request in
            switch (request.featureIndex, request.bytes[3] >> 4) {
            case (0x00, 0x0): return hidppReply(request, [14])
            case (14, 0x0): return hidppReply(request, [0x02, 15, 10])
            default: return nil
            }
        }
        let session = HIDPPSession(transport: transport, deviceIndex: 2)

        let state = try await session.readSmartShift()
        XCTAssertEqual(state.mode, .ratchet)
        XCTAssertEqual(state.threshold, 15)
        XCTAssertEqual(state.defaultThreshold, 10)
    }

    func testReadSmartShiftRejectsAnUnknownMode() async throws {
        let transport = ScriptedTransport { request in
            switch (request.featureIndex, request.bytes[3] >> 4) {
            case (0x00, 0x0): return hidppReply(request, [14])
            case (14, 0x0): return hidppReply(request, [0x03, 15, 10])
            default: return nil
            }
        }
        let session = HIDPPSession(transport: transport, deviceIndex: 2)

        do {
            _ = try await session.readSmartShift()
            XCTFail("esperava erro")
        } catch {
            XCTAssertEqual(error as? HIDPPError, .malformed)
        }
    }

    func testDPIParserTreatsAValueAboveE000AsTheStepNotAsADPI() throws {
        let sensor = try HIDPPDPISensor(index: 0, list: [0, 0x00, 0xC8, 0xE0, 0x32, 0, 0],
                                       current: [0, 0x00, 0xC8, 0x00, 0xC8])
        XCTAssertEqual(sensor.minimum, 200)
        XCTAssertEqual(sensor.maximum, 200)
        XCTAssertEqual(sensor.steps, 50)
    }

    func testDPIParserRejectsAListWithoutAnyRange() {
        XCTAssertThrowsError(try HIDPPDPISensor(index: 0, list: [0, 0, 0], current: [0, 0, 1, 0, 1])) { error in
            XCTAssertEqual(error as? HIDPPError, .malformed)
        }
    }
}

private func hidppReply(_ request: HIDPPFrame, _ params: [UInt8]) -> HIDPPFrame {
    HIDPPFrame(deviceIndex: request.deviceIndex, featureIndex: request.featureIndex,
               function: request.bytes[3] >> 4, params: params, softwareID: request.bytes[3] & 0x0F)
}

private actor RequestLog {
    private(set) var requests: [HIDPPFrame] = []

    func append(_ request: HIDPPFrame) { requests.append(request) }
    func all() -> [HIDPPFrame] { requests }
}

private final class ScriptedTransport: HIDPPTransport, @unchecked Sendable {
    private let handler: @Sendable (HIDPPFrame) -> HIDPPFrame?
    private let log = RequestLog()

    init(handler: @escaping @Sendable (HIDPPFrame) -> HIDPPFrame?) {
        self.handler = handler
    }

    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame {
        await log.append(request)
        guard let response = handler(request) else { throw HIDPPError.noDevice }
        return response
    }

    func requests() async -> [HIDPPFrame] { await log.all() }
}
