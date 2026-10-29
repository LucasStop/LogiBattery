import XCTest
@testable import LogiBattery

@MainActor
final class LoginItemTests: XCTestCase {
    func testReflectsCurrentSystemStatus() {
        let service = FakeLoginService(enabled: true)
        XCTAssertTrue(LoginItemModel(service: service).isEnabled)
    }

    func testEnablingRegistersAndDisablingUnregisters() {
        let service = FakeLoginService(enabled: false)
        let model = LoginItemModel(service: service)
        model.setEnabled(true)
        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(service.calls, ["register"])
        model.setEnabled(false)
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(service.calls, ["register", "unregister"])
    }

    func testFailureKeepsRealStateAndReportsError() {
        let service = FakeLoginService(enabled: false)
        service.failure = true
        let model = LoginItemModel(service: service)
        model.setEnabled(true)
        XCTAssertFalse(model.isEnabled)
        XCTAssertTrue(model.failed)
        service.failure = false
        model.setEnabled(true)
        XCTAssertTrue(model.isEnabled)
        XCTAssertFalse(model.failed)
    }
}

private final class FakeLoginService: LoginItemService {
    struct Failure: Error {}
    var enabled: Bool
    var failure = false
    var calls: [String] = []

    init(enabled: Bool) { self.enabled = enabled }

    var isEnabled: Bool { enabled }

    func register() throws {
        calls.append("register")
        if failure { throw Failure() }
        enabled = true
    }

    func unregister() throws {
        calls.append("unregister")
        if failure { throw Failure() }
        enabled = false
    }
}
