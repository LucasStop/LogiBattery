import XCTest
@testable import LogiBattery

/// Histórias do ciclo de vida de um aparelho na lista (#116): aparece, dorme, fica cinza, some, volta. Cada teste
/// conta uma história com relógio falso; quando uma quebra, o nome do teste diz qual comportamento regrediu
/// (US-01, US-13). Tempos em segundos a partir de `Date(timeIntervalSince1970: 1_800_000_000)`.
@MainActor
final class DeviceLifecycleScenarioTests: XCTestCase {
    private let minute: TimeInterval = 60
    private let hour: TimeInterval = 3600

    private let clock = StoryClock(Date(timeIntervalSince1970: 1_800_000_000))
    private lazy var scanner = StoryScanner(clock: clock)
    private var published: [[Device]] = []

    private func launch(restoring snapshot: Snapshot? = nil, policy: ReadingPolicy = ReadingPolicy())
        -> DeviceListViewModel {
        DeviceListViewModel(scanner: scanner, restoring: snapshot, policy: policy,
                            publish: { [weak self] in self?.published.append($0) }, now: { [clock] in clock.now })
    }

    /// Passa `seconds`, põe `cast` para responder e roda uma leitura.
    private func scan(_ viewModel: DeviceListViewModel, after seconds: TimeInterval, _ cast: [Cast]) async {
        clock.advance(seconds)
        scanner.respond(cast)
        await viewModel.refresh()
    }

    private func names(_ viewModel: DeviceListViewModel) -> [String] { viewModel.devices.map(\.name) }

    private func row(_ cast: Cast, in viewModel: DeviceListViewModel) throws -> Device {
        try XCTUnwrap(viewModel.devices.first { $0.name == cast.name })
    }

    /// Snapshot gravado `age` segundos atrás com as leituras de cada aparelho, cada uma com a sua idade.
    private func snapshot(age: TimeInterval, interval: Int? = nil, _ readings: [(Cast, TimeInterval)]) -> Snapshot {
        Snapshot(schemaVersion: Snapshot.schemaVersion, generatedAt: clock.now.addingTimeInterval(-age),
                 devices: readings.map { $0.0.device(readAt: clock.now.addingTimeInterval(-$0.1)) },
                 intervalMinutes: interval)
    }

    // MARK: Aparece

    func testDevicesAppearAtLaunchAndLaterOnes() async {
        let viewModel = launch()
        XCTAssertEqual(viewModel.devices, [])
        await scan(viewModel, after: 0, [.mac, .mouse])
        XCTAssertEqual(names(viewModel), ["MacBook", "MX Master 3S"])
        XCTAssertTrue(viewModel.hasLoaded)

        await scan(viewModel, after: minute, [.mac, .mouse, .keyboard, .bluetoothMouse, .headset])
        XCTAssertEqual(names(viewModel),
                       ["MacBook", "MX Anywhere 3", "PRO X TKL", "MX Master 3S", "QCY MeloBuds Pro"])
        XCTAssertEqual(published.last?.count, 5)
    }

    // MARK: Dorme, fica cinza, some

