import Foundation
import Security

/// Última leitura de cada aparelho. O host escreve, o widget lê (docs/API.md, ADR 0001).
struct Snapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let staleAfter: TimeInterval = 30 * 60

    let schemaVersion: Int
    let generatedAt: Date
    let devices: [Device]

    func isStale(at date: Date) -> Bool {
        date.timeIntervalSince(generatedAt) > Self.staleAfter
    }

    /// Menor nível primeiro, sem leitura por último (DESIGN.md §listas).
    static func widgetOrder(_ devices: [Device]) -> [Device] {
        devices.sorted { ($0.percent ?? .max) < ($1.percent ?? .max) }
    }
}

struct SnapshotStore: Sendable {
    /// Grupo prefixado com o time (`$(TeamIdentifierPrefix)` nos entitlements): sem o prefixo o macOS barra o
    /// widget no container do host. Lê o valor assinado do próprio processo; nil sem assinatura (testes e CI).
    static var appGroupID: String? {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString,
                                                          nil) as? [String] else { return nil }
        return groups.first { $0.hasSuffix("com.lucasstop.LogiBattery") }
    }

    let directory: URL
    private var file: URL { directory.appendingPathComponent("snapshot.json") }

    init(directory: URL) {
        self.directory = directory
    }

    /// Nil quando o app não está assinado com o App Group (testes e CI sem certificado).
    static var appGroup: SnapshotStore? {
        appGroupID.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
            .map(SnapshotStore.init)
    }

    func write(_ devices: [Device], at date: Date) throws {
        let snapshot = Snapshot(schemaVersion: Snapshot.schemaVersion, generatedAt: date, devices: devices)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: file, options: .atomic)
    }

    // ponytail: versão desconhecida lê como vazio; o "último estado válido" da API.md exigiria guardar cópia anterior.
    func read() -> Snapshot? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(Snapshot.self, from: data),
              snapshot.schemaVersion == Snapshot.schemaVersion else { return nil }
        return snapshot
    }
}
