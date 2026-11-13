import XCTest
@testable import QCYBattery

/// Link falso: grava o que o modelo escreve e deixa o teste simular o que o fone devolve.
private final class FakeLink: QCYLink, @unchecked Sendable {
    var onState: (@Sendable (QCYState) -> Void)?
    var onAdvertisement: (@Sendable (QCYAdvertisement) -> Void)?
    var onReady: (@Sendable () -> Void)?
    var onDisconnect: (@Sendable () -> Void)?
    private(set) var sent: [QCYPacket] = []
    private(set) var refreshCount = 0

    func start() {}
    func stop() {}
    func refresh() { refreshCount += 1 }
    func send(_ packet: QCYPacket) { sent.append(packet) }
}

@MainActor
final class QCYViewModelTests: XCTestCase {
    private func makeModel(readOnly: Bool = false, writeTimeout: Duration = .seconds(5),
                           settleTimeout: Duration = .seconds(5)) -> (QCYViewModel, FakeLink) {
        let link = FakeLink()
        return (QCYViewModel(link: link, isReadOnly: readOnly, writeTimeout: writeTimeout,
                             settleTimeout: settleTimeout), link)
    }

    private func state(anc: UInt8 = 0x03, ldac: Bool = false, game: Bool = false) -> QCYState {
        var state = QCYState()
        state.left = QCYBatteryLevel(raw: 90)
        state.right = QCYBatteryLevel(raw: 91)
        state.ancScene = QCYANScene(mode: anc, subScene: 0x02, noiseValue: 0x00)
        state.isLDACEnabled = ldac
        state.isLowLatencyEnabled = game
        return state
    }

    /// Os callbacks do link pulam para o main actor em `Task`; um instante basta para eles rodarem.
    private func flush() async { try? await Task.sleep(for: .milliseconds(30)) }

    func testStartsLoadingAndBecomesConnectedOnFirstState() async {
        let (model, link) = makeModel()
        XCTAssertEqual(model.phase, .loading)
        link.onState?(state())
        await flush()
        XCTAssertEqual(model.phase, .connected)
        XCTAssertEqual(model.state.left?.percent, 90)
        XCTAssertEqual(model.ancChoice, .transparency)
    }

    func testSelectingANCSendsSceneAndWaitsForEcho() async {
        let (model, link) = makeModel()
        link.onState?(state())
        await flush()

        model.select(.anc)
        XCTAssertEqual(link.sent, [.ancSetting(mode: 0x01, subScene: 0x02, noiseValue: 0x03)])
        XCTAssertEqual(model.pending, .anc(.anc))
        XCTAssertEqual(model.ancSelection, .anc)
        XCTAssertTrue(model.areControlsDisabled)

        link.onState?(state(anc: 0x01))
        await flush()
        XCTAssertNil(model.pending)
        XCTAssertEqual(model.ancChoice, .anc)
        XCTAssertFalse(model.writeFailed)
    }

    func testUnrelatedStateDoesNotConfirmPendingWrite() async {
        let (model, link) = makeModel()
        link.onState?(state())
        await flush()
        model.setLDAC(true)
        link.onState?(state(ldac: false))
        await flush()
        XCTAssertEqual(model.pending, .ldac(true))
        XCTAssertTrue(model.isLDACOn)
        link.onState?(state(ldac: true))
        await flush()
        XCTAssertNil(model.pending)
    }

    func testGameToggleSendsLowLatency() async {
        let (model, link) = makeModel()
        link.onState?(state())
        await flush()
        model.setGame(true)
        XCTAssertEqual(link.sent, [.setLowLatency(true)])
        link.onState?(state(game: true))
        await flush()
        XCTAssertTrue(model.isGameOn)
        XCTAssertNil(model.pending)
    }

    func testRollsBackWhenFoneDoesNotEcho() async {
        let (model, link) = makeModel(writeTimeout: .milliseconds(40))
        link.onState?(state())
        await flush()
        model.select(.normal)
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertNil(model.pending)
        XCTAssertTrue(model.writeFailed)
        XCTAssertEqual(model.ancSelection, .transparency)
    }

    func testRetryClearsFailureAndRereadsState() async {
        let (model, link) = makeModel(writeTimeout: .milliseconds(20))
        link.onState?(state())
        await flush()
        model.setGame(true)
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(model.writeFailed)
        model.retryAfterFailure()
        XCTAssertFalse(model.writeFailed)
        XCTAssertEqual(link.refreshCount, 1)
    }

    func testReadOnlyNeverWrites() async {
        let (model, link) = makeModel(readOnly: true)
        link.onState?(state())
        await flush()
        model.select(.anc)
        model.setLDAC(true)
        model.setGame(true)
        XCTAssertTrue(link.sent.isEmpty)
        XCTAssertNil(model.pending)
    }

    func testDisconnectClearsPendingAndState() async {
        let (model, link) = makeModel()
        link.onState?(state())
        await flush()
        model.setLDAC(true)
        link.onDisconnect?()
        await flush()
        XCTAssertEqual(model.phase, .disconnected)
        XCTAssertNil(model.pending)
        XCTAssertNil(model.state.left)
        XCTAssertFalse(model.writeFailed)
        XCTAssertTrue(model.areControlsDisabled)
    }

    func testIgnoresWritesWithoutConnection() {
        let (model, link) = makeModel()
        model.select(.anc)
        XCTAssertTrue(link.sent.isEmpty)
    }

    func testReadyWithoutStateSettlesToConnectedWithNoReading() async {
        let (model, link) = makeModel(settleTimeout: .milliseconds(30))
        link.onReady?()
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(model.phase, .connected)
        XCTAssertNil(model.state.left)
    }

    func testNoFoneSettlesToDisconnected() async {
        let (model, _) = makeModel(settleTimeout: .milliseconds(30))
        model.start()
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(model.phase, .disconnected)
        model.stop()
    }

    func testAdvertisementProvidesControlAddress() async throws {
        let (model, link) = makeModel()
        var bytes = [UInt8](repeating: 0, count: 26)
        bytes[0] = 0x1C
        bytes[1] = 0x52
        let advertisement = try XCTUnwrap(QCYAdvertisement(manufacturerData: Data(bytes)))
        link.onAdvertisement?(advertisement)
        await flush()
        XCTAssertEqual(model.address, advertisement.controlMAC)
    }
}