    func testSleepingReceiverDeviceGoesLastTurnsGrayAfterThirtyMinutesAndVanishesAfterADay() async throws {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mouse, .keyboard])
        let lastRead = clock.now
        XCTAssertEqual(names(viewModel), ["PRO X TKL", "MX Master 3S"])

        await scan(viewModel, after: minute, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S", "PRO X TKL"])
        let sleeping = try row(.keyboard, in: viewModel)
        XCTAssertEqual(sleeping.readAt, lastRead)
        XCTAssertFalse(viewModel.isGray(sleeping))
        XCTAssertFalse(viewModel.canForget(sleeping))

        // Borda: aos 30 min exatos ainda não é cinza; um segundo depois é.
        await scan(viewModel, after: 29 * minute, [.mouse])
        XCTAssertFalse(viewModel.isGray(sleeping))
        clock.advance(1)
        XCTAssertTrue(viewModel.isGray(sleeping))
        XCTAssertTrue(viewModel.canForget(sleeping))
        XCTAssertFalse(viewModel.isGray(try row(.mouse, in: viewModel)))

        // Borda: um segundo antes das 24 h ainda está na lista; nas 24 h exatas some.
        await scan(viewModel, after: 24 * hour - 30 * minute - 2, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S", "PRO X TKL"])
        await scan(viewModel, after: 1, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S"])
        XCTAssertEqual(published.last?.map(\.name), ["MX Master 3S"])
    }

    func testSleepingDeviceThatWakesUpComesBackInPlaceAndNotGray() async throws {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mouse, .keyboard])
        await scan(viewModel, after: 40 * minute, [.mouse])
        XCTAssertTrue(viewModel.isGray(try row(.keyboard, in: viewModel)))

        await scan(viewModel, after: minute, [.mouse, .keyboard])
        XCTAssertEqual(names(viewModel), ["PRO X TKL", "MX Master 3S"])
        XCTAssertFalse(viewModel.isGray(try row(.keyboard, in: viewModel)))
    }

    // MARK: Some na hora

    func testBluetoothDeviceAndHeadsetVanishAtOnceWhenTheyLeaveTheScan() async {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mouse, .bluetoothMouse, .headset])
        XCTAssertEqual(viewModel.devices.count, 3)
        await scan(viewModel, after: minute, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S"])
    }

    func testHeadsetWithoutLevelKeepsItsLastLevelAndTurnsGrayLikeAnyKeptReading() async throws {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.headset])
        await scan(viewModel, after: minute, [Cast.headset.withoutLevel()])
        XCTAssertEqual(viewModel.devices.first?.percent, 100)
        XCTAssertFalse(viewModel.isGray(try row(.headset, in: viewModel)))

        await scan(viewModel, after: 30 * minute, [Cast.headset.withoutLevel()])
        XCTAssertEqual(viewModel.devices.first?.percent, 100)
        XCTAssertTrue(viewModel.isGray(try row(.headset, in: viewModel)))
    }

    // MARK: Troca de caminho

    func testSwitchingBetweenReceiverAndBluetoothKeepsASingleRow() async {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.keyboard])
        await scan(viewModel, after: minute, [Cast.keyboard.onBluetooth()])
        XCTAssertEqual(viewModel.devices.map(\.path), [.bluetooth])
        await scan(viewModel, after: minute, [.keyboard])
        XCTAssertEqual(viewModel.devices.map(\.path), [.receiver])
        XCTAssertEqual(published.map(\.count), [1, 1, 1])
    }

    // MARK: Esquecer

    func testForgetUndoAndComingBackByItself() async throws {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mac, .mouse, .keyboard])
        await scan(viewModel, after: 31 * minute, [.mac, .mouse])
        XCTAssertFalse(viewModel.canForget(try row(.mac, in: viewModel)))
        XCTAssertFalse(viewModel.canForget(try row(.mouse, in: viewModel)))
        let kept = try row(.keyboard, in: viewModel)
        XCTAssertTrue(viewModel.canForget(kept))

        viewModel.forget(kept)
        XCTAssertEqual(names(viewModel), ["MacBook", "MX Master 3S"])
        XCTAssertEqual(published.last?.map(\.name), ["MacBook", "MX Master 3S"])

        viewModel.undoForget()
        XCTAssertEqual(names(viewModel), ["MacBook", "MX Master 3S", "PRO X TKL"])
        XCTAssertNil(viewModel.forgotten)

        viewModel.forget(try row(.keyboard, in: viewModel))
        await scan(viewModel, after: minute, [.mac, .mouse, .keyboard])
        XCTAssertEqual(names(viewModel), ["MacBook", "PRO X TKL", "MX Master 3S"])
        XCTAssertNil(viewModel.forgotten)
    }

    // MARK: Abrir o app de novo

    func testRelaunchShowsRecentSnapshotBeforeTheFirstScan() throws {
        let saved = snapshot(age: minute, [(.mouse, minute), (.bluetoothMouse, minute), (.keyboard, 23 * hour)])
        let viewModel = launch(restoring: saved)
        XCTAssertFalse(viewModel.hasLoaded)
        XCTAssertEqual(names(viewModel), ["MX Anywhere 3", "MX Master 3S", "PRO X TKL"])
        XCTAssertFalse(viewModel.isGray(try row(.mouse, in: viewModel)))
        XCTAssertTrue(viewModel.isGray(try row(.keyboard, in: viewModel)))
    }

    /// B2: o restore aceitava leitura mantida de qualquer idade se o snapshot fosse recente.
    func testRelaunchDropsReadingOlderThanADayEvenFromARecentSnapshot() {
        let saved = snapshot(age: minute, [(.mouse, minute), (.keyboard, 25 * hour)])
        XCTAssertEqual(names(launch(restoring: saved)), ["MX Master 3S"])
    }

    /// Com o app parado o estado do Bluetooth e do fone mudou sem ninguém ver: só o receptor volta, até a leitura
    /// seguinte.
    func testRelaunchAfterTheAppWasStoppedKeepsOnlyReceiverReadings() {
        let saved = snapshot(age: 2 * hour, [(.mouse, 2 * hour), (.keyboard, 2 * hour),
                                             (.bluetoothMouse, 2 * hour), (.headset, 2 * hour)])
        XCTAssertEqual(names(launch(restoring: saved)), ["PRO X TKL", "MX Master 3S"])
    }

    // MARK: Intervalo longo

    /// B1: com intervalo de 45 min, quem respondeu ao último scan não pode ficar cinza antes do próximo.
    func testIntervalOfFortyFiveMinutesDoesNotGrayDevicesThatAnsweredTheLastScan() async {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mouse, .keyboard])
        clock.advance(40 * minute)
        XCTAssertFalse(viewModel.devices.contains { viewModel.isGray($0) })
    }

    // MARK: Ajustes de aparelhos sem resposta (#115)

    /// "Ficar cinza depois de" zero: a leitura mantida já aparece cinza no primeiro scan sem resposta.
    func testGrayAfterZeroShowsAKeptReadingGrayAtOnce() async throws {
        let viewModel = launch(policy: ReadingPolicy(grayAfter: 0))
        await scan(viewModel, after: 0, [.mouse, .keyboard])
        await scan(viewModel, after: minute, [.mouse])
        XCTAssertTrue(viewModel.isGray(try row(.keyboard, in: viewModel)))
        XCTAssertFalse(viewModel.isGray(try row(.mouse, in: viewModel)))
    }

    func testShorterGrayAfterTurnsGrayOnItsOwnEdge() async throws {
        let viewModel = launch(policy: ReadingPolicy(grayAfter: 5 * minute))
        await scan(viewModel, after: 0, [.mouse, .keyboard])
        await scan(viewModel, after: 5 * minute, [.mouse])
        let sleeping = try row(.keyboard, in: viewModel)
        XCTAssertFalse(viewModel.isGray(sleeping))
        clock.advance(1)
        XCTAssertTrue(viewModel.isGray(sleeping))
    }

    /// "Sumir sozinho depois de" zero: nenhuma leitura é mantida, nem no scan nem ao reabrir o app.
    func testKeepForZeroDropsASleepingDeviceAtTheNextScanAndRestoresNothing() async {
        let policy = ReadingPolicy(grayAfter: 0, keepFor: 0)
        let viewModel = launch(policy: policy)
        await scan(viewModel, after: 0, [.mouse, .keyboard])
        XCTAssertEqual(viewModel.devices.count, 2)
        await scan(viewModel, after: minute, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S"])

        let saved = snapshot(age: minute, [(.mouse, minute), (.keyboard, minute)])
        XCTAssertEqual(launch(restoring: saved, policy: policy).devices, [])
    }

    func testLongerKeepForKeepsAThreeDayOldReadingUntilTheLimit() async {
        let viewModel = launch(policy: ReadingPolicy(keepFor: 7 * 24 * hour))
        await scan(viewModel, after: 0, [.mouse, .keyboard])
        await scan(viewModel, after: 3 * 24 * hour, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S", "PRO X TKL"])
        await scan(viewModel, after: 4 * 24 * hour - 1, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S", "PRO X TKL"])
        await scan(viewModel, after: 1, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S"])
    }

    /// B3 da revisão #116: ajuste novo vale na hora, sem esperar a próxima leitura, e chega ao snapshot do widget.
    func testApplyingANewPolicyReachesTheListAndThePublishedSnapshotAtOnce() async throws {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mouse, .keyboard])
        await scan(viewModel, after: 10 * minute, [.mouse])
        let sleeping = try row(.keyboard, in: viewModel)
        XCTAssertFalse(viewModel.isGray(sleeping))
        let publishedBefore = published.count

        viewModel.apply(ReadingPolicy(grayAfter: 5 * minute))
        XCTAssertTrue(viewModel.isGray(sleeping))
        XCTAssertEqual(published.count, publishedBefore + 1)

        viewModel.apply(ReadingPolicy(grayAfter: 5 * minute))
        XCTAssertEqual(published.count, publishedBefore + 1, "mesma regra não republica")

        viewModel.apply(ReadingPolicy(grayAfter: 0, keepFor: 5 * minute))
        XCTAssertEqual(names(viewModel), ["MX Master 3S"])
        XCTAssertEqual(published.last?.map(\.name), ["MX Master 3S"])
    }

    /// Quem respondeu ao último scan não é leitura mantida: o ajuste novo não o tira da lista.
    func testApplyingAZeroKeepForKeepsEveryDeviceThatAnsweredTheLastScan() async {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mac, .mouse, .keyboard])
        viewModel.apply(ReadingPolicy(grayAfter: 0, keepFor: 0))
        XCTAssertEqual(names(viewModel), ["MacBook", "PRO X TKL", "MX Master 3S"])
    }

    func testForgetScopeDecidesWhetherAKeptReadingThatIsStillGreenCanBeForgotten() async throws {
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mac, .mouse, .keyboard])
        await scan(viewModel, after: minute, [.mac, .mouse])
        let green = try row(.keyboard, in: viewModel)
        XCTAssertFalse(viewModel.canForget(green), "só cinza é o padrão")

        viewModel.apply(ReadingPolicy(forgetScope: .anyKept))
        XCTAssertTrue(viewModel.canForget(green))
        XCTAssertFalse(viewModel.canForget(try row(.mac, in: viewModel)))
        XCTAssertFalse(viewModel.canForget(try row(.mouse, in: viewModel)))

        viewModel.forget(green)
        XCTAssertEqual(names(viewModel), ["MacBook", "MX Master 3S"])
        XCTAssertEqual(viewModel.forgotten?.name, "PRO X TKL")

        viewModel.apply(ReadingPolicy(forgetScope: .grayOnly))
        XCTAssertEqual(viewModel.forgotten?.name, "PRO X TKL", "o aviso Desfazer continua")
    }

    // MARK: Nome ilegível

    func testUnreadableNameDoesNotLingerAsASleepingDevice() async {
        let garbled = Cast(id: "usb-c548-3:3", name: "Z\u{08}Z\u{08}Z", kind: .other, path: .receiver, percent: 90)
        let viewModel = launch()
        await scan(viewModel, after: 0, [.mouse, garbled])
        await scan(viewModel, after: minute, [.mouse])
        XCTAssertEqual(names(viewModel), ["MX Master 3S"])
    }
}

