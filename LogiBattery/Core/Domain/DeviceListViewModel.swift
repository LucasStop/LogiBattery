import Foundation
import Observation

@MainActor
@Observable
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var hasLoaded = false

    private let scanner: any DeviceScanning

    init(scanner: any DeviceScanning) {
        self.scanner = scanner
    }

    func refresh() async {
        devices = await scanner.scan()
        hasLoaded = true
    }
}
