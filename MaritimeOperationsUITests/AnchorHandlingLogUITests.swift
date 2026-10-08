import XCTest

/// Add an Anchor handling entry and find it in Log.
final class AnchorHandlingLogUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddAHEntryShowsInLog() throws {
        let app = XCUIApplication.launchedClean()

        // Log tab shows both books; AH starts empty.
        app.buttons["tab_log"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["logBook_dp"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["logBook_anchorHandling"].exists)
        XCTAssertTrue(app.staticTexts["Starred books show on Main."].exists)

        app.descendants(matching: .any)["logBook_anchorHandling"].tap()
        XCTAssertTrue(app.staticTexts["No rig moves yet."].waitForExistence(timeout: 5))
        app.buttons["navAddRigMove"].tap()
        XCTAssertTrue(app.navigationBars["New entry"].waitForExistence(timeout: 5))

        let vessel = app.textFields["ahVessel"]
        XCTAssertTrue(vessel.waitForExistence(timeout: 3))
        vessel.tap()
        vessel.typeText("QA AH Vessel")

        let rig = app.textFields["ahRigName"]
        rig.tap()
        rig.typeText("QA AH Rig")
        app.buttons["ahKeyboardDone"].tap()

        app.buttons["ahPositionPicker"].tap()
        let secondOff = app.buttons["2nd Off."]
        XCTAssertTrue(secondOff.waitForExistence(timeout: 3))
        secondOff.tap()

        let preLay = app.buttons["ahJobType_preLay"]
        preLay.swipeUpUntilHittable(in: app)
        preLay.tap()
        XCTAssertTrue(preLay.isSelected)

        let recover = app.buttons["ahTask_recoverAnchor"]
        recover.swipeUpUntilHittable(in: app)
        recover.tap()
        XCTAssertTrue(recover.isSelected)
        app.buttons["ahControl_dp"].tap()
        XCTAssertTrue(app.buttons["ahControl_dp"].isSelected)

        app.buttons["rigMoveSave"].tap()
        XCTAssertFalse(app.navigationBars["New entry"].waitForExistence(timeout: 3))

        // Row in the Anchor handling book.
        let row = app.ahRow(containing: "QA AH Rig")
        XCTAssertTrue(row.waitForExistence(timeout: 6))
        XCTAssertTrue(row.label.contains("Pre-lay"), row.label)
        XCTAssertTrue(row.label.contains("QA AH Vessel"), row.label)
        XCTAssertEqual(app.staticTexts["ahRowCount"].label, "1 row")

        // Back on the Log tab the book card counts it.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let card = app.descendants(matching: .any)["logBook_anchorHandling"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.value as? String, "1 rig moves")

        // Reopen: values were saved on the Rig Move record.
        card.tap()
        app.ahRow(containing: "QA AH Rig").tap()
        XCTAssertTrue(app.navigationBars["Edit entry"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["ahPositionPicker"].value as? String, "Second Officer")
        XCTAssertTrue(app.buttons["ahJobType_preLay"].isSelected)
    }

    /// A new AH entry prefills only the vessel (newest DP line or AH entry); Position stays "Not set".
    func testNewEntryPrefillsVesselButNotPosition() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.anchorHandling)
        app.buttons["navAddRigMove"].tap()
        XCTAssertTrue(app.navigationBars["New entry"].waitForExistence(timeout: 5))
        let vessel = app.textFields["ahVessel"]
        XCTAssertTrue(vessel.waitForExistence(timeout: 3))
        vessel.tap()
        vessel.typeText("QA Prefill Ship")
        let rig = app.textFields["ahRigName"]
        rig.tap()
        rig.typeText("QA Prefill Rig")
        app.buttons["ahKeyboardDone"].tap()
        app.buttons["ahPositionPicker"].tap()
        let secondOff = app.buttons["2nd Off."]
        XCTAssertTrue(secondOff.waitForExistence(timeout: 3))
        secondOff.tap()
        app.buttons["rigMoveSave"].tap()
        XCTAssertTrue(app.ahRow(containing: "QA Prefill Rig").waitForExistence(timeout: 6))

        app.buttons["navAddRigMove"].tap()
        XCTAssertTrue(app.navigationBars["New entry"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["ahVessel"].value as? String, "QA Prefill Ship")
        XCTAssertEqual(app.buttons["ahPositionPicker"].value as? String, "Not set")
    }
}
