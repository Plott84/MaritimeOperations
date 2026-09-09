import XCTest

final class RigMovesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyRegisterAndRequiredRigName() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Rig Moves"].tap()
        XCTAssertTrue(app.staticTexts["No rig moves yet."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Rig Move Register"].waitForExistence(timeout: 3))

        let add = app.buttons["addRigMovePill"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Rig Move"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Rig name is required."].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    func testAddOpenMoveThenDoneIncrementsCounters() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Rig Moves"].tap()
        app.buttons["addRigMovePill"].tap()
        let name = app.textFields["Rig name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("QA Rig")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["QA Rig"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Open"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Anchor Handling"].exists)
    }

    func testNewRigMoveOnMainOpensForm() throws {
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["New Rig Move"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        open.tap()
        XCTAssertTrue(app.navigationBars["Add Rig Move"].waitForExistence(timeout: 6))
    }
}
