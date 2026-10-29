import XCTest

final class LaunchUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) || app.state == .runningForeground)
    }
}
