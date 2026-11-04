import Foundation
import Observation

@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var hasLoaded = false
    private(set) var lastRefresh: Date?
    /// Último aparelho esquecido, para o aviso Desfazer do popover (T11, #113).
    private(set) var forgotten: Device?

    private let scanner: any DeviceScanning
    private var isRefreshing = false
    private let publish: @MainActor ([Device]) -> Void
    private let now: @MainActor () -> Date
    /// Regra de leitura mantida (#116); vira ajuste do usuário na #115.
    var policy = ReadingPolicy()

    /// `publish` recebe cada leitura (snapshot do widget); o padrão não faz nada.
    /// `restoring` mostra a última leitura salva enquanto a primeira leitura nova não termina. Snapshot de app que
    /// estava parado só devolve quem a lista manteria (receptor dentro de `keepFor`): o estado do Bluetooth e do fone
    /// mudou enquanto o app não lia.
    init(scanner: any DeviceScanning, restoring: Snapshot? = nil,
         publish: @escaping @MainActor ([Device]) -> Void = { _ in },
         now: @escaping @MainActor () -> Date = { .now }) {
        self.scanner = scanner
        self.publish = publish
        self.now = now
        guard let restoring else { return }
        let date = now()
        let alive = !restoring.isStale(at: date)
        let restored = restoring.devices.filter {
            alive ? policy.isWithinKeep($0, at: date) : policy.keeps($0, at: date)
        }
        guard !restored.isEmpty else { return }
        devices = Snapshot.widgetOrder(restored, scanAt: restoring.generatedAt)
        lastRefresh = restoring.generatedAt
    }

    /// Aparelho dormindo (o teclado Lightspeed dorme ~12 s parado) não responde e sumiria entre leituras;
    /// fica a última leitura dele (`ReadingPolicy.keeps`), que vai para o fim da lista e fica cinza depois de
    /// `policy.grayAfter`.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let date = now()
        // Fone conectado que o sistema devolveu sem nível agora mantém a última leitura (issue #70).
        let fresh = await scanner.scan().map { device in
            guard device.kind == .headphones, device.percent == nil,
                  let last = devices.first(where: { $0.identity == device.identity && $0.percent != nil })
            else { return device }
            return last
        }
        let seen = Set(fresh.map(\.identity))
        let kept = devices.filter { !seen.contains($0.identity) && policy.keeps($0, at: date) }
        devices = Snapshot.widgetOrder(fresh + kept, scanAt: date)
        if let forgotten, seen.contains(forgotten.identity) { self.forgotten = nil }
        hasLoaded = true
        lastRefresh = date
        publish(devices)
    }

    /// Cinza no popover. Antes da primeira leitura nova tudo é memória do snapshot: conta como mantido.
    func isGray(_ device: Device) -> Bool {
        let date = now()
        return device.isGray(at: date, scanAt: (hasLoaded ? lastRefresh : nil) ?? date, policy: policy)
    }

    /// Só leitura mantida (cinza) pode ser esquecida; quem respondeu agora voltaria na próxima leitura.
    func canForget(_ device: Device) -> Bool { isGray(device) }

    /// Tira da lista e do widget uma leitura mantida; o histórico fica e o aparelho volta se responder a um scan.
    func forget(_ device: Device) {
        guard canForget(device), devices.contains(where: { $0.id == device.id }) else { return }
        devices.removeAll { $0.id == device.id }
        forgotten = device
        publish(devices)
    }

    func undoForget() {
        guard let device = forgotten else { return }
        forgotten = nil
        devices = Snapshot.widgetOrder(devices + [device], scanAt: lastRefresh ?? now())
        publish(devices)
    }

    func dismissForgotten() { forgotten = nil }

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
