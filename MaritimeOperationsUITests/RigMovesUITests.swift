import XCTest

/// Anchor handling book (Log → Anchor handling) and its entry form. Rows are Rig Move records.
final class RigMovesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyBookAndRequiredRigName() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.anchorHandling)
        XCTAssertTrue(app.staticTexts["No rig moves yet."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Rig moves"].waitForExistence(timeout: 3))

        let add = app.buttons["addRigMovePill"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.navigationBars["New entry"].waitForExistence(timeout: 5))
        app.buttons["rigMoveSave"].tap()
        XCTAssertTrue(app.staticTexts["Rig name is required."].waitForExistence(timeout: 5))
        app.buttons["rigMoveCancel"].tap()
    }

    func testNewRigMoveOnMainOpensForm() throws {
        let app = XCUIApplication.launchedClean()
        let open = app.buttons["New Rig Move"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        open.tap()
        XCTAssertTrue(app.navigationBars["New entry"].waitForExistence(timeout: 6))
    }

    func testFormShowsAHFieldsWithEmptyDefaults() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.anchorHandling)
        app.buttons["addRigMovePill"].tap()
        XCTAssertTrue(app.textFields["ahRigName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["ahVessel"].exists)
        XCTAssertTrue(app.textFields["ahFieldArea"].exists)
        let position = app.buttons["ahPositionPicker"]
        XCTAssertTrue(position.exists)
        XCTAssertEqual(position.value as? String, "Not set")
        XCTAssertEqual(app.buttons["ahUnitTypePicker"].value as? String, "Not set")
        XCTAssertTrue(app.buttons["ahJobType_rigMove"].isSelected, "Job type defaults to Rig move")
        XCTAssertFalse(app.buttons["ahControl_dp"].isSelected)
        XCTAssertFalse(app.buttons["ahControl_manual"].isSelected)
        XCTAssertFalse(app.buttons["ahTask_recoverAnchor"].isSelected)

        // More details is collapsed on a new entry; older rig move fields live inside it.
        XCTAssertFalse(app.textFields["Client or operator"].exists)
        let more = app.buttons["ahMoreDetailsToggle"]
        more.swipeUpUntilHittable(in: app)
        more.tap()
        XCTAssertTrue(app.buttons["ahSupervised_yes"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["ahSupervised_yes"].isSelected)
        XCTAssertFalse(app.buttons["ahSupervised_no"].isSelected)
        XCTAssertTrue(app.textFields["ahWaterDepth"].exists)
    }

    func testPositionPickerOffersEngineersAndABButDPRankPickerDoesNot() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.anchorHandling)
        app.buttons["addRigMovePill"].tap()
        let position = app.buttons["ahPositionPicker"]
        XCTAssertTrue(position.waitForExistence(timeout: 5))
        position.tap()
        XCTAssertTrue(app.buttons["2nd Eng."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["3rd Eng."].exists)
        XCTAssertTrue(app.buttons["AB"].exists)
        let master = app.buttons["Master"].frame.minY
        let ab = app.buttons["AB"].frame.minY
        let chiefEng = app.buttons["Ch. Eng."].frame.minY
        XCTAssertLessThan(master, chiefEng, "Deck officers before engineers")
        XCTAssertLessThan(chiefEng, ab, "AB last")
        app.buttons["AB"].tap()
        XCTAssertEqual(app.buttons["ahPositionPicker"].value as? String, "Able Seaman")
    }
}

extension XCUIElement {
    /// Scrolls the app up until this element can be tapped (form cards below the fold).
    func swipeUpUntilHittable(in app: XCUIApplication, maxSwipes: Int = 6) {
        var swipes = 0
        while !(exists && isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }
}
