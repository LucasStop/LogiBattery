import Foundation
import IOKit.ps

/// Avisa quando a fonte de energia do Mac muda (plugar, desplugar, % mudou) ou o Modo de Pouca Energia liga/desliga,
/// para o ícone da barra de menus mudar na hora e não só com o popover aberto.
final class PowerEvents: @unchecked Sendable {
    let changes: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private var source: CFRunLoopSource?
    private var observer: NSObjectProtocol?

    init() {
        (changes, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let context = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<PowerEvents>.fromOpaque(context).takeUnretainedValue().continuation.yield()
        }, context)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode) }
        observer = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: nil
        ) { [continuation] _ in continuation.yield() }
    }

    deinit {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
