import XCTest

/// Home book on Main. HB-04 (five Crane rows) is covered in HomeBookTests; this file
/// walks the phone: default DP, Crane swap, relaunch, CTAs, and the Entries star.
final class HomeBookUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHB01_defaultIsDPWithoutStarredStrip() throws {
        let app = XCUIApplication.launchedClean()
        XCTAssertTrue(app.staticTexts["DP TIMER"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Start DP"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["New Rig Move"].exists)
        XCTAssertTrue(app.staticTexts["00:00"].exists)
        XCTAssertFalse(app.staticTexts["STARRED"].exists)
        XCTAssertFalse(app.staticTexts["Your books"].exists)
        XCTAssertFalse(app.buttons["mainEditStarredBooks"].exists)

        let chip = app.buttons["homeBookChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertTrue(chip.label.contains("Home book"))
        XCTAssertTrue(chip.label.contains("D P"))
        XCTAssertTrue(app.buttons["homeBookStar"].label.contains("Home book"))
        XCTAssertTrue(app.buttons["homeBookStar"].label.contains("D P"))
        XCTAssertTrue(app.staticTexts["5 latest · DP"].exists)
        XCTAssertEqual(app.buttons["tab_log"].label, "Entries")
        XCTAssertTrue(app.buttons["tab_rigMoves"].exists)
        XCTAssertEqual(app.buttons["tab_rigMoves"].label, "Rig Moves")
    }

    func testHB02_craneSwapHidesDPTimer() throws {
        let app = XCUIApplication.launchedClean()
        app.buttons["homeBookStar"].tap()
        let crane = app.buttons["homeBookOption_crane"]
        XCTAssertTrue(crane.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Main shows this book\u{2019}s quick-start. Change anytime."].exists)
        XCTAssertTrue(app.buttons["homeBookOption_dp"].isSelected)
        XCTAssertFalse(crane.isSelected)
        crane.tap()

        XCTAssertTrue(app.staticTexts["CRANE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["New lift"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Open Crane log"].exists)
        XCTAssertFalse(app.staticTexts["DP TIMER"].exists)
        XCTAssertFalse(app.staticTexts["00:00"].exists)
        XCTAssertFalse(app.buttons["Start DP"].exists)
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["startDPNewWatch"].exists)
        XCTAssertTrue(app.buttons["homeBookChip"].label.contains("Crane"))
        XCTAssertTrue(app.staticTexts["5 latest · Crane"].exists)
        XCTAssertTrue(app.staticTexts["No Crane entries yet."].exists)
        XCTAssertTrue(app.staticTexts["Newest 5 Crane entries. DP timer is not on this Home."].exists)
    }

    func testHB02_chipOpensTheSamePicker() throws {
        let app = XCUIApplication.launchedClean()
        app.buttons["homeBookChip"].tap()
        XCTAssertTrue(app.buttons["homeBookOption_dp"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["homeBookOption_ah"].exists)
        XCTAssertTrue(app.buttons["homeBookOption_rov"].exists)
        XCTAssertTrue(app.buttons["homeBookOption_dp"].isSelected)
        app.buttons["homeBookClose"].tap()
        XCTAssertTrue(app.staticTexts["DP TIMER"].waitForExistence(timeout: 3))
    }

    func testHB03_cranePersistsAcrossRelaunch() throws {
        let app = openCraneHome()
        app.relaunchKeepingState()
        XCTAssertTrue(app.staticTexts["CRANE"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["DP TIMER"].exists)
        XCTAssertFalse(app.buttons["Start DP"].exists)
        XCTAssertTrue(app.buttons["homeBookChip"].label.contains("Crane"))
    }

    func testHB05_newLiftOpensCraneForm() throws {
        let app = openCraneHome()
        app.buttons["New lift"].tap()
        XCTAssertTrue(app.navigationBars["New crane entry"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.descendants(matching: .any)["craneEntrySheet"].exists)
    }

    func testHB06_openCraneLogScopesEntries() throws {
        let app = openCraneHome()
        app.buttons["Open Crane log"].tap()
        XCTAssertTrue(app.navigationBars["Crane"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["No crane entries yet."].exists)
    }

    func testHB07_startDPKeepsPrefill() throws {
        let app = XCUIApplication.launchedClean()
        XCTAssertTrue(app.descendants(matching: .any)["startDPNewWatch"].waitForExistence(timeout: 8))
        app.buttons["Start DP"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Stop DP"].firstMatch.waitForExistence(timeout: 5))
    }

    /// Largest Dynamic Type (AX5). Buttons stay in the tree and can be tapped; titles are not clipped away.
    func testHB10_largestDynamicTypeKeepsCTAs() throws {
        let app = XCUIApplication.launchedClean(extraArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])
        let start = app.buttons["Start DP"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(start.frame.height, 43)
        XCTAssertTrue(app.staticTexts["DP TIMER"].exists)
        XCTAssertTrue(app.buttons["New Rig Move"].exists)
        XCTAssertTrue(app.staticTexts["Latest Activity"].exists)

        app.buttons["homeBookStar"].tap()
        let crane = app.buttons["homeBookOption_crane"]
        XCTAssertTrue(crane.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(crane.frame.height, 43)
        crane.tap()

        let lift = app.buttons["New lift"]
        XCTAssertTrue(lift.waitForExistence(timeout: 5))
        var swipes = 0
        while !lift.isHittable && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(lift.isHittable)
        XCTAssertGreaterThan(lift.frame.height, 43)
        XCTAssertTrue(app.buttons["Open Crane log"].exists)
        XCTAssertFalse(app.staticTexts["DP TIMER"].exists)
    }

    func testHB08_logStarReplacesHomeBook() throws {
        let app = XCUIApplication.launchedClean()
        app.buttons["tab_log"].tap()
        let dpStar = app.buttons["logBookStar_dp"]
        XCTAssertTrue(dpStar.waitForExistence(timeout: 5))
        XCTAssertTrue(dpStar.isSelected)
        let ahStar = app.buttons["logBookStar_anchorHandling"]
        var swipes = 0
        while !ahStar.isHittable && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        ahStar.tap()
        XCTAssertTrue(ahStar.isSelected)
        XCTAssertFalse(dpStar.isSelected)
        app.buttons["tab_main"].tap()
        XCTAssertTrue(app.staticTexts["ANCHOR HANDLING"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["DP TIMER"].exists)
        XCTAssertTrue(app.buttons["New rig move"].exists)
        XCTAssertFalse(app.buttons["Start DP"].exists)
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
    }

    private func openCraneHome() -> XCUIApplication {
        let app = XCUIApplication.launchedClean()
        XCTAssertTrue(app.buttons["homeBookStar"].waitForExistence(timeout: 8))
        app.buttons["homeBookStar"].tap()
        let crane = app.buttons["homeBookOption_crane"]
        XCTAssertTrue(crane.waitForExistence(timeout: 5))
        crane.tap()
        XCTAssertTrue(app.buttons["New lift"].waitForExistence(timeout: 5))
        return app
    }
}
