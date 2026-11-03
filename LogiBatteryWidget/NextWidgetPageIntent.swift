import AppIntents
import Foundation

/// Avança a página do widget médio ou grande (#79, T09 opção A).
struct NextWidgetPageIntent: AppIntent {
    static let title: LocalizedStringResource = "widget.page.next"
    static let isDiscoverable = false

    @Parameter(title: "Family")
    var family: String

    init() {
        self.family = "medium"
    }

    init(family: String) {
        self.family = family
    }

    func perform() async throws -> some IntentResult {
        if let store = WidgetPageStore.appGroup {
            let count = SnapshotStore.appGroup?.read()?.devices.count ?? 0
            let perPage = family == "large" ? WidgetPage.largePerPage : WidgetPage.mediumPerPage
            let pageCount = max(1, (count + perPage - 1) / perPage)
            store.advance(family: family, pageCount: pageCount)
        }
        return .result()
    }
}
