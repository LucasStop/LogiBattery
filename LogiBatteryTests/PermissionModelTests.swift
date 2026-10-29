import XCTest
@testable import LogiBattery

@MainActor
final class PermissionModelTests: XCTestCase {
    func testGuideShowsWhenAccessIsNotGranted() {
        XCTAssertTrue(PermissionModel(access: FakeAccess(.denied)).needsGuide)
        XCTAssertTrue(PermissionModel(access: FakeAccess(.unknown)).needsGuide)
        XCTAssertFalse(PermissionModel(access: FakeAccess(.granted)).needsGuide)
    }

    func testNotNowHidesGuideButKeepsAttentionBanner() {
        let model = PermissionModel(access: FakeAccess(.denied))
        model.dismiss()
        XCTAssertFalse(model.needsGuide)
        XCTAssertTrue(model.needsAttention)
    }

    func testRefreshPicksUpGrantedAccess() {
        let access = FakeAccess(.denied)
        let model = PermissionModel(access: access)
        access.status = .granted
        model.refresh()
        XCTAssertFalse(model.needsGuide)
        XCTAssertFalse(model.needsAttention)
    }

    func testOpenPrivacyRequestsAccessOnlyWhenNeverAsked() {
        let fresh = FakeAccess(.unknown)
        PermissionModel(access: fresh).openPrivacy()
        XCTAssertEqual(fresh.calls, ["request", "open"])
        let denied = FakeAccess(.denied)
        PermissionModel(access: denied).openPrivacy()
        XCTAssertEqual(denied.calls, ["open"])
    }
}

private final class FakeAccess: InputAccess {
    var status: InputAccessStatus
    var calls: [String] = []

    init(_ status: InputAccessStatus) { self.status = status }

    func request() { calls.append("request") }
    func openPrivacySettings() { calls.append("open") }
}
