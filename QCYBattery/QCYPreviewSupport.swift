#if DEBUG
import Foundation

/// Link de mentira só para o canvas do Xcode: não fala com o fone, devolve o estado que o preview injeta.
final class PreviewQCYLink: QCYLink, @unchecked Sendable {
    var onState: (@Sendable (QCYState) -> Void)?
    var onAdvertisement: (@Sendable (QCYAdvertisement) -> Void)?
    var onReady: (@Sendable () -> Void)?
    var onDisconnect: (@Sendable () -> Void)?
    func start() {}
    func stop() {}
    func refresh() {}
    func send(_ packet: QCYPacket) {}
}

enum PreviewScenario { case connected, loading, disconnected }

@MainActor
func previewModel(_ scenario: PreviewScenario, readOnly: Bool = false) -> QCYViewModel {
    let link = PreviewQCYLink()
    let model = QCYViewModel(link: link, isReadOnly: readOnly)
    switch scenario {
    case .connected:
        var state = QCYState()
        state.left = QCYBatteryLevel(raw: 90)
        state.right = QCYBatteryLevel(raw: 0x80 | 64)
        state.ancScene = QCYANScene(mode: 0x01, subScene: 0x02, noiseValue: 0x03)
        state.isLDACEnabled = true
        state.isLowLatencyEnabled = false
        link.onState?(state)
    case .loading:
        break
    case .disconnected:
        link.onDisconnect?()
    }
    return model
}
#endif
