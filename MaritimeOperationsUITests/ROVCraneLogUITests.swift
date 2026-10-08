import XCTest

/// ROV and Crane books: add an entry and see it in Log, vessel prefill across books,
/// number validation, and swipe-delete with confirmation (Cancel keeps the row).
final class ROVCraneLogUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Add and see in Log

    func testAddROVEntryShowsInLog() throws {
        let app = XCUIApplication.launchedClean()

        app.buttons["tab_log"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["logBook_rov"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["logBook_crane"].exists)

        app.openLogBook(.rov)
        XCTAssertTrue(app.staticTexts["No ROV entries yet."].waitForExistence(timeout: 5))
        app.buttons["navAddROVEntry"].tap()
        XCTAssertTrue(app.navigationBars["New ROV entry"].waitForExistence(timeout: 5))

        let vessel = app.textFields["rovVessel"]
        XCTAssertTrue(vessel.waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["rovPositionPicker"].value as? String, "Not set")
        vessel.tap()
        vessel.typeText("QA ROV Vessel")
        let system = app.textFields["rovSystem"]
        system.tap()
        system.typeText("QA ROV System")
        app.buttons["rovKeyboardDone"].tap()

        // ROV Position is the IMCA grade list, not ship ranks.
        app.buttons["rovPositionPicker"].tap()
        let gradeI = app.buttons["ROV Pilot/Technician Grade I"]
        XCTAssertTrue(gradeI.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["ROV Tooling Supervisor"].exists)
        XCTAssertFalse(app.buttons["2nd Off."].exists)
        XCTAssertFalse(app.buttons["Crane operator"].exists)
        gradeI.tap()

        let classIII = app.buttons["rovClass_III"]
        classIII.swipeUpUntilHittable(in: app)
        classIII.tap()
        XCTAssertTrue(classIII.isSelected)
        XCTAssertTrue(app.staticTexts["Class III · Work-class"].exists)

        let inspection = app.buttons["rovJobType_inspection"]
        inspection.swipeUpUntilHittable(in: app)
        inspection.tap()
        XCTAssertTrue(inspection.isSelected)

        let piloting = app.buttons["rovTask_piloting"]
        piloting.swipeUpUntilHittable(in: app)
        piloting.tap()
        XCTAssertTrue(piloting.isSelected)

        let hours = app.textFields["rovPilotingHours"]
        hours.swipeUpUntilHittable(in: app)
        hours.tap()
        hours.typeText("3.5")
        let dives = app.textFields["rovDives"]
        dives.tap()
        dives.typeText("2")
        app.buttons["rovKeyboardDone"].tap()

        // Support site is optional and starts Not set.
        let support = app.buttons["rovSupportSitePicker"]
        support.swipeUpUntilHittable(in: app)
        XCTAssertEqual(support.value as? String, "Not set")
        support.tap()
        let onDP = app.buttons["Vessel on DP"]
        XCTAssertTrue(onDP.waitForExistence(timeout: 3))
        onDP.tap()

        app.buttons["rovSave"].tap()
        XCTAssertFalse(app.navigationBars["New ROV entry"].waitForExistence(timeout: 3))

        // Row in the ROV book.
        let row = app.bookRow(containing: "QA ROV System")
        XCTAssertTrue(row.waitForExistence(timeout: 6))
        XCTAssertTrue(row.label.contains("Inspection"), row.label)
        XCTAssertTrue(row.label.contains("QA ROV Vessel"), row.label)
        XCTAssertTrue(row.label.contains("\(dec("3.5")) hours piloting"), row.label)
        XCTAssertEqual(app.staticTexts["rovRowCount"].label, "1 entry")

        // Back on Log the ROV card counts it.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let card = app.descendants(matching: .any)["logBook_rov"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.value as? String, "\(dec("3.5")) piloting hours, 1 entry")

        // Reopen: values were saved.
        app.openLogBook(.rov)
        app.bookRow(containing: "QA ROV System").tap()
        XCTAssertTrue(app.navigationBars["Edit ROV entry"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["rovPositionPicker"].value as? String, "R O V Pilot or Technician, Grade 1")
        XCTAssertEqual(app.buttons["rovSupportSitePicker"].value as? String, "Vessel on D P")
        XCTAssertTrue(app.buttons["rovClass_III"].isSelected)
        XCTAssertTrue(app.buttons["rovJobType_inspection"].isSelected)
        XCTAssertEqual(app.textFields["rovDives"].value as? String, "2")
    }

    func testAddCraneEntryShowsInLog() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.crane)
        XCTAssertTrue(app.staticTexts["No crane entries yet."].waitForExistence(timeout: 5))
        app.buttons["navAddCraneEntry"].tap()
        XCTAssertTrue(app.navigationBars["New crane entry"].waitForExistence(timeout: 5))

        let vessel = app.textFields["craneVessel"]
        XCTAssertTrue(vessel.waitForExistence(timeout: 3))
        vessel.tap()
        vessel.typeText("QA Crane Vessel")
        let crane = app.textFields["craneName"]
        crane.tap()
        crane.typeText("QA Crane A")
        app.buttons["craneKeyboardDone"].tap()

        app.buttons["craneTypePicker"].tap()
        let offshore = app.buttons["Offshore crane"]
        XCTAssertTrue(offshore.waitForExistence(timeout: 3))
        offshore.tap()
        XCTAssertEqual(app.buttons["craneTypePicker"].value as? String, "Offshore crane")

        let hours = app.textFields["craneHoursOperated"]
        hours.swipeUpUntilHittable(in: app)
        hours.tap()
        hours.typeText("4.5")
        app.buttons["craneKeyboardDone"].tap()

        // Lift types are multi-select.
        let deck = app.buttons["craneLift_deck"]
        deck.swipeUpUntilHittable(in: app)
        deck.tap()
        let supply = app.buttons["craneLift_supplyVessel"]
        supply.tap()
        XCTAssertTrue(deck.isSelected)
        XCTAssertTrue(supply.isSelected)
        XCTAssertFalse(app.buttons["craneLift_subsea"].isSelected)

        let normal = app.buttons["craneMode_normal"]
        normal.swipeUpUntilHittable(in: app)
        normal.tap()
        XCTAssertTrue(normal.isSelected)

        let day = app.buttons["craneDayNight_day"]
        day.swipeUpUntilHittable(in: app)
        day.tap()
        XCTAssertTrue(day.isSelected)

        let wind = app.textFields["craneWind"]
        wind.swipeUpUntilHittable(in: app)
        wind.tap()
        wind.typeText("9")
        let wave = app.textFields["craneWaveHeight"]
        wave.tap()
        wave.typeText("1.8")
        app.buttons["craneKeyboardDone"].tap()

        app.buttons["craneSave"].tap()
        XCTAssertFalse(app.navigationBars["New crane entry"].waitForExistence(timeout: 3))

        let row = app.bookRow(containing: "QA Crane A")
        XCTAssertTrue(row.waitForExistence(timeout: 6))
        XCTAssertTrue(row.label.contains("Deck, Supply vessel lifts"), row.label)
        XCTAssertTrue(row.label.contains("QA Crane Vessel"), row.label)
        XCTAssertTrue(row.label.contains("\(dec("4.5")) hours operated"), row.label)
        XCTAssertEqual(app.staticTexts["craneRowCount"].label, "1 entry")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let card = app.descendants(matching: .any)["logBook_crane"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.value as? String, "\(dec("4.5")) hours operated, 1 entry")

        app.openLogBook(.crane)
        app.bookRow(containing: "QA Crane A").tap()
        XCTAssertTrue(app.navigationBars["Edit crane entry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["craneLift_deck"].isSelected)
        XCTAssertTrue(app.buttons["craneLift_supplyVessel"].isSelected)
        XCTAssertEqual(app.textFields["craneWind"].value as? String, "9")
    }

    // MARK: Prefill and validation

    /// A new ROV entry takes the vessel of the newest entry in any book (here a Crane entry);
    /// Position stays "Not set".
    func testNewROVEntryPrefillsVesselFromCraneButNotPosition() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.crane)
        app.buttons["navAddCraneEntry"].tap()
        let vessel = app.textFields["craneVessel"]
        XCTAssertTrue(vessel.waitForExistence(timeout: 5))
        vessel.tap()
        vessel.typeText("QA Prefill Crane Ship")
        app.buttons["craneKeyboardDone"].tap()
        app.buttons["cranePositionPicker"].tap()
        let master = app.buttons["Master"]
        XCTAssertTrue(master.waitForExistence(timeout: 3))
        // Crane list: Crane operator first, then the AH ranks.
        XCTAssertTrue(app.buttons["Crane operator"].exists)
        XCTAssertFalse(app.buttons["ROV Supervisor"].exists)
        master.tap()
        app.buttons["craneSave"].tap()
        XCTAssertTrue(app.bookRow(containing: "QA Prefill Crane Ship").waitForExistence(timeout: 6))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.openLogBook(.rov)
        app.buttons["navAddROVEntry"].tap()
        XCTAssertTrue(app.navigationBars["New ROV entry"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["rovVessel"].value as? String, "QA Prefill Crane Ship")
        XCTAssertEqual(app.buttons["rovPositionPicker"].value as? String, "Not set")
        XCTAssertEqual(app.switches["rovUnderTraining"].value as? String, "0", "Under training starts off")
    }

    func testJunkHoursBlockSaveWithMessage() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.rov)
        app.buttons["navAddROVEntry"].tap()
        let hours = app.textFields["rovPilotingHours"]
        XCTAssertTrue(hours.waitForExistence(timeout: 5))
        hours.swipeUpUntilHittable(in: app)
        hours.tap()
        hours.typeText("30")
        app.buttons["rovKeyboardDone"].tap()
        app.buttons["rovSave"].tap()
        let error = app.staticTexts["rovFieldError"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertEqual(error.label, "Piloting hours must be a number from 0 to 24.")
        XCTAssertTrue(app.navigationBars["New ROV entry"].exists, "Form stays open")
    }

    // MARK: "Other" needs text

    func testROVOtherGradeAndSupportSiteNeedTextBeforeSave() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.rov)
        app.buttons["navAddROVEntry"].tap()
        let save = app.buttons["rovSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled, "Nothing required besides Start")

        app.buttons["rovPositionPicker"].tap()
        let other = app.buttons["Other"]
        XCTAssertTrue(other.waitForExistence(timeout: 3))
        other.tap()
        let gradeText = app.textFields["rovPositionOther"]
        XCTAssertTrue(gradeText.waitForExistence(timeout: 3))
        XCTAssertFalse(save.isEnabled, "Other position with blank text blocks Save")
        gradeText.tap()
        gradeText.typeText("Survey pilot")
        app.buttons["rovKeyboardDone"].tap()
        XCTAssertTrue(save.isEnabled)

        let support = app.buttons["rovSupportSitePicker"]
        support.swipeUpUntilHittable(in: app)
        support.tap()
        let otherSite = app.buttons["Other"]
        XCTAssertTrue(otherSite.waitForExistence(timeout: 3))
        otherSite.tap()
        XCTAssertFalse(save.isEnabled, "Other support site with blank text blocks Save")
        XCTAssertTrue(app.staticTexts["rovOtherNeeded"].exists)
        let siteText = app.textFields["rovSupportSiteOther"]
        siteText.swipeUpUntilHittable(in: app)
        siteText.tap()
        siteText.typeText("Barge")
        app.buttons["rovKeyboardDone"].tap()
        XCTAssertTrue(save.isEnabled)

        save.tap()
        XCTAssertFalse(app.navigationBars["New ROV entry"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["rovRowCount"].label, "1 entry")
    }

    func testCraneOtherTypeNeedsTextBeforeSave() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.crane)
        app.buttons["navAddCraneEntry"].tap()
        let save = app.buttons["craneSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)

        app.buttons["craneTypePicker"].tap()
        let other = app.buttons["Other"]
        XCTAssertTrue(other.waitForExistence(timeout: 3))
        other.tap()
        XCTAssertFalse(save.isEnabled, "Other crane type with blank text blocks Save")
        let text = app.textFields["craneTypeOther"]
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        text.tap()
        text.typeText("Gantry")
        app.buttons["craneKeyboardDone"].tap()
        XCTAssertTrue(save.isEnabled)

        save.tap()
        XCTAssertFalse(app.navigationBars["New crane entry"].waitForExistence(timeout: 3))
        app.bookRow(containing: "Crane entry").tap()
        XCTAssertTrue(app.navigationBars["Edit crane entry"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["craneTypeOther"].value as? String, "Gantry")
    }

    // MARK: DP totals

    /// ROV piloting hours and Crane hours operated never reach the DP total or the DP card.
    func testROVAndCraneHoursDoNotChangeDPTotals() throws {
        let app = XCUIApplication.launchedClean()
        app.openLogBook(.rov)
        app.buttons["navAddROVEntry"].tap()
        let hours = app.textFields["rovPilotingHours"]
        XCTAssertTrue(hours.waitForExistence(timeout: 5))
        hours.swipeUpUntilHittable(in: app)
        hours.tap()
        hours.typeText("6")
        app.buttons["rovKeyboardDone"].tap()
        app.buttons["rovSave"].tap()
        XCTAssertTrue(app.staticTexts["rovRowCount"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.openLogBook(.crane)
        app.buttons["navAddCraneEntry"].tap()
        let craneHours = app.textFields["craneHoursOperated"]
        XCTAssertTrue(craneHours.waitForExistence(timeout: 5))
        craneHours.swipeUpUntilHittable(in: app)
        craneHours.tap()
        craneHours.typeText("8")
        app.buttons["craneKeyboardDone"].tap()
        app.buttons["craneSave"].tap()
        XCTAssertTrue(app.staticTexts["craneRowCount"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let dpCard = app.descendants(matching: .any)["logBook_dp"]
        XCTAssertTrue(dpCard.waitForExistence(timeout: 5))
        XCTAssertEqual(dpCard.value as? String, "\(dec("0.0")) hours total, 0 entries")
        XCTAssertEqual(app.descendants(matching: .any)["logBook_rov"].value as? String, "\(dec("6.0")) piloting hours, 1 entry")

        app.openLogBook(.dp)
        let total = app.staticTexts["totalDPHours"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "0 h")
    }

    // MARK: Swipe delete

    func testROVSwipeDeleteCancelKeepsRow() throws {
        let app = XCUIApplication.launchedClean()
        addROVEntry(app, system: "Swipe Keep ROV")
        let row = app.bookRow(containing: "Swipe Keep ROV")

        row.swipeLeft()
        let swipeDelete = app.buttons["swipeDeleteROVEntry"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3), "Expected red Delete swipe action")
        swipeDelete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Expected delete confirmation alert")
        XCTAssertTrue(
            alert.label.contains("Delete this entry?")
                || app.staticTexts["Delete this entry? Its hours come off your total."].exists,
            "Expected locked confirm copy"
        )
        let cancel = app.buttons["cancelDeleteROVEntry"].firstMatch.exists
            ? app.buttons["cancelDeleteROVEntry"].firstMatch
            : alert.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3), "Alert should close on Cancel")
        XCTAssertTrue(app.bookRow(containing: "Swipe Keep ROV").waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["rovRowCount"].label, "1 entry")
    }

    func testROVSwipeDeleteConfirmRemovesRow() throws {
        let app = XCUIApplication.launchedClean()
        addROVEntry(app, system: "Swipe Drop ROV")
        app.bookRow(containing: "Swipe Drop ROV").swipeLeft()
        let swipeDelete = app.buttons["swipeDeleteROVEntry"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3))
        swipeDelete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        let confirm = app.buttons["confirmDeleteROVEntry"].firstMatch.exists
            ? app.buttons["confirmDeleteROVEntry"].firstMatch
            : alert.buttons["Delete"]
        confirm.tap()
        XCTAssertFalse(app.bookRow(containing: "Swipe Drop ROV").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No ROV entries yet."].waitForExistence(timeout: 4))
    }

    func testCraneSwipeDeleteCancelKeepsRow() throws {
        let app = XCUIApplication.launchedClean()
        addCraneEntry(app, crane: "Swipe Keep Crane")
        let row = app.bookRow(containing: "Swipe Keep Crane")

        row.swipeLeft()
        let swipeDelete = app.buttons["swipeDeleteCraneEntry"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3), "Expected red Delete swipe action")
        swipeDelete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Expected delete confirmation alert")
        let cancel = app.buttons["cancelDeleteCraneEntry"].firstMatch.exists
            ? app.buttons["cancelDeleteCraneEntry"].firstMatch
            : alert.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3), "Alert should close on Cancel")
        XCTAssertTrue(app.bookRow(containing: "Swipe Keep Crane").waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["craneRowCount"].label, "1 entry")
    }

    func testCraneSwipeDeleteConfirmRemovesRow() throws {
        let app = XCUIApplication.launchedClean()
        addCraneEntry(app, crane: "Swipe Drop Crane")
        app.bookRow(containing: "Swipe Drop Crane").swipeLeft()
        let swipeDelete = app.buttons["swipeDeleteCraneEntry"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 3))
        swipeDelete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        let confirm = app.buttons["confirmDeleteCraneEntry"].firstMatch.exists
            ? app.buttons["confirmDeleteCraneEntry"].firstMatch
            : alert.buttons["Delete"]
        confirm.tap()
        XCTAssertFalse(app.bookRow(containing: "Swipe Drop Crane").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No crane entries yet."].waitForExistence(timeout: 4))
    }

    // MARK: Helpers

    /// Log → ROV → New entry with only the ROV system typed (no other field is required).
    private func addROVEntry(_ app: XCUIApplication, system: String) {
        app.openLogBook(.rov)
        app.buttons["rovAddEntryPill"].tap()
        let field = app.textFields["rovSystem"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(system)
        app.buttons["rovKeyboardDone"].tap()
        app.buttons["rovSave"].tap()
        XCTAssertTrue(app.bookRow(containing: system).waitForExistence(timeout: 6))
    }

    private func addCraneEntry(_ app: XCUIApplication, crane: String) {
        app.openLogBook(.crane)
        app.buttons["craneAddEntryPill"].tap()
        let field = app.textFields["craneName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(crane)
        app.buttons["craneKeyboardDone"].tap()
        app.buttons["craneSave"].tap()
        XCTAssertTrue(app.bookRow(containing: crane).waitForExistence(timeout: 6))
    }

    /// "3.5" with the device's decimal separator ("3,5" in a Norwegian region): the app formats
    /// hours with the current locale, and the UI test runs on the same device.
    private func dec(_ value: String) -> String {
        value.replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }

}
