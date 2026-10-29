import Foundation

struct HistoryPoint: Codable, Equatable, Sendable {
    let deviceId: String
    let deviceName: String
    let percent: Int
    let chargeState: ChargeState
    let timestamp: Date

    /// Série do gráfico: o `deviceId` muda a cada reconexão, então agrupa pelo nome.
    var identity: String { DeviceIdentity.key(deviceName) }
}

/// Histórico de leituras no App Group: o host grava, o app e o widget leem (docs/DATA.md).
struct HistoryStore: Sendable {
    // ponytail: um JSON reescrito de forma atômica; com a poda e o intervalo mínimo fica abaixo de ~2 MB.
    // Migrar para SwiftData se o arquivo crescer ou se precisar de consulta mais rica.
    static let retention: TimeInterval = 90 * 86_400
    static let minInterval: TimeInterval = 30 * 60

    let directory: URL
    private var file: URL { directory.appendingPathComponent("history.json") }

    init(directory: URL) {
        self.directory = directory
    }

    static var appGroup: HistoryStore? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SnapshotStore.appGroupID)
            .map(HistoryStore.init)
    }

    /// Guarda um ponto quando o valor ou o estado mudou, ou depois de `minInterval` sem mudança.
    func record(_ devices: [Device], at now: Date) throws {
        let cutoff = now.addingTimeInterval(-Self.retention)
        let stored = load()
        var points = stored.filter { $0.timestamp >= cutoff }
        var latest = Dictionary(points.map { ($0.identity, $0) }, uniquingKeysWith: { _, new in new })
        for device in devices {
            guard let percent = device.percent else { continue }
            if let last = latest[device.identity], last.percent == percent, last.chargeState == device.chargeState,
               now.timeIntervalSince(last.timestamp) < Self.minInterval { continue }
            let point = HistoryPoint(deviceId: device.id, deviceName: device.name, percent: percent,
                                     chargeState: device.chargeState, timestamp: now)
            points.append(point)
            latest[device.identity] = point
        }
        guard points != stored else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(points).write(to: file, options: .atomic)
    }

    func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try FileManager.default.removeItem(at: file)
    }

    func points(since date: Date) -> [HistoryPoint] {
        load().filter { $0.timestamp >= date }
    }

    private func load() -> [HistoryPoint] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HistoryPoint].self, from: data)) ?? []
    }
}

enum HistoryPeriod: CaseIterable, Sendable {
    case day, week, month

    var interval: TimeInterval {
        switch self {
        case .day: 86_400
        case .week: 7 * 86_400
        case .month: 30 * 86_400
        }
    }
}

/// Uma linha do gráfico; `index` escolhe cor e traço, para a série não depender só da cor.
struct HistorySeries: Equatable, Identifiable, Sendable {
    let deviceId: String
    let deviceName: String
    let index: Int
    let points: [HistoryPoint]

    var id: String { deviceId }

    static func build(_ points: [HistoryPoint], period: HistoryPeriod, now: Date) -> [HistorySeries] {
        let since = now.addingTimeInterval(-period.interval)
        let grouped = Dictionary(grouping: points.filter { $0.timestamp >= since }, by: \.identity)
        return grouped
            .map { id, group in (id, group.sorted { $0.timestamp < $1.timestamp }) }
            .sorted { ($0.1[0].deviceName, $0.0) < ($1.1[0].deviceName, $1.0) }
            .enumerated()
            .map { HistorySeries(deviceId: $1.0, deviceName: $1.1[0].deviceName, index: $0, points: $1.1) }
    }
}
