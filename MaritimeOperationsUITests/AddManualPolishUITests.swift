import XCTest

final class AddManualPolishUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openAddManual(_ app: XCUIApplication) {
        app.buttons["Entries"].tap()
        let add = app.descendants(matching: .button)
            .matching(NSPredicate(format: "label == %@", "Add Manual Entry"))
            .element(boundBy: 0)
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Manual Entry"].waitForExistence(timeout: 5))
    }

    func testEmptyEntriesShowsAddManualCTA() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Entries"].tap()
        XCTAssertTrue(
            app.navigationBars["Entries"].buttons["Add Manual Entry"].waitForExistence(timeout: 8)
            || app.buttons.matching(NSPredicate(format: "label == %@", "Add Manual Entry")).count > 0
        )
    }

    func testDurationRequiredError() throws {
        let app = XCUIApplication()
        app.launch()
        openAddManual(app)
        let vessel = app.textFields["Vessel"]
        XCTAssertTrue(vessel.waitForExistence(timeout: 5))
        vessel.tap()
        vessel.typeText("QA Vessel")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Duration is required."].waitForExistence(timeout: 5))
    }

    func testDirtyCancelShowsDiscard() throws {
        let app = XCUIApplication()
        app.launch()
        openAddManual(app)
        let vessel = app.textFields["Vessel"]
        XCTAssertTrue(vessel.waitForExistence(timeout: 5))
        vessel.tap()
        vessel.typeText("Dirty")
        // Dismiss keyboard so dialog buttons are hittable
        app.navigationBars["Add Manual Entry"].tap()
        app.buttons["Cancel"].tap()
        let discard = app.buttons["Discard Changes"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "Expected discard confirm when dirty")
        // Prefer Keep Editing if present; else Discard to close
        if app.buttons["Keep Editing"].waitForExistence(timeout: 2) {
            app.buttons["Keep Editing"].tap()
            XCTAssertTrue(app.navigationBars["Add Manual Entry"].exists)
        } else {
            discard.tap()
        }
    }

    func testTranscribeCopyPresent() throws {
        let app = XCUIApplication()
        app.launch()
        openAddManual(app)
        XCTAssertTrue(app.staticTexts["Transcribe a line from your old logbook."].waitForExistence(timeout: 5))
    }
}
