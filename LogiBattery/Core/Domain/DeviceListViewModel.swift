import Foundation
import Observation

@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var hasLoaded = false

    private let scanner: any DeviceScanning
    private let publish: @MainActor ([Device]) -> Void

    /// `publish` recebe cada leitura (snapshot do widget); o padrão não faz nada.
    init(scanner: any DeviceScanning, publish: @escaping @MainActor ([Device]) -> Void = { _ in }) {
        self.scanner = scanner
        self.publish = publish
    }

    func refresh() async {
        devices = await scanner.scan()
        hasLoaded = true
        publish(devices)
    }

    // ponytail: intervalo fixo; vira ajuste na US-11.
    func poll(every interval: Duration = .seconds(300)) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval)
        }
    }
}
