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
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertFalse(app.buttons["homeSecondaryCTA"].exists)
        XCTAssertTrue(app.staticTexts["00:00"].exists)
        XCTAssertFalse(app.staticTexts["STARRED"].exists)
        XCTAssertFalse(app.staticTexts["Your books"].exists)
        XCTAssertFalse(app.buttons["mainEditStarredBooks"].exists)

        let chip = app.buttons["homeBookChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertTrue(chip.label.contains("On Main"))
        XCTAssertTrue(chip.label.contains("D P"))
        XCTAssertFalse(chip.label.contains("Crane"))
        XCTAssertTrue(app.buttons["homeBookStar"].label.contains("On Main"))
        XCTAssertTrue(app.buttons["homeBookStar"].label.contains("D P"))
        XCTAssertTrue(app.staticTexts["5 latest · DP"].exists)
        XCTAssertTrue(app.staticTexts["Newest 5 records in the DP book."].exists)
        XCTAssertEqual(app.buttons["tab_log"].label, "Entries")
        XCTAssertFalse(app.buttons["tab_rigMoves"].exists)
    }

    /// HB-11: DP Home idle hero has Start DP and no New Rig Move.
    func testHB11_dpHomeIdleShowsOnlyStartDP() throws {
        let app = XCUIApplication.launchedClean()
        let start = app.buttons["Start DP"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["DP TIMER"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["homeHero_dp"].exists)
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertFalse(app.buttons["homeSecondaryCTA"].exists)
        XCTAssertEqual(app.buttons["homePrimaryCTA"].label, "Start DP")
    }

    /// HB-12: tab bar is Main, Entries, Tools, Export. Each item is a 44 pt hit.
    func testHB12_tabBarHasFourTabsAndNoRigMoves() throws {
        let app = XCUIApplication.launchedClean()
        let tabs = [
            ("tab_main", "Main"),
            ("tab_log", "Entries"),
            ("tab_tools", "Tools"),
            ("tab_export", "Export")
        ]
        for (identifier, title) in tabs {
            let tab = app.buttons[identifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 8), identifier)
            XCTAssertEqual(tab.label, title)
            XCTAssertGreaterThan(tab.frame.height, 43, identifier)
        }
        XCTAssertFalse(app.buttons["tab_rigMoves"].exists)
        let tabButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tab_'"))
        XCTAssertEqual(tabButtons.count, 4)
    }

    func testHB02_craneSwapHidesDPTimer() throws {
        let app = XCUIApplication.launchedClean()
        app.buttons["homeBookStar"].tap()
        let crane = app.buttons["homeBookOption_crane"]
        XCTAssertTrue(crane.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Primary gets the big card. Secondary sits under it. Max two."].exists)
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
        XCTAssertTrue(app.staticTexts["No Crane entries yet"].exists)
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
        XCTAssertGreaterThan(start.frame.height, 43, "Hero CTA hit target")
        XCTAssertEqual(start.label, "Start DP")
        XCTAssertTrue(app.staticTexts["DP TIMER"].exists)
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertTrue(app.staticTexts["Latest Activity"].exists)
        let mainTab = app.buttons["tab_main"]
        XCTAssertGreaterThan(mainTab.frame.height, 43, "Tab hit target at AX5")

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
        XCTAssertGreaterThan(lift.frame.height, 43, "Crane hero CTA hit target")
        XCTAssertEqual(lift.label, "New lift")
        let log = app.buttons["Open Crane log"]
        XCTAssertTrue(log.exists)
        XCTAssertEqual(log.label, "Open Crane log")
        XCTAssertFalse(app.staticTexts["DP TIMER"].exists)
    }

    /// A second Entries star sits under the primary. It does not replace the DP hero.
    func testHB08_secondLogStarSitsUnderThePrimary() throws {
        let app = XCUIApplication.launchedClean()
        app.buttons["tab_log"].tap()
        let dpStar = app.buttons["logBookStar_dp"]
        XCTAssertTrue(dpStar.waitForExistence(timeout: 5))
        XCTAssertTrue(dpStar.isSelected)
        tapLogStar(app, "anchorHandling")
        let ahStar = app.buttons["logBookStar_anchorHandling"]
        XCTAssertTrue(ahStar.isSelected)
        XCTAssertTrue(dpStar.isSelected)
        app.buttons["tab_main"].tap()
        XCTAssertTrue(app.staticTexts["DP TIMER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start DP"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["homeHero_ah"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["homeBookSecondaryCard_ah"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["homeBookSecondaryCTA"].label.contains("New rig move"))
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertFalse(app.buttons["homeSecondaryCTA"].exists)
    }

    /// HB-13a: DP hero, Crane compact card, chip names both, one Latest list.
    func testHB13a_dpHeroAndCraneSecondaryCard() throws {
        let app = starDPThenCrane()
        XCTAssertTrue(app.staticTexts["DP TIMER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["homeHero_dp"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["homeHero_crane"].exists)
        XCTAssertTrue(app.buttons["Start DP"].firstMatch.exists)
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertFalse(app.buttons["homeSecondaryCTA"].exists)
        XCTAssertFalse(app.buttons["Open Crane log"].exists)
        let secondary = app.buttons["homeBookSecondaryCTA"]
        XCTAssertTrue(secondary.waitForExistence(timeout: 3))
        XCTAssertEqual(secondary.label, "Crane on Main, New lift")
        XCTAssertGreaterThan(secondary.frame.height, 43)
        XCTAssertTrue(app.descendants(matching: .any)["homeBookSecondaryCard_crane"].exists)
        XCTAssertEqual(app.staticTexts["homeBookSecondaryStatus"].label, "No entries yet")
        let chip = app.buttons["homeBookChip"]
        XCTAssertTrue(chip.label.contains("D P"))
        XCTAssertTrue(chip.label.contains("Crane"))
        XCTAssertTrue(app.buttons["homeBookStar"].label.contains("Crane"))
        XCTAssertTrue(app.staticTexts["5 latest · DP"].exists)
        XCTAssertFalse(app.staticTexts["5 latest · Crane"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Latest Activity")).count, 1)
        XCTAssertFalse(app.staticTexts["STARRED"].exists)
        XCTAssertFalse(app.buttons["mainEditStarredBooks"].exists)
        let tabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tab_'"))
        XCTAssertEqual(tabs.count, 4)
        XCTAssertFalse(app.buttons["tab_rigMoves"].exists)
    }

    /// HB-13b: starring AH after DP + Crane replaces the secondary. DP stays primary.
    func testHB13b_thirdStarReplacesSecondary() throws {
        let app = starDPThenCrane()
        app.buttons["tab_log"].tap()
        tapLogStar(app, "anchorHandling")
        XCTAssertTrue(app.buttons["logBookStar_dp"].isSelected)
        XCTAssertTrue(app.buttons["logBookStar_anchorHandling"].isSelected)
        XCTAssertFalse(app.buttons["logBookStar_crane"].isSelected)
        app.buttons["tab_main"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["homeHero_dp"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["homeHero_ah"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["homeBookSecondaryCard_crane"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["homeBookSecondaryCard_ah"].exists)
        XCTAssertEqual(app.buttons["homeBookSecondaryCTA"].label, "A H on Main, New rig move")
        XCTAssertTrue(app.buttons["Start DP"].firstMatch.exists)
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertTrue(app.staticTexts["5 latest · DP"].exists)
        XCTAssertTrue(app.buttons["homeBookChip"].label.contains("A H"))
        XCTAssertFalse(app.buttons["homeBookChip"].label.contains("Crane"))
    }

    /// HB-13c: Make primary swaps Crane into the hero and DP into the compact card.
    func testHB13c_makePrimarySwapsTheBooks() throws {
        let app = starDPThenCrane()
        app.buttons["homeBookChip"].tap()
        XCTAssertTrue(app.navigationBars["On Main"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["homeBookOption_dp"].isSelected)
        XCTAssertFalse(app.buttons["homeBookOption_crane"].isSelected)
        let make = app.buttons["homeBookMakePrimary"]
        var swipes = 0
        while !make.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(make.isHittable)
        make.tap()
        XCTAssertTrue(app.descendants(matching: .any)["homeHero_crane"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["homeHero_dp"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["homeBookSecondaryCard_dp"].exists)
        XCTAssertTrue(app.buttons["New lift"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Open Crane log"].exists)
        XCTAssertEqual(app.buttons["homeBookSecondaryCTA"].label, "D P on Main, Start DP")
        XCTAssertEqual(app.staticTexts["homeBookSecondaryStatus"].label, "00:00 · Ready")
        XCTAssertFalse(app.staticTexts["00:00"].exists)
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertTrue(app.staticTexts["5 latest · Crane"].exists)
        XCTAssertFalse(app.staticTexts["5 latest · DP"].exists)
        XCTAssertTrue(app.buttons["homeBookChip"].label.contains("Crane"))
        XCTAssertTrue(app.buttons["homeBookChip"].label.contains("D P"))
    }

    /// HB-13d: with Crane under a DP hero, Latest stays on DP.
    func testHB13d_activityChipStaysOnThePrimary() throws {
        let app = starDPThenCrane()
        XCTAssertTrue(app.staticTexts["5 latest · DP"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Newest 5 records in the DP book."].exists)
        XCTAssertFalse(app.staticTexts["5 latest · Crane"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Latest Activity")).count, 1)
    }

    /// HB-13e: the pair is still there after relaunch.
    func testHB13e_primaryAndSecondaryPersist() throws {
        let app = starDPThenCrane()
        app.relaunchKeepingState()
        XCTAssertTrue(app.descendants(matching: .any)["homeHero_dp"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["homeBookSecondaryCard_crane"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["homeHero_crane"].exists)
        XCTAssertEqual(app.buttons["homeBookSecondaryCTA"].label, "Crane on Main, New lift")
        XCTAssertTrue(app.buttons["homeBookChip"].label.contains("D P"))
        XCTAssertTrue(app.buttons["homeBookChip"].label.contains("Crane"))
        XCTAssertTrue(app.buttons["Start DP"].firstMatch.exists)
        XCTAssertFalse(app.buttons["New Rig Move"].exists)
        XCTAssertFalse(app.buttons["tab_rigMoves"].exists)
    }

    private func starDPThenCrane() -> XCUIApplication {
        let app = XCUIApplication.launchedClean()
        XCTAssertTrue(app.buttons["tab_log"].waitForExistence(timeout: 8))
        app.buttons["tab_log"].tap()
        let dpStar = app.buttons["logBookStar_dp"]
        XCTAssertTrue(dpStar.waitForExistence(timeout: 5))
        XCTAssertTrue(dpStar.isSelected)
        dpStar.tap()
        XCTAssertTrue(dpStar.isSelected, "Clearing the only DP star falls back to DP")
        tapLogStar(app, "crane")
        XCTAssertTrue(app.buttons["logBookStar_crane"].isSelected)
        XCTAssertTrue(dpStar.isSelected)
        app.buttons["tab_main"].tap()
        XCTAssertTrue(app.staticTexts["DP TIMER"].waitForExistence(timeout: 5))
        return app
    }

    private func tapLogStar(_ app: XCUIApplication, _ raw: String) {
        let star = app.buttons["logBookStar_\(raw)"]
        XCTAssertTrue(star.waitForExistence(timeout: 5))
        var swipes = 0
        while !star.isHittable && swipes < 4 {
            app.swipeDown()
            swipes += 1
        }
        swipes = 0
        while !star.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        star.tap()
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
