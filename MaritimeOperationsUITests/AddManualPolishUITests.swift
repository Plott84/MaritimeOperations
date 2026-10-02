import XCTest

final class AddManualPolishUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openAdd(_ app: XCUIApplication) {
        app.buttons["DP Entries"].tap()
        let add = app.buttons["addManualEntryPill"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.tap()
        XCTAssertTrue(app.navigationBars["DP log line"].waitForExistence(timeout: 5))
    }

    func testEmptyEntriesShowsAddCTA() throws {
        let app = XCUIApplication.launchedClean()
        app.buttons["DP Entries"].tap()
        XCTAssertTrue(
            app.buttons["addManualEntryPill"].waitForExistence(timeout: 8)
            || app.buttons["navAddEntry"].waitForExistence(timeout: 2)
        )
    }

    func testTimesRequiredError() throws {
        let app = XCUIApplication.launchedClean()
        openAdd(app)
        let ship = app.textFields["Ship name"]
        XCTAssertTrue(ship.waitForExistence(timeout: 5))
        ship.tap()
        ship.typeText("QA Vessel")
        app.buttons["dpFieldsSave"].tap()
        XCTAssertTrue(app.staticTexts["Start and stop are required."].waitForExistence(timeout: 5))
    }

    func testCancelWritesNothing() throws {
        let app = XCUIApplication.launchedClean()
        openAdd(app)
        let ship = app.textFields["Ship name"]
        XCTAssertTrue(ship.waitForExistence(timeout: 5))
        ship.tap()
        ship.typeText("Dirty")
        app.buttons["dpFieldsCancel"].tap()
        XCTAssertFalse(app.navigationBars["DP log line"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Dirty"].exists)
    }

    func testPhonePositionSwitchStaysOffOnOpen() throws {
        let app = XCUIApplication.launchedClean()
        openAdd(app)
        let phoneSwitch = app.switches["phonePositionSwitch"]
        XCTAssertTrue(phoneSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(phoneSwitch.value as? String, "0")
        XCTAssertTrue(app.textFields["Location"].exists)
        XCTAssertFalse(app.alerts.element.exists)
    }
}
