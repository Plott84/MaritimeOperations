import XCTest

final class SwipeDeleteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDPEntrySwipeDeleteCancelKeepsRow() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.dp)

        app.buttons["addManualEntryPill"].tap()
        XCTAssertTrue(app.navigationBars["DP log line"].waitForExistence(timeout: 5))
        app.buttons["dpStartTime"].tap()
        app.buttons["dpStopTime"].tap()
        let ship = app.textFields["Ship name"]
        XCTAssertTrue(ship.waitForExistence(timeout: 5))
        ship.tap()
        ship.typeText("Swipe Keep Vessel")
        app.buttons["dpFieldsSave"].tap()
        XCTAssertTrue(app.staticTexts["Swipe Keep Vessel"].waitForExistence(timeout: 6))

        app.staticTexts["Swipe Keep Vessel"].swipeLeft()
        let swipeDelete = app.buttons["swipeDeleteDPEntry"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3), "Expected red Delete swipe action")
        swipeDelete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Expected delete confirmation alert")
        XCTAssertTrue(
            alert.label.contains("Delete this entry?")
                || app.staticTexts["Delete this entry? Its hours come off your total."].exists,
            "Expected locked confirm copy"
        )
        let cancel = app.buttons["cancelDeleteEntry"].firstMatch.exists
            ? app.buttons["cancelDeleteEntry"].firstMatch
            : alert.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "Expected Cancel on confirm alert")
        cancel.tap()
        XCTAssertTrue(app.staticTexts["Swipe Keep Vessel"].waitForExistence(timeout: 3))
    }

    func testDPEntrySwipeDeleteConfirmRemovesRow() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.dp)

        app.buttons["addManualEntryPill"].tap()
        XCTAssertTrue(app.navigationBars["DP log line"].waitForExistence(timeout: 5))
        app.buttons["dpStartTime"].tap()
        app.buttons["dpStopTime"].tap()
        let ship = app.textFields["Ship name"]
        XCTAssertTrue(ship.waitForExistence(timeout: 5))
        ship.tap()
        ship.typeText("Swipe Drop Vessel")
        app.buttons["dpFieldsSave"].tap()
        XCTAssertTrue(app.staticTexts["Swipe Drop Vessel"].waitForExistence(timeout: 6))

        app.staticTexts["Swipe Drop Vessel"].swipeLeft()
        let swipeDelete = app.buttons["swipeDeleteDPEntry"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3))
        swipeDelete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        let confirm = app.buttons["confirmDeleteEntry"].firstMatch.exists
            ? app.buttons["confirmDeleteEntry"].firstMatch
            : alert.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertFalse(app.staticTexts["Swipe Drop Vessel"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["No entries yet. Add a DP log line, or stop the timer on Main."].waitForExistence(timeout: 4)
        )
    }

    func testRigMoveSwipeDeleteConfirmRemovesRow() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.anchorHandling)
        app.buttons["addRigMovePill"].tap()
        let name = app.textFields["ahRigName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Swipe Drop Rig")
        app.buttons["rigMoveSave"].tap()
        let row = app.ahRow(containing: "Swipe Drop Rig")
        XCTAssertTrue(row.waitForExistence(timeout: 6))

        row.swipeLeft()
        let swipeDelete = app.buttons["swipeDeleteRigMove"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3))
        swipeDelete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        let confirm = app.buttons["confirmDeleteRigMove"].firstMatch.exists
            ? app.buttons["confirmDeleteRigMove"].firstMatch
            : alert.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertFalse(app.ahRow(containing: "Swipe Drop Rig").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No rig moves yet."].waitForExistence(timeout: 4))
    }

    func testRigMoveSwipeDeleteCancelKeepsRow() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.anchorHandling)
        app.buttons["addRigMovePill"].tap()
        let name = app.textFields["ahRigName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Swipe Keep Rig")
        app.buttons["rigMoveSave"].tap()
        let row = app.ahRow(containing: "Swipe Keep Rig")
        XCTAssertTrue(row.waitForExistence(timeout: 6))

        row.swipeLeft()
        let swipeDelete = app.buttons["swipeDeleteRigMove"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3), "Expected red Delete swipe action")
        swipeDelete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Expected delete confirmation alert")
        XCTAssertTrue(
            alert.label.contains("Delete this entry?")
                || app.staticTexts["Delete this entry? Its hours come off your total."].exists,
            "Expected locked confirm copy"
        )
        let cancel = app.buttons["cancelDeleteRigMove"].firstMatch.exists
            ? app.buttons["cancelDeleteRigMove"].firstMatch
            : alert.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "Expected Cancel on confirm alert")
        cancel.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3), "Alert should close on Cancel")
        XCTAssertTrue(app.ahRow(containing: "Swipe Keep Rig").waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["ahRowCount"].label, "1 row")
    }
}
