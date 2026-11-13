import Foundation
import Observation

/// Canal com o fone, atrás de protocolo para os testes trocarem o CoreBluetooth por um fake.
protocol QCYLink: AnyObject, Sendable {
    var onState: (@Sendable (QCYState) -> Void)? { get set }
    var onAdvertisement: (@Sendable (QCYAdvertisement) -> Void)? { get set }
    var onReady: (@Sendable () -> Void)? { get set }
    var onDisconnect: (@Sendable () -> Void)? { get set }
    func start()
    func stop()
    func refresh()
    func send(_ packet: QCYPacket)
}

extension QCYClient: QCYLink {}

/// Cena de ANC que a tela oferece. O `0x17` é a única via de escrita (o `0x0C` não responde no MeloBuds Pro);
/// os bytes são os medidos em `docs/QCY.md` §5.
enum QCYANCChoice: CaseIterable, Equatable, Sendable {
    case anc, normal, transparency

    var packet: QCYPacket {
        switch self {
        case .anc: .ancSetting(mode: 0x01, subScene: 0x02, noiseValue: 0x03)
        case .normal: .ancSetting(mode: 0x02, subScene: 0x00, noiseValue: 0x00)
        case .transparency: .ancSetting(mode: 0x03, subScene: 0x02, noiseValue: 0x00)
        }
    }

    init?(scene: QCYANScene) {
        switch scene.mode {
        case 0x01: self = .anc
        case 0x02: self = .normal
        case 0x03: self = .transparency
        default: return nil
        }
    }
}

/// Escrita enviada e ainda sem eco do fone.
enum QCYPending: Equatable, Sendable {
    case anc(QCYANCChoice)
    case ldac(Bool)
    case game(Bool)
}

/// Estado da janela do fone (T12). O controle só muda depois do eco do fone; sem eco no prazo, ou com o link
/// caído, volta ao valor lido.
@MainActor
@Observable
final class QCYViewModel {
    enum Phase: Equatable { case loading, connected, disconnected }

    private(set) var phase: Phase = .loading
    private(set) var state = QCYState()
    private(set) var address: String?
    private(set) var pending: QCYPending?
    private(set) var writeFailed = false
    let isReadOnly: Bool

    @ObservationIgnored private let link: any QCYLink
    @ObservationIgnored private let writeTimeout: Duration
    @ObservationIgnored private let settleTimeout: Duration
    @ObservationIgnored private let pollInterval: Duration
    @ObservationIgnored private var isLinked = false
    @ObservationIgnored private var writeTask: Task<Void, Never>?
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    init(link: any QCYLink, isReadOnly: Bool = false, writeTimeout: Duration = .seconds(3),
         settleTimeout: Duration = .seconds(3), pollInterval: Duration = .seconds(30)) {
        self.link = link
        self.isReadOnly = isReadOnly
        self.writeTimeout = writeTimeout
        self.settleTimeout = settleTimeout
        self.pollInterval = pollInterval
        link.onState = { [weak self] state in Task { @MainActor in self?.receive(state) } }
        link.onAdvertisement = { [weak self] advertisement in Task { @MainActor in self?.receive(advertisement) } }
        link.onReady = { [weak self] in Task { @MainActor in self?.linkReady() } }
        link.onDisconnect = { [weak self] in Task { @MainActor in self?.linkLost() } }
    }

    // MARK: - Leitura

    var ancChoice: QCYANCChoice? { state.ancScene.flatMap(QCYANCChoice.init(scene:)) }
    var ancSelection: QCYANCChoice? {
        if case .anc(let target)? = pending { return target }
        return ancChoice
    }
    var isLDACOn: Bool {
        if case .ldac(let value)? = pending { return value }
        return state.isLDACEnabled ?? false
    }
    var isGameOn: Bool {
        if case .game(let value)? = pending { return value }
        return state.isLowLatencyEnabled ?? false
    }
    var areControlsDisabled: Bool { isReadOnly || phase != .connected || pending != nil }

    // MARK: - Ciclo de vida

    func start() {
        link.start()
        settle(after: settleTimeout) { [self] in
            if phase == .loading, !isLinked { phase = .disconnected }
        }
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: self?.pollInterval ?? .seconds(30))
                guard let self, !Task.isCancelled else { return }
                if phase == .connected, pending == nil { link.refresh() }
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        writeTask?.cancel()
        settleTask?.cancel()
        link.stop()
    }

    /// "Procurar de novo" da tela sem conexão.
    func reconnect() {
        link.stop()
        phase = .loading
        link.start()
        settle(after: settleTimeout) { [self] in
            if phase == .loading, !isLinked { phase = .disconnected }
        }
    }

    /// "Tentar de novo" do erro de escrita: limpa o aviso e relê o retrato.
    func retryAfterFailure() {
        writeFailed = false
        link.refresh()
    }

    // MARK: - Escrita

    func select(_ choice: QCYANCChoice) {
        guard !areControlsDisabled, choice != ancChoice else { return }
        begin(.anc(choice), choice.packet)
    }

    func setLDAC(_ enabled: Bool) {
        guard !areControlsDisabled, enabled != isLDACOn else { return }
        begin(.ldac(enabled), .setLDAC(enabled))
    }

    func setGame(_ enabled: Bool) {
        guard !areControlsDisabled, enabled != isGameOn else { return }
        begin(.game(enabled), .setLowLatency(enabled))
    }

    private func begin(_ write: QCYPending, _ packet: QCYPacket) {
        pending = write
        writeFailed = false
        link.send(packet)
        writeTask?.cancel()
        writeTask = Task { [weak self] in
            try? await Task.sleep(for: self?.writeTimeout ?? .seconds(3))
            guard let self, !Task.isCancelled else { return }
            pending = nil
            writeFailed = true
        }
    }

    // MARK: - Eventos do link

    private func receive(_ newState: QCYState) {
        state = newState
        phase = .connected
        settleTask?.cancel()
        guard let write = pending else { return }
        let confirmed = switch write {
        case .anc(let target): ancChoice == target
        case .ldac(let value): state.isLDACEnabled == value
        case .game(let value): state.isLowLatencyEnabled == value
        }
        if confirmed {
            pending = nil
            writeTask?.cancel()
        }
    }

    private func receive(_ advertisement: QCYAdvertisement) {
        if let mac = advertisement.controlMAC { address = mac }
    }

    /// Características descobertas: o retrato chega logo em seguida. Se não chegar, mostra "sem leitura" em vez
    /// de ficar carregando para sempre.
    private func linkReady() {
        isLinked = true
        settle(after: settleTimeout) { [self] in
            if phase == .loading { phase = .connected }
        }
    }

    private func linkLost() {
        isLinked = false
        phase = .disconnected
        state = QCYState()
        address = nil
        pending = nil
        writeTask?.cancel()
    }

    private func settle(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
