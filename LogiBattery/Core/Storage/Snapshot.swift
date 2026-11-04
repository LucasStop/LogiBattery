import Foundation
import Security

/// Última leitura de cada aparelho. O host escreve, o widget lê (docs/API.md, ADR 0001).
struct Snapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    /// Mínimo sem snapshot novo para o app contar como parado; com intervalo longo vale `2 × intervalo` (#116).
    static let staleAfter: TimeInterval = 30 * 60

    let schemaVersion: Int
    let generatedAt: Date
    let devices: [Device]
    /// Opcional: snapshot gravado antes do campo existir cai no padrão (docs/API.md).
    var thresholds: BatteryThresholds?
    /// Intervalo de leitura dos Ajustes, para o widget saber quando o app parou. Opcional como `thresholds`.
    var intervalMinutes: Int?

    var levelThresholds: BatteryThresholds { thresholds ?? BatteryThresholds() }

    /// App parado: nenhum snapshot novo em duas leituras (no mínimo 30 min). Não é o cinza da linha (`isGray`).
    func isStale(at date: Date) -> Bool {
        date.timeIntervalSince(generatedAt) > max(Self.staleAfter, 2 * Double(intervalMinutes ?? 1) * 60)
    }

    /// Cinza no widget: app parado ou leitura mantida há mais de `grayAfter`.
    func showsGray(_ device: Device, at date: Date) -> Bool {
        isStale(at: date) || device.isGray(at: date, scanAt: generatedAt)
    }

    /// Folga entre as leituras de um mesmo scan; quem ficou para trás disso não respondeu ao último scan.
    static let sameScanTolerance: TimeInterval = 30

    /// Mac primeiro (como no widget da Apple), depois quem respondeu ao scan de `scanAt`, do menor nível ao maior,
    /// sem leitura por último; dormindo ou desconectado (leitura mantida) vai para o fim (DESIGN.md §listas).
    static func widgetOrder(_ devices: [Device], scanAt: Date) -> [Device] {
        func rank(_ device: Device) -> [Int] {
            [device.kind == .laptop ? 0 : 1, device.isKept(scanAt: scanAt) ? 1 : 0, device.percent ?? .max]
        }
        return devices.sorted { rank($0).lexicographicallyPrecedes(rank($1)) }
    }

    /// Muda o que o widget mostra? `readAt` avança a cada leitura e não conta (o "há X min" anda pela timeline);
    /// recarregar o widget a cada leitura esgota o orçamento do WidgetKit.
    static func meaningfullyDiffers(_ old: [Device], _ new: [Device], at date: Date) -> Bool {
        func shown(_ devices: [Device]) -> Set<[String]> {
            Set(devices.map {
                [$0.identity, $0.percent.map(String.init) ?? "", $0.chargeState.rawValue, $0.path.rawValue,
                 $0.kind.rawValue, String($0.isGray(at: date, scanAt: date))]
            })
        }
        return shown(old) != shown(new)
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

    func write(_ devices: [Device], at date: Date, thresholds: BatteryThresholds = BatteryThresholds(),
               intervalMinutes: Int = 1) throws {
        let snapshot = Snapshot(schemaVersion: Snapshot.schemaVersion, generatedAt: date, devices: devices,
                                thresholds: thresholds, intervalMinutes: intervalMinutes)
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
