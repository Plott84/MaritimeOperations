import XCTest

/// Tools tab grouped list + Gyro & Compass (GC-01…GC-13, compass worked example, polar).
final class ToolsCompassUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func type(_ app: XCUIApplication, _ id: String, _ text: String, clear: Bool = true) {
        let f = app.textFields[id]
        XCTAssertTrue(f.waitForExistence(timeout: 3))
        f.tap()
        // Shared lat/dec stay on the screen if Navigation keeps the destination.
        // Replace the field instead of appending ("60" + "75" → "6075" / "7551").
        if clear, let v = f.value as? String, !v.isEmpty {
            f.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: v.count))
        }
        f.typeText(text)
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 2) { done.tap() }
    }

    func testGroupedToolsAndCompassError() throws {
        let app = XCUIApplication.launchedClean()
        app.buttons["tab_tools"].tap()

        for kind in ["gyro", "catenary", "winch", "chainLocker", "craneHeel", "portUnlocode"] {
            XCTAssertTrue(app.descendants(matching: .any)["toolTile.\(kind)"].waitForExistence(timeout: 5), kind)
        }
        XCTAssertFalse(app.descendants(matching: .any)["toolTile.compassError"].exists)
        XCTAssertTrue(app.staticTexts["DP & NAV"].exists)
        XCTAssertTrue(app.staticTexts["DECK CALCS"].exists)
        XCTAssertTrue(app.staticTexts["REFERENCE"].exists)
        let gyroTile = app.descendants(matching: .any)["toolTile.gyro"]
        XCTAssertTrue(gyroTile.label.contains("Gyro & Compass"), gyroTile.label)
        XCTAssertTrue(gyroTile.label.contains("Not used yet"), gyroTile.label)
        let blurbs = [
            "catenary": "Free-hang span and sag",
            "winch": "Drum length and layers",
            "chainLocker": "Stowage volume and length",
            "craneHeel": "Static heel and ballast to level"
        ]
        for (kind, blurb) in blurbs {
            let tile = app.descendants(matching: .any)["toolTile.\(kind)"]
            XCTAssertTrue(tile.label.contains(blurb), tile.label)
            XCTAssertFalse(tile.label.contains("Not used yet"), tile.label)
        }
        sleep(1)
        XCTAssertTrue(app.descendants(matching: .any)["toolTile.portUnlocode"].label.contains("no searches yet"))
        snap(app, "01-tools-grouped-fresh")

        gyroTile.tap()
        XCTAssertTrue(app.navigationBars["Gyro & Compass"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["EXAMPLE DATA"].exists)
        app.buttons["gyroCompass.tab.Compass"].tap()
        XCTAssertTrue(app.staticTexts["compassError.subtitle"].waitForExistence(timeout: 3))
        snap(app, "02-compass-empty")

        type(app, "compassError.latitude.deg", "60")
        type(app, "compassError.declination.deg", "20")
        XCTAssertEqual(app.staticTexts["compassError.declination.echo"].label.contains("20°00.0′ N"), true)
        type(app, "compassError.compass", "49")
        type(app, "compassError.variation", "1.5")
        let hero = app.descendants(matching: .any)["compassError.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(hero.label.contains("2.2 degrees West"), hero.label)
        XCTAssertTrue(hero.label.contains("degrees true"), hero.label)
        XCTAssertTrue(hero.label.contains("degrees compass"), hero.label)
        snap(app, "03-compass-filled-top")
        app.swipeUp()
        sleep(1)
        XCTAssertTrue(app.staticTexts["3.7° W"].exists)
        let truth = app.descendants(matching: .any)["compassError.trueBearing"]
        XCTAssertTrue(truth.label.contains("degrees true"), truth.label)
        let compassRow = app.descendants(matching: .any)["compassError.compassBearing"]
        XCTAssertTrue(compassRow.label.contains("degrees compass"), compassRow.label)
        XCTAssertTrue(app.staticTexts["Aid, not authority."].exists)
        snap(app, "04-compass-filled-result")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let status = app.descendants(matching: .any)["toolTile.gyro"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        sleep(1)
        XCTAssertTrue(status.label.contains("Last compass 2.2° W · true 046.8°T"), status.label)
        snap(app, "05-tools-grouped-after-compass")

        status.tap()
        XCTAssertTrue(app.navigationBars["Gyro & Compass"].waitForExistence(timeout: 5))
        app.buttons["gyroCompass.tab.Compass"].tap()
        type(app, "compassError.latitude.deg", "75")
        type(app, "compassError.declination.deg", "20")
        type(app, "compassError.declination.min", "15.3")
        XCTAssertTrue(app.staticTexts["compassError.declination.echo"].label.contains("20°15.3′ N"))
        type(app, "compassError.compass", "49")
        let polar = app.descendants(matching: .any)["compassError.polar"]
        XCTAssertTrue(polar.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["compass error"].exists)
        XCTAssertTrue(polar.label.contains("Sun doesn't rise or set here"), polar.label)
        XCTAssertTrue(polar.label.contains("≥ 90°"), polar.label)
        app.swipeUp()
        sleep(1)
        snap(app, "06-compass-polar")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.descendants(matching: .any)["toolTile.gyro"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["toolTile.gyro"].tap()
        XCTAssertTrue(app.navigationBars["Gyro & Compass"].waitForExistence(timeout: 5))
        app.buttons["gyro.method.Azimuth"].tap()
        type(app, "gyro.latitude.deg", "51")
        type(app, "gyro.latitude.min", "28")
        type(app, "gyro.declination.deg", "18")
        type(app, "gyro.declination.min", "42")
        XCTAssertTrue(app.staticTexts["gyro.latitude.echo"].label.contains("51°28.0′ N"))
        type(app, "gyro.lha", "045.0")
        type(app, "gyro.bearing", "046.8")
        let gyroHero = app.descendants(matching: .any)["gyro.hero"]
        XCTAssertTrue(gyroHero.waitForExistence(timeout: 3))
        XCTAssertTrue(gyroHero.label.contains("244 point 2 degrees true"), gyroHero.label)
        XCTAssertTrue(gyroHero.label.contains("162.6 degrees West"), gyroHero.label)
        XCTAssertTrue(app.descendants(matching: .any)["gyro.flag"].waitForExistence(timeout: 2))
        app.buttons["gyroCompass.tab.Compass"].tap()
        XCTAssertTrue(app.staticTexts["compassError.latitude.echo"].label.contains("51°28.0′ N"))
        app.buttons["gyroCompass.tab.Gyro"].tap()
        let lha = app.textFields["gyro.lha"]
        XCTAssertTrue(lha.waitForExistence(timeout: 2))
        XCTAssertTrue((lha.value as? String)?.contains("045.0") == true || (lha.value as? String)?.contains("45") == true)
        snap(app, "07-gyro-azimuth")
    }
}
