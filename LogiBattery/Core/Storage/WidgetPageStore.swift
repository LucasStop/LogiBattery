import Foundation

struct WidgetPageSlice<Item: Equatable>: Equatable, Sendable where Item: Sendable {
    let items: [Item]
    let page: Int
    let pageCount: Int
    let startItem: Int
    let endItem: Int
    let totalItems: Int

    var isPaged: Bool { pageCount > 1 }
}

enum WidgetPage {
    static let mediumPerPage = 4
    static let largePerPage = 6
    /// Com 5 ou mais aparelhos no widget grande o gráfico de 24 h sai para caberem até 6 linhas por página (T09, #79).
    static let largeChartMaxDevices = 4

    static func slice<Item: Equatable & Sendable>(
        _ items: [Item],
        page: Int,
        perPage: Int
    ) -> WidgetPageSlice<Item> {
        guard !items.isEmpty, perPage > 0 else {
            return WidgetPageSlice(items: [], page: 0, pageCount: 1, startItem: 0, endItem: 0, totalItems: 0)
        }
        let pageCount = (items.count + perPage - 1) / perPage
        let normalized = ((page % pageCount) + pageCount) % pageCount
        let start = normalized * perPage
        let end = min(start + perPage, items.count)
        return WidgetPageSlice(
            items: Array(items[start..<end]),
            page: normalized,
            pageCount: pageCount,
            startItem: start + 1,
            endItem: end,
            totalItems: items.count
        )
    }
}

/// Guarda a página atual dos widgets médio e grande no container do App Group (#79, T09 opção A).
struct WidgetPageStore: Sendable {
    let directory: URL
    private var file: URL { directory.appendingPathComponent("widget-pages.json") }

    static var appGroup: WidgetPageStore? {
        SnapshotStore.appGroup.map { WidgetPageStore(directory: $0.directory) }
    }

    func page(for family: String) -> Int {
        readAll()[family] ?? 0
    }

    @discardableResult
    func advance(family: String, pageCount: Int) -> Int {
        guard pageCount > 1 else {
            write(family: family, page: 0)
            return 0
        }
        let current = ((page(for: family) % pageCount) + pageCount) % pageCount
        let next = (current + 1) % pageCount
        write(family: family, page: next)
        return next
    }

    private func readAll() -> [String: Int] {
        guard let data = try? Data(contentsOf: file),
              let map = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return map
    }

    private func write(family: String, page: Int) {
        var map = readAll()
        map[family] = page
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
