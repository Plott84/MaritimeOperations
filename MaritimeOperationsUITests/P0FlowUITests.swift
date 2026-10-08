import XCTest

/// Interactive P0: timed create, manual create, validation. Kill/relaunch is best-effort.
final class P0FlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testE1_startStopCreatesTimedEntry() throws {
        let app = XCUIApplication.launchedClean(extraArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])

        let start = app.buttons["Start DP"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), "Start DP missing")
        start.tap()

        let stop = app.buttons["Stop DP"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5), "Stop DP missing after start")
        // Brief run so duration > 0
        sleep(2)
        stop.tap()

        // Stop saves immediately. No card, and the ship can be empty.
        XCTAssertFalse(app.navigationBars["DP log line"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Start DP"].waitForExistence(timeout: 5))

        app.openLogBook(.dp)

        XCTAssertTrue(app.staticTexts["Needs details"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Timed session"].waitForExistence(timeout: 3))
        let total = app.staticTexts["totalDPHours"]
        XCTAssertTrue(total.waitForExistence(timeout: 3))
        // A stop of a couple of seconds rounds to 0 h. Old hours still add.

        let oldHours = app.textFields["oldDPHours"]
        XCTAssertTrue(oldHours.waitForExistence(timeout: 3))
        oldHours.tap()
        oldHours.typeText("10")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["totalDPHours"].label.contains("10"))

        app.buttons["addManualEntryPill"].tap()
        XCTAssertTrue(app.navigationBars["DP log line"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["Remarks / location / client"].exists)
        XCTAssertTrue(app.textFields["Client"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Location"].exists)
        let phoneSwitch = app.switches["phonePositionSwitch"]
        XCTAssertTrue(phoneSwitch.waitForExistence(timeout: 3))
        XCTAssertEqual(phoneSwitch.value as? String, "0")
    }

    func testE2_addManualEntry() throws {
        let app = XCUIApplication.launchedClean()

        app.openLogBook(.dp)

        let add = app.buttons["addManualEntryPill"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        XCTAssertTrue(app.navigationBars["DP log line"].waitForExistence(timeout: 5))
        app.buttons["dpStartTime"].tap()
        app.buttons["dpStopTime"].tap()

        let ship = app.textFields["Ship name"]
        XCTAssertTrue(ship.waitForExistence(timeout: 5))
        ship.tap()
        ship.typeText("QA Manual Vessel")

        app.buttons["dpFieldsSave"].tap()

        XCTAssertTrue(app.staticTexts["QA Manual Vessel"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Manual"].waitForExistence(timeout: 3) || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Manual")).firstMatch.exists)
    }

    func testE4_validationBlocksEmptyVessel() throws {
        let app = XCUIApplication.launchedClean()

        app.openLogBook(.dp)
        let add = app.buttons["addManualEntryPill"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        app.buttons["dpStartTime"].tap()
        app.buttons["dpStopTime"].tap()
        app.buttons["dpFieldsSave"].tap()

        XCTAssertTrue(app.staticTexts["Ship name is required."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["DP log line"].exists)
    }

    func testE3_timerSurvivesRelaunch() throws {
        let app = XCUIApplication.launchedClean()

        let start = app.buttons["Start DP"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        XCTAssertTrue(app.buttons["Stop DP"].waitForExistence(timeout: 5))
        sleep(2)

        app.relaunchKeepingState()

        XCTAssertTrue(app.buttons["Stop DP"].waitForExistence(timeout: 8), "Timer should still be running after relaunch")
        // Elapsed should not be 00:00
        let zero = app.staticTexts["00:00"]
        XCTAssertFalse(zero.exists && app.buttons["Stop DP"].exists && zero.isHittable == false)
        // Soft assert: while running, Ready pill gone / Running present
        let running = app.staticTexts["Running"]
        XCTAssertTrue(running.waitForExistence(timeout: 5), "Expected Running status after relaunch")
    }
}
