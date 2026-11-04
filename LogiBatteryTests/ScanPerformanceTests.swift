import XCTest
@testable import LogiBattery

/// Orçamento de desempenho do scan (#117). O baseline é contagem (trocas HID++, timeouts, aparelhos em voo) e não
/// segundos: o `measure` do XCTest guarda o baseline por máquina e o runner do GitHub muda a cada job, então um limite
/// em segundos ou nunca falha ou falha sem motivo. Cada troca a mais custa, no transporte real, até o timeout inteiro
/// quando o aparelho dorme, então a contagem é o que prevê o tempo de verdade.
final class ScanPerformanceTests: XCTestCase {
    private static let sleepDelay: Duration = .milliseconds(300)

    /// Índice 2 responde (6 trocas: nome 3, tipo 1, bateria 2), índice 3 dorme (1 timeout) e os índices 1, 4, 5 e 6
    /// não existem no receptor (1 troca cada, sem timeout).
    func testReceiverScanWithOneAwakeAndOneSleepingDeviceStaysWithinExchangeBudget() async throws {
        let transport = CountingTransport(inner: try FixtureTransport(fixture: "bolt-mx-master-3s"),
                                          sleepingIndex: 3, delay: .milliseconds(50))
        let devices = await DeviceScanner(endpoints: [HIDEndpoint(id: "bolt", transport: transport)]).scan()

        XCTAssertEqual(devices.map(\.name), ["MX Master 3S"])
        let counts = await transport.counter.snapshot()
        XCTAssertEqual(counts.exchanges, 11)
        XCTAssertEqual(counts.timeouts, 1)
    }

    /// Dois endpoints dormindo ao mesmo tempo custam um atraso, não dois: o scan não serializa os endpoints.
    func testEndpointsAreScannedInParallel() async {
        let counter = ExchangeCounter()
        let endpoints = ["bt-a", "bt-b"].map {
            HIDEndpoint(id: $0, transport: SleepingTransport(counter: counter, delay: Self.sleepDelay),
                        path: .bluetooth)
        }
        let start = ContinuousClock.now
        _ = await DeviceScanner(endpoints: endpoints).scan()
        let elapsed = ContinuousClock.now - start

        let counts = await counter.snapshot()
        XCTAssertEqual(counts.peakInFlight, 2)
        XCTAssertEqual(counts.timeouts, 2)
        XCTAssertLessThan(elapsed, Self.sleepDelay * 1.5)
    }

    /// Só tendência local: o baseline do `measure` fica no xcbaseline da máquina, não no CI.
    func testMergeOfFiftyDevicesSeenOnBothPaths() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let devices = (0..<50).flatMap { index in
            [DevicePath.receiver, .bluetooth].map { path in
                Device(id: "\(path.rawValue):\(index)", name: "Device \(index)", kind: .mouse, percent: index * 2,
                       chargeState: .discharging, path: path, readAt: now.addingTimeInterval(Double(index)))
            }
        }
        measure {
            XCTAssertEqual(DeviceDeduplicator.merge(devices).count, 50)
        }
    }
}

private struct ExchangeCounts {
    var exchanges = 0
    var timeouts = 0
    var peakInFlight = 0
}

private actor ExchangeCounter {
    private var counts = ExchangeCounts()
    private var inFlight = 0

    func begin() {
        counts.exchanges += 1
        inFlight += 1
        counts.peakInFlight = max(counts.peakInFlight, inFlight)
    }

    func end(timedOut: Bool) {
        inFlight -= 1
        if timedOut { counts.timeouts += 1 }
    }

    func snapshot() -> ExchangeCounts { counts }
}

/// Aparelho que responde vem das fixtures; o do `sleepingIndex` demora `delay` e dá timeout, como o real dormindo.
private struct CountingTransport: HIDPPTransport {
    let inner: FixtureTransport
    let sleepingIndex: UInt8
    let delay: Duration
    let counter = ExchangeCounter()

    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame {
        await counter.begin()
        guard request.deviceIndex == sleepingIndex else {
            await counter.end(timedOut: false)
            return try await inner.exchange(request)
        }
        try? await Task.sleep(for: delay)
        await counter.end(timedOut: true)
        throw HIDPPError.timeout
    }
}

private struct SleepingTransport: HIDPPTransport {
    let counter: ExchangeCounter
    let delay: Duration

    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame {
        await counter.begin()
        try? await Task.sleep(for: delay)
        await counter.end(timedOut: true)
        throw HIDPPError.timeout
    }
}
