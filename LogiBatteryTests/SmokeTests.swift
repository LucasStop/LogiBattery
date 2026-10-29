import XCTest

final class SmokeTests: XCTestCase {
    func testBundleIdentifier() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.lucasstop.LogiBattery")
    }
}
