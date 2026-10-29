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
            devices = Snapshot.widgetOrder(restoring.devices)
            lastRefresh = restoring.generatedAt
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        devices = Snapshot.widgetOrder(await scanner.scan())
        hasLoaded = true
        lastRefresh = .now
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
             debounce: Duration = .seconds(2), minGap: Duration = .seconds(5)) async {
        let polling = Task { await poll(interval: interval) }
        defer { polling.cancel() }
        await react(to: changes, debounce: debounce, minGap: minGap)
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
    private func react(to changes: AsyncStream<Void>, debounce: Duration, minGap: Duration) async {
        var iterator = changes.makeAsyncIterator()
        while await iterator.next() != nil {
            try? await Task.sleep(for: debounce)
            if Task.isCancelled { return }
            await refresh()
            try? await Task.sleep(for: minGap)
        }
    }
}
