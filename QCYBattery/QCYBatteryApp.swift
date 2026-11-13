import SwiftUI

/// App separado do fone QCY (ADR 0005): janela única, sem menu de barra, widget nem histórico (T12, #135).
@main
struct QCYBatteryApp: App {
    @State private var model = QCYViewModel(link: QCYClient(),
                                            isReadOnly: CommandLine.arguments.contains("--read-only"))

    var body: some Scene {
        Window("qcy.window", id: "main") {
            QCYView(model: model)
                .task {
                    // O host dos testes é o app: sem isso ele escaneia Bluetooth durante o `xcodebuild test`.
                    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
                    model.start()
                }
        }
        .windowResizability(.contentSize)
    }
}
