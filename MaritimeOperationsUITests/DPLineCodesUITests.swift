import XCTest

/// Activity code picker (OT needs Specify) and the logged-ship picker.
final class DPLineCodesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openAdd(_ app: XCUIApplication) {
        app.openLogBook(.dp)
        let add = app.buttons["addManualEntryPill"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.tap()
        XCTAssertTrue(app.navigationBars["DP log line"].waitForExistence(timeout: 5))
        app.buttons["dpStartTime"].tap()
        app.buttons["dpStopTime"].tap()
    }

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !element.isHittable && tries < 5 {
            app.swipeUp()
            tries += 1
        }
    }

    func testOTNeedsSpecifyThenSaves() throws {
        let app = XCUIApplication.launchedClean()
        openAdd(app)

        let ship = app.textFields["Ship name"]
        XCTAssertTrue(ship.waitForExistence(timeout: 5))
        XCTAssertEqual(ship.value as? String ?? "", "Ship name", "Ship name must start empty")
        ship.tap()
        ship.typeText("QA Codes Vessel")

        let picker = app.buttons["dpActivityCode"]
        reveal(picker, in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let ot = app.buttons["OT"]
        XCTAssertTrue(ot.waitForExistence(timeout: 5))
        ot.tap()

        let specify = app.textFields["dpActivitySpecify"]
        XCTAssertTrue(specify.waitForExistence(timeout: 5))
        specify.tap()
        specify.typeText("   ")

        let save = app.buttons["dpFieldsSave"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts["Specify the OT activity."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["DP log line"].exists)

        reveal(specify, in: app)
        specify.tap()
        specify.typeText("Crew change")
        reveal(save, in: app)
        save.tap()
        XCTAssertFalse(app.navigationBars["DP log line"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["QA Codes Vessel"].waitForExistence(timeout: 5))
    }

    func testActivityPickerHidesKeyboardAndListsAnchorHandlingLast() throws {
        let app = XCUIApplication.launchedClean()
        openAdd(app)

        let notes = app.textFields["Notes"]
        reveal(notes, in: app)
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        notes.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Keyboard should be up while typing notes")

        let picker = app.buttons["dpActivityCode"]
        reveal(picker, in: app)
        picker.tap()

        let ot = app.buttons["OT"]
        XCTAssertTrue(ot.waitForExistence(timeout: 5))
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "Opening the activity code menu must hide the keyboard")

        XCTAssertFalse(app.staticTexts["My codes"].exists, "No My codes section header")
        XCTAssertFalse(app.buttons["AH – Anchor handling"].exists)
        let anchor = app.buttons["OT – Anchor handling"]
        XCTAssertTrue(anchor.exists)
        XCTAssertGreaterThan(anchor.frame.minY, ot.frame.minY, "Anchor handling must be listed after OT")
        attachScreenshot(named: "Activity code menu, keyboard hidden")

        anchor.tap()
        XCTAssertFalse(app.textFields["dpActivitySpecify"].waitForExistence(timeout: 2), "Anchor handling needs no Specify")

        // Reopen with Anchor handling selected; the menu shows the bottom of the list.
        picker.tap()
        XCTAssertTrue(anchor.waitForExistence(timeout: 5))
        attachScreenshot(named: "Activity code menu, anchor handling selected")
        anchor.tap()
    }

    func testPickLoggedShipFillsName() throws {
        let app = XCUIApplication.launchedClean()
        openAdd(app)
        let ship = app.textFields["Ship name"]
        XCTAssertTrue(ship.waitForExistence(timeout: 5))
        ship.tap()
        ship.typeText("QA Picker Vessel")
        let save = app.buttons["dpFieldsSave"]
        reveal(save, in: app)
        save.tap()
        XCTAssertFalse(app.navigationBars["DP log line"].waitForExistence(timeout: 3))

        app.buttons["addManualEntryPill"].tap()
        XCTAssertTrue(app.navigationBars["DP log line"].waitForExistence(timeout: 5))
        let pick = app.buttons["pickLoggedShip"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        let option = app.buttons["shipOption_QA Picker Vessel"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertEqual(app.textFields["Ship name"].value as? String, "QA Picker Vessel")
    }
}
