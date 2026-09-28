import XCTest

final class testUITests: XCTestCase {
    func testLaunchShowsMain() throws {
        let app = XCUIApplication.launchedClean()
        XCTAssertTrue(app.staticTexts["Main"].waitForExistence(timeout: 5) || app.buttons["Main"].waitForExistence(timeout: 5))
    }
}
