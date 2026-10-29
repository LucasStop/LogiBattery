import XCTest
@testable import LogiBattery

@MainActor
final class DeviceListViewModelTests: XCTestCase {
    func testRefreshPublishesScannedDevices() async {
        let device = Device(id: "a", name: "MX Master 3S", kind: .mouse, percent: 90, chargeState: .discharging,
                            path: .receiver, readAt: Date(timeIntervalSince1970: 0))
        let viewModel = DeviceListViewModel(scanner: StubScanner(devices: [device]))
        XCTAssertFalse(viewModel.hasLoaded)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices, [device])
        XCTAssertTrue(viewModel.hasLoaded)
    }

    func testDeviceKindFromName() {
        XCTAssertEqual(DeviceKind(name: "MX Master 3S"), .mouse)
        XCTAssertEqual(DeviceKind(name: "PRO X TKL"), .keyboard)
        XCTAssertEqual(DeviceKind(name: "MX Keys"), .keyboard)
        XCTAssertEqual(DeviceKind(name: "Headset"), .other)
    }
}

private struct StubScanner: DeviceScanning {
    let devices: [Device]
    func scan() async -> [Device] { devices }
}

@MainActor
final class DeviceListPublishTests: XCTestCase {
    func testRefreshPublishesDevicesToSnapshotSink() async {
        let device = Device(id: "a", name: "MX Master 3S", kind: .mouse, percent: 90, chargeState: .discharging,
                            path: .receiver, readAt: Date(timeIntervalSince1970: 0))
        var published: [[Device]] = []
        let viewModel = DeviceListViewModel(scanner: StubScanner(devices: [device])) { published.append($0) }
        await viewModel.refresh()
        XCTAssertEqual(published, [[device]])
    }
}

@MainActor
final class DeviceChangeRefreshTests: XCTestCase {
    func testDeviceChangeTriggersRefreshWithoutWaitingForInterval() async throws {
        let scanner = CountingScanner()
        let viewModel = DeviceListViewModel(scanner: scanner)
        let (changes, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let task = Task {
            await viewModel.run(interval: { .seconds(3600) }, changes: changes,
                                debounce: .milliseconds(10), minGap: .milliseconds(10))
        }
        try await waitUntil { scanner.count >= 1 }
        continuation.yield()
        try await waitUntil { scanner.count >= 2 }
        task.cancel()
        XCTAssertGreaterThanOrEqual(scanner.count, 2)
    }

    func testBurstOfChangesIsCoalesced() async throws {
        let scanner = CountingScanner()
        let viewModel = DeviceListViewModel(scanner: scanner)
        let (changes, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let task = Task {
            await viewModel.run(interval: { .seconds(3600) }, changes: changes,
                                debounce: .milliseconds(50), minGap: .seconds(60))
        }
        try await waitUntil { scanner.count >= 1 }
        for _ in 0..<20 { continuation.yield() }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        XCTAssertEqual(scanner.count, 2)
    }

    func testChangeRepeatsReadingWhileTheDeviceSettles() async throws {
        let scanner = CountingScanner()
        let viewModel = DeviceListViewModel(scanner: scanner)
        let (changes, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let task = Task {
            await viewModel.run(interval: { .seconds(3600) }, changes: changes, debounce: .milliseconds(10),
                                minGap: .milliseconds(10), settle: [.milliseconds(20), .milliseconds(20)])
        }
        try await waitUntil { scanner.count >= 1 }
        continuation.yield()
        try await waitUntil { scanner.count >= 4 }
        task.cancel()
        XCTAssertGreaterThanOrEqual(scanner.count, 4)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<200 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition())
    }
}

private final class CountingScanner: DeviceScanning, @unchecked Sendable {
    private let lock = NSLock()
    private var scans = 0
    var count: Int { lock.withLock { scans } }

    func scan() async -> [Device] {
        lock.withLock { scans += 1 }
        return []
    }
}
