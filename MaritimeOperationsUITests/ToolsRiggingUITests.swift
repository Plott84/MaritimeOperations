import XCTest

/// Tools row and Slinging & Rigging screen (RG-12, 14, 23, 25, 40, 42, 43, 48).
final class ToolsRiggingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func type(_ app: XCUIApplication, _ id: String, _ text: String) {
        let field = app.textFields[id]
        XCTAssertTrue(field.waitForExistence(timeout: 3), id)
        field.tap()
        if let value = field.value as? String, !value.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text)
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 2) { done.tap() }
    }

    private func scrollToTop(_ app: XCUIApplication) {
        for _ in 0..<3 { app.swipeDown() }
    }

    private func reveal(_ app: XCUIApplication, _ id: String) {
        let element = app.descendants(matching: .any)[id]
        var swipes = 0
        while !element.isHittable && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
    }

    func testSlingingAndChainBlock() throws {
        let app = XCUIApplication.launchedClean()
        XCTAssertEqual(app.buttons["tab_main"].label, "Main")
        XCTAssertEqual(app.buttons["tab_log"].label, "Entries")
        XCTAssertEqual(app.buttons["tab_tools"].label, "Tools")
        XCTAssertEqual(app.buttons["tab_export"].label, "Export")
        XCTAssertFalse(app.buttons["New Rig Move"].exists)

        app.buttons["tab_tools"].tap()
        let tile = app.descendants(matching: .any)["toolTile.rigging"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        var swipes = 0
        while !tile.isHittable && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(tile.label.contains("Slinging & Rigging"), tile.label)
        XCTAssertTrue(tile.label.contains("Not used yet"), tile.label)

        tile.tap()
        XCTAssertTrue(app.navigationBars["Slinging & Rigging"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Aid, not authority."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Measured from vertical. L includes hook/shackle."].exists)
        XCTAssertFalse(app.staticTexts["EXAMPLE DATA"].exists)
        XCTAssertFalse(app.staticTexts["Design mock, not a build"].exists)
        XCTAssertFalse(app.buttons["Calculate"].exists)

        type(app, "rigging.load", "6.0")
        type(app, "rigging.length", "4")
        type(app, "rigging.height", "3.06")
        type(app, "rigging.tag", "5")
        reveal(app, "rigging.hero")
        let hero = app.descendants(matching: .any)["rigging.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(hero.label.contains("Within marked W L L"), hero.label)
        XCTAssertTrue(hero.label.contains("from vertical"), hero.label)
        XCTAssertFalse(hero.label.lowercased().contains("safe"), hero.label)
        let required = app.descendants(matching: .any)["rigging.required"]
        XCTAssertTrue(required.label.contains("4.29"), required.label)
        XCTAssertFalse(required.label.contains("4.28"), required.label)
        XCTAssertTrue(app.descendants(matching: .any)["rigging.echo"].label.contains("from vertical"))
        XCTAssertTrue(app.descendants(matching: .any)["rigging.trig"].label.contains("Band decides pass/fail"))
        XCTAssertTrue(app.descendants(matching: .any)["rigging.trig"].label.contains("info only"))
        XCTAssertFalse(app.descendants(matching: .any)["rigging.amber"].exists)
        XCTAssertTrue(app.staticTexts["Aid, not authority."].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let used = app.descendants(matching: .any)["toolTile.rigging"]
        XCTAssertTrue(used.waitForExistence(timeout: 5))
        swipes = 0
        while !used.isHittable && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        let showedLast = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Last sling"),
            object: used
        )
        XCTAssertEqual(XCTWaiter().wait(for: [showedLast], timeout: 3), .completed, used.label)
        XCTAssertTrue(used.label.contains("within"), used.label)
        XCTAssertFalse(used.label.contains("Not used yet"), used.label)

        used.tap()
        XCTAssertTrue(app.navigationBars["Slinging & Rigging"].waitForExistence(timeout: 5))
        scrollToTop(app)
        app.buttons["rigging.angleMode.Angle"].tap()
        type(app, "rigging.load", "6")
        type(app, "rigging.angle", "40")
        type(app, "rigging.tag", "4")
        reveal(app, "rigging.hero")
        let exceeds = app.descendants(matching: .any)["rigging.hero"]
        XCTAssertTrue(exceeds.waitForExistence(timeout: 3))
        XCTAssertTrue(exceeds.label.contains("Exceeds"), exceeds.label)
        XCTAssertTrue(app.descendants(matching: .any)["rigging.trig"].label.contains("3.92"))
        XCTAssertTrue(app.descendants(matching: .any)["rigging.trig"].label.contains("info only"))

        scrollToTop(app)
        app.buttons["rigging.legs.4"].tap()
        let legNote = app.descendants(matching: .any)["rigging.legNote"]
        XCTAssertTrue(legNote.waitForExistence(timeout: 2))
        XCTAssertTrue(legNote.label.contains("3- and 4-leg slings are calculated as 2-leg."), legNote.label)

        type(app, "rigging.angle", "50")
        reveal(app, "rigging.amber")
        let amber = app.descendants(matching: .any)["rigging.amber"]
        XCTAssertTrue(amber.waitForExistence(timeout: 3))
        XCTAssertTrue(amber.label.contains("High angle"), amber.label)

        type(app, "rigging.angle", "61")
        let blocked = app.descendants(matching: .any)["rigging.blocked"]
        XCTAssertTrue(blocked.waitForExistence(timeout: 3))
        XCTAssertTrue(blocked.label.contains("Outside rated range"), blocked.label)
        XCTAssertNil(blocked.label.rangeOfCharacter(from: .decimalDigits), blocked.label)
        XCTAssertFalse(app.descendants(matching: .any)["rigging.tension"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["rigging.hero"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["rigging.trig"].exists)

        scrollToTop(app)
        app.buttons["rigging.tab.Chain block"].tap()
        type(app, "rigging.chain.load", "0.80")
        type(app, "rigging.chain.wll", "1")
        type(app, "rigging.chain.angle", "0")
        reveal(app, "rigging.hero")
        let block = app.descendants(matching: .any)["rigging.hero"]
        XCTAssertTrue(block.waitForExistence(timeout: 3))
        XCTAssertTrue(block.label.contains("Within block W L L"), block.label)
        XCTAssertTrue(block.label.contains("from vertical"), block.label)
        XCTAssertFalse(app.descendants(matching: .any)["rigging.amber"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["rigging.noReduction"].exists)
        XCTAssertFalse(block.label.lowercased().contains("safe"))

        type(app, "rigging.chain.angle", "30")
        XCTAssertFalse(app.descendants(matching: .any)["rigging.noReduction"].exists)
        reveal(app, "rigging.amber")
        let chainAmber = app.descendants(matching: .any)["rigging.amber"]
        XCTAssertTrue(chainAmber.waitForExistence(timeout: 3))
        XCTAssertTrue(chainAmber.label.contains("Most blocks are rated vertical only"), chainAmber.label)
        XCTAssertTrue(chainAmber.label.contains("LEEA 053"), chainAmber.label)

        scrollToTop(app)
        app.buttons["rigging.chainMode.Two-block"].tap()
        type(app, "rigging.chain.load", "2")
        type(app, "rigging.chain.beta1", "20")
        type(app, "rigging.chain.beta2", "55")
        reveal(app, "rigging.t1")
        let t1 = app.descendants(matching: .any)["rigging.t1"]
        XCTAssertTrue(t1.waitForExistence(timeout: 3))
        XCTAssertTrue(t1.label.contains("1.70"), t1.label)
        XCTAssertTrue(app.descendants(matching: .any)["rigging.t2"].label.contains("0.71"))
        XCTAssertTrue(app.descendants(matching: .any)["rigging.chain.beta1Row"].label.contains("from vertical"))
        XCTAssertTrue(app.descendants(matching: .any)["rigging.amber"].exists)

        scrollToTop(app)
        app.buttons["rigging.tab.Slings"].tap()
        let load = app.textFields["rigging.load"]
        XCTAssertTrue(load.waitForExistence(timeout: 3))
        XCTAssertTrue((load.value as? String)?.contains("6") == true)
        XCTAssertTrue(app.staticTexts["Aid, not authority."].exists)
    }
}