private struct Cast {
    let id: String
    let name: String
    let kind: DeviceKind
    let path: DevicePath
    let percent: Int?

    static let mac = Cast(id: "mac-internal", name: "MacBook", kind: .laptop, path: .internal, percent: 80)
    static let mouse = Cast(id: "usb-c548-2:2", name: "MX Master 3S", kind: .mouse, path: .receiver, percent: 90)
    static let keyboard = Cast(id: "usb-c547-1:1", name: "PRO X TKL", kind: .keyboard, path: .receiver, percent: 77)
    static let bluetoothMouse = Cast(id: "ble:1", name: "MX Anywhere 3", kind: .mouse, path: .bluetooth, percent: 60)
    static let headset = Cast(id: "bt-audio-QCY MeloBuds Pro", name: "QCY MeloBuds Pro", kind: .headphones,
                              path: .bluetooth, percent: 100)

    func withoutLevel() -> Cast { Cast(id: id, name: name, kind: kind, path: path, percent: nil) }
    func onBluetooth() -> Cast { Cast(id: "ble:2", name: name, kind: kind, path: .bluetooth, percent: percent) }

    func device(readAt: Date) -> Device {
        Device(id: id, name: name, kind: kind, percent: percent, chargeState: .discharging, path: path,
               readAt: readAt)
    }
}

private final class StoryClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) { current = start }

    var now: Date { lock.withLock { current } }

    func advance(_ seconds: TimeInterval) { lock.withLock { current = current.addingTimeInterval(seconds) } }
}

/// Responde com quem está em `respond`, carimbado com a hora do relógio falso, como o scanner real carimba `.now`.
private final class StoryScanner: DeviceScanning, @unchecked Sendable {
    private let clock: StoryClock
    private let lock = NSLock()
    private var cast: [Cast] = []

    init(clock: StoryClock) { self.clock = clock }

    func respond(_ cast: [Cast]) { lock.withLock { self.cast = cast } }

    func scan() async -> [Device] {
        let date = clock.now
        return lock.withLock { cast }.map { $0.device(readAt: date) }
    }
}
