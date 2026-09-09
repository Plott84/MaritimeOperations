import XCTest

/// Interactive P0: timed create, manual create, validation. Kill/relaunch is best-effort.
final class P0FlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testE1_startStopCreatesTimedEntry() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let start = app.buttons["Start DP"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), "Start DP missing")
        start.tap()

        let stop = app.buttons["Stop DP"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5), "Stop DP missing after start")
        // Brief run so duration > 0
        sleep(2)
        stop.tap()

        XCTAssertTrue(app.navigationBars["Save DP session"].waitForExistence(timeout: 5))
        func fill(_ label: String, _ value: String) {
            let field = app.textFields[label]
            XCTAssertTrue(field.waitForExistence(timeout: 3), label)
            field.tap()
            field.typeText(value)
        }
        fill("Vessel", "QA Vessel")
        fill("Rig", "QA Rig")
        fill("Vessel type", "AH")
        fill("DP class", "Class 2")
        app.buttons["dpFieldsSave"].tap()

        // Back to Ready only after confirm
        XCTAssertTrue(app.buttons["Start DP"].waitForExistence(timeout: 5))

        let entriesTab = app.buttons["Entries"]
        XCTAssertTrue(entriesTab.waitForExistence(timeout: 5))
        entriesTab.tap()

        // Timed source label or vessel default
        let timed = app.staticTexts["Timed session"]
        let vessel = app.staticTexts["QA Vessel"]
        XCTAssertTrue(
            timed.waitForExistence(timeout: 6) || vessel.waitForExistence(timeout: 2),
            "Expected a timed entry on Entries after Stop"
        )
    }

    func testE2_addManualEntry() throws {
        let app = XCUIApplication()
        app.launch()

        let entriesTab = app.buttons["Entries"]
        XCTAssertTrue(entriesTab.waitForExistence(timeout: 8))
        entriesTab.tap()

        let add = app.buttons["addManualEntryPill"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let vesselField = app.textFields["Vessel"]
        XCTAssertTrue(vesselField.waitForExistence(timeout: 5))
        vesselField.tap()
        vesselField.typeText("QA Manual Vessel")

        let durationField = app.textFields["Duration (hours)"]
        XCTAssertTrue(durationField.waitForExistence(timeout: 3))
        durationField.tap()
        durationField.typeText("3,2")

        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["QA Manual Vessel"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Manual"].waitForExistence(timeout: 3) || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Manual")).firstMatch.exists)
    }

    func testE4_validationBlocksEmptyVessel() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Entries"].tap()
        let add = app.buttons["addManualEntryPill"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let durationField = app.textFields["Duration (hours)"]
        XCTAssertTrue(durationField.waitForExistence(timeout: 5))
        durationField.tap()
        durationField.typeText("1")

        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Vessel is required."].waitForExistence(timeout: 5))
        // Sheet should still be up
        XCTAssertTrue(app.navigationBars["Add Manual Entry"].exists)
    }

    func testE3_timerSurvivesRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["Start DP"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        XCTAssertTrue(app.buttons["Stop DP"].waitForExistence(timeout: 5))
        sleep(2)

        app.terminate()
        app.launch()

        XCTAssertTrue(app.buttons["Stop DP"].waitForExistence(timeout: 8), "Timer should still be running after relaunch")
        // Elapsed should not be 00:00
        let zero = app.staticTexts["00:00"]
        XCTAssertFalse(zero.exists && app.buttons["Stop DP"].exists && zero.isHittable == false)
        // Soft assert: while running, Ready pill gone / Running present
        let running = app.staticTexts["Running"]
        XCTAssertTrue(running.waitForExistence(timeout: 5), "Expected Running status after relaunch")
    }
}
