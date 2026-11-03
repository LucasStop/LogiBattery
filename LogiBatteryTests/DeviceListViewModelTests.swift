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

/// Teclado Lightspeed dorme ~12 s parado e não responde à leitura; a lista mantém a última leitura dele.
@MainActor
final class KeepLastReadingTests: XCTestCase {
    private func keyboard(_ readAt: Date, id: String = "usb-c547-1:1") -> Device {
        Device(id: id, name: "PRO X TKL", kind: .keyboard, percent: 77, chargeState: .discharging, path: .receiver,
               readAt: readAt)
    }

    private func mouse(_ readAt: Date) -> Device {
        Device(id: "usb-c548-2:2", name: "MX Master 3S", kind: .mouse, percent: 90, chargeState: .discharging,
               path: .receiver, readAt: readAt)
    }

    func testSleepingDeviceKeepsLastReading() async {
        let now = Date.now
        let viewModel = DeviceListViewModel(scanner: ScriptedScanner([[mouse(now), keyboard(now)], [mouse(now)]]))
        await viewModel.refresh()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices.map(\.name), ["PRO X TKL", "MX Master 3S"])
        XCTAssertEqual(viewModel.devices.first?.readAt, now)
    }

    func testReadingOlderThanADayIsDropped() async {
        let old = Date.now.addingTimeInterval(-DeviceListViewModel.keepFor - 60)
        let viewModel = DeviceListViewModel(scanner: ScriptedScanner([[keyboard(old)], []]))
        await viewModel.refresh()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices, [])
    }

    /// #100: receptor que parou de responder fica no fim da lista, atrás de quem respondeu ao último scan.
    func testUnseenReceiverDeviceSortsAfterConnectedOnes() async {
        let headset = Device(id: "bt-headset", name: "QCY MeloBuds Pro", kind: .headphones, percent: 100,
                             chargeState: .unknown, path: .bluetooth, readAt: .now)
        let earlier = mouse(.now.addingTimeInterval(-600))
        let viewModel = DeviceListViewModel(scanner: ScriptedScanner([[earlier, headset], [headset]]))
        await viewModel.refresh()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices.map(\.name), ["QCY MeloBuds Pro", "MX Master 3S"])
    }

    /// #100: mouse Bluetooth fora do scan foi desconectado (o sistema sabe na hora): some, sem esperar 24 h.
    func testUnseenBluetoothDeviceIsDropped() async {
        let bluetoothMouse = Device(id: "ble:1", name: "MX Master 3S", kind: .mouse, percent: 85,
                                    chargeState: .discharging, path: .bluetooth, readAt: .now)
        let viewModel = DeviceListViewModel(scanner: ScriptedScanner([[bluetoothMouse], []]))
        await viewModel.refresh()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices, [])
    }

    /// Fone fora do scan foi desligado ou guardado (o sistema sabe na hora): some, como no widget da Apple.
    func testDisconnectedHeadsetIsNotKept() async {
        let headset = Device(id: "bt-headset", name: "QCY MeloBuds Pro", kind: .headphones, percent: 100,
                             chargeState: .unknown, path: .bluetooth, readAt: .now)
        let viewModel = DeviceListViewModel(scanner: ScriptedScanner([[mouse(.now), headset], [mouse(.now)]]))
        await viewModel.refresh()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices.map(\.name), ["MX Master 3S"])
    }

    /// Issue #70: fone conectado que veio sem nível nesta leitura mantém a última leitura (cinza depois de 30 min).
    func testConnectedHeadsetWithoutLevelKeepsLastReading() async {
        let before = Date.now.addingTimeInterval(-60)
        let known = Device(id: "bt-audio-QCY", name: "QCY MeloBuds Pro", kind: .headphones, percent: 80,
                           chargeState: .unknown, path: .bluetooth, readAt: before)
        let noLevel = Device(id: "bt-audio-QCY", name: "QCY MeloBuds Pro", kind: .headphones, percent: nil,
                             chargeState: .unknown, path: .bluetooth, readAt: .now)
        let viewModel = DeviceListViewModel(scanner: ScriptedScanner([[known], [noLevel]]))
        await viewModel.refresh()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.devices, [known])
    }

    func testDeviceBackWithNewIdReplacesKeptReading() async {
        let back = keyboard(.now, id: "ble-b382-3:255")
        let viewModel = DeviceListViewModel(scanner: ScriptedScanner([[keyboard(.now)], [], [back]]))
        for _ in 0..<3 { await viewModel.refresh() }
        XCTAssertEqual(viewModel.devices, [back])
    }
}
