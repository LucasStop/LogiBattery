import Foundation
import Observation

@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var hasLoaded = false
    private(set) var lastRefresh: Date?

    private let scanner: any DeviceScanning
    private var isRefreshing = false
    private let publish: @MainActor ([Device]) -> Void

    /// `publish` recebe cada leitura (snapshot do widget); o padrão não faz nada.
    /// `restoring` mostra a última leitura salva enquanto a primeira leitura nova não termina; snapshot velho não vale.
    init(scanner: any DeviceScanning, restoring: Snapshot? = nil, now: Date = .now,
         publish: @escaping @MainActor ([Device]) -> Void = { _ in }) {
        self.scanner = scanner
        self.publish = publish
        if let restoring, !restoring.isStale(at: now) {
            devices = Snapshot.widgetOrder(restoring.devices.filter { DeviceIdentity.isPrintable($0.name) })
            lastRefresh = restoring.generatedAt
        }
    }

    /// Quanto tempo a última leitura de um aparelho que não respondeu continua na lista.
    static let keepFor: TimeInterval = 24 * 3600

    /// Aparelho dormindo (o teclado Lightspeed dorme ~12 s parado) não responde e sumiria entre leituras;
    /// fica a última leitura dele, que passa a cinza depois de `Snapshot.staleAfter` e vai para o fim da lista.
    /// Fone e aparelho Bluetooth fora do scan foram desligados (o sistema sabe na hora) e somem, como no widget da
    /// Apple (#100).
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let now = Date.now
        // Fone conectado que o sistema devolveu sem nível agora mantém a última leitura (issue #70).
        let fresh = await scanner.scan().map { device in
            guard device.kind == .headphones, device.percent == nil,
                  let last = devices.first(where: { $0.identity == device.identity && $0.percent != nil })
            else { return device }
            return last
        }
        let seen = Set(fresh.map(\.identity))
        let kept = devices.filter {
            $0.kind != .headphones && $0.path != .bluetooth && DeviceIdentity.isPrintable($0.name)
                && !seen.contains($0.identity) && now.timeIntervalSince($0.readAt) < Self.keepFor
        }
        devices = Snapshot.widgetOrder(fresh + kept)
        hasLoaded = true
        lastRefresh = now
        publish(devices)
    }

    /// O ícone da barra de menu mostra o menor nível entre os aparelhos com leitura.
    var menuBarPercent: Int? { devices.compactMap(\.percent).min() }

    var menuBarSymbol: String {
        menuBarPercent.map(Self.symbol(forPercent:)) ?? (hasLoaded ? "questionmark.circle" : "ellipsis.circle")
    }

    static func symbol(forPercent percent: Int) -> String {
        switch percent {
        case 88...: "battery.100"
        case 63..<88: "battery.75"
        case 38..<63: "battery.50"
        case 13..<38: "battery.25"
        default: "battery.0"
        }
    }

    /// Leitura periódica mais releitura quando um aparelho conecta, desconecta ou manda aviso de bateria.
    func run(interval: @escaping @MainActor () -> Duration, changes: AsyncStream<Void>,
             debounce: Duration = .seconds(2), minGap: Duration = .seconds(5),
             settle: [Duration] = [.seconds(5), .seconds(10), .seconds(15)]) async {
        let polling = Task { await poll(interval: interval) }
        defer { polling.cancel() }
        await react(to: changes, debounce: debounce, minGap: minGap, settle: settle)
    }

    // ponytail: o intervalo novo vale depois da espera em curso; cancelar o sono ao mudar o ajuste se incomodar.
    func poll(interval: @escaping @MainActor () -> Duration = { .seconds(60) }) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval())
        }
    }

    /// Espera o aparelho terminar de conectar (`debounce`) e limita a frequência (`minGap`) para uma rajada de
    /// eventos virar uma leitura só.
    /// Aparelho que acabou de conectar (ex.: mouse trocando para Bluetooth) ainda dorme e não responde à primeira
    /// leitura; `settle` repete a leitura em intervalos curtos em vez de esperar o próximo ciclo de 1 min.
    private func react(to changes: AsyncStream<Void>, debounce: Duration, minGap: Duration,
                       settle: [Duration]) async {
        var iterator = changes.makeAsyncIterator()
        while await iterator.next() != nil {
            try? await Task.sleep(for: debounce)
            if Task.isCancelled { return }
            await refresh()
            for wait in settle {
                try? await Task.sleep(for: wait)
                if Task.isCancelled { return }
                await refresh()
            }
            try? await Task.sleep(for: minGap)
        }
    }
}
