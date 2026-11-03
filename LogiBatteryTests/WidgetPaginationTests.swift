import XCTest
@testable import LogiBattery

/// Paginação dos widgets médio (4 por página) e grande (6 por página a partir do 7º aparelho, T09, #79).
final class WidgetPaginationTests: XCTestCase {
    private func devices(_ count: Int) -> [Device] {
        (1...count).map { index in
            Device(id: "id-\(index)", name: "Dev \(index)", kind: .mouse, percent: index * 10,
                   chargeState: .discharging, path: .bluetooth, readAt: .now)
        }
    }

    func testMediumDoesNotPageUpToFourDevices() {
        let slice = WidgetPage.slice(devices(4), page: 0, perPage: WidgetPage.mediumPerPage)
        XCTAssertFalse(slice.isPaged)
        XCTAssertEqual(slice.pageCount, 1)
        XCTAssertEqual(slice.items.count, 4)
        XCTAssertEqual(slice.startItem, 1)
        XCTAssertEqual(slice.endItem, 4)
    }

    func testMediumSlicesSevenDevicesAcrossTwoPages() {
        let all = devices(7)
        let first = WidgetPage.slice(all, page: 0, perPage: WidgetPage.mediumPerPage)
        XCTAssertTrue(first.isPaged)
        XCTAssertEqual(first.pageCount, 2)
        XCTAssertEqual(first.items.map(\.id), ["id-1", "id-2", "id-3", "id-4"])

        let second = WidgetPage.slice(all, page: 1, perPage: WidgetPage.mediumPerPage)
        XCTAssertEqual(second.page, 1)
        XCTAssertEqual(second.items.map(\.id), ["id-5", "id-6", "id-7"])
    }

    func testLargeFitsSixDevicesOnSinglePageWithoutPaging() {
        let slice = WidgetPage.slice(devices(6), page: 0, perPage: WidgetPage.largePerPage)
        XCTAssertFalse(slice.isPaged)
        XCTAssertEqual(slice.pageCount, 1)
        XCTAssertEqual(slice.items.count, 6)
    }

    func testLargePagesFromSeventhDeviceOnward() {
        let all = devices(7)
        let first = WidgetPage.slice(all, page: 0, perPage: WidgetPage.largePerPage)
        XCTAssertTrue(first.isPaged)
        XCTAssertEqual(first.pageCount, 2)
        XCTAssertEqual(first.items.count, 6)
        XCTAssertEqual(first.startItem, 1)
        XCTAssertEqual(first.endItem, 6)

        let second = WidgetPage.slice(all, page: 1, perPage: WidgetPage.largePerPage)
        XCTAssertEqual(second.items.map(\.id), ["id-7"])
        XCTAssertEqual(second.startItem, 7)
        XCTAssertEqual(second.endItem, 7)
        XCTAssertEqual(second.totalItems, 7)
    }

    func testSliceWrapsOutOfRangePageWhenDevicesShrink() {
        let slice = WidgetPage.slice(devices(3), page: 1, perPage: WidgetPage.mediumPerPage)
        XCTAssertEqual(slice.page, 0)
        XCTAssertFalse(slice.isPaged)
        XCTAssertEqual(slice.items.count, 3)
    }

    func testStoreAdvancesAndWrapsPerFamily() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = WidgetPageStore(directory: directory)
        XCTAssertEqual(store.page(for: "medium"), 0)
        XCTAssertEqual(store.advance(family: "medium", pageCount: 2), 1)
        XCTAssertEqual(store.page(for: "medium"), 1)
        XCTAssertEqual(store.advance(family: "medium", pageCount: 2), 0)
        XCTAssertEqual(store.page(for: "large"), 0)
    }
}
