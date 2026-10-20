import XCTest

/// Tools tab grouped list + Compass error by amplitude (TG-01/03/13, CE-01/03).
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

    private func type(_ app: XCUIApplication, _ id: String, _ text: String, clear: Bool = false) {
        let f = app.textFields[id]
        XCTAssertTrue(f.waitForExistence(timeout: 3))
        f.tap()
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

        for kind in ["gyro", "compassError", "catenary", "winch", "chainLocker", "craneHeel", "portUnlocode"] {
            XCTAssertTrue(app.descendants(matching: .any)["toolTile.\(kind)"].waitForExistence(timeout: 5), kind)
        }
        XCTAssertTrue(app.staticTexts["DP & NAV"].exists)
        XCTAssertTrue(app.staticTexts["DECK CALCS"].exists)
        XCTAssertTrue(app.staticTexts["REFERENCE"].exists)
        sleep(1)
        XCTAssertTrue(app.descendants(matching: .any)["toolTile.portUnlocode"].label.contains("no searches yet"))
        snap(app, "01-tools-grouped-fresh")

        app.descendants(matching: .any)["toolTile.compassError"].tap()
        XCTAssertTrue(app.navigationBars["Compass error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["compassError.subtitle"].exists)
        snap(app, "02-compass-empty")

        type(app, "compassError.latitude.deg", "60")
        type(app, "compassError.declination.deg", "20")
        XCTAssertEqual(app.staticTexts["compassError.declination.echo"].label.contains("20°00.0′ N"), true)
        type(app, "compassError.compass", "49")
        type(app, "compassError.variation", "1.5")
        XCTAssertTrue(app.staticTexts["2.2° W"].firstMatch.waitForExistence(timeout: 3))
        snap(app, "03-compass-filled-top")
        app.swipeUp()
        sleep(1)
        XCTAssertTrue(app.staticTexts["3.7° W"].exists)
        XCTAssertTrue(app.staticTexts["046.8°T"].exists)
        snap(app, "04-compass-filled-result")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let status = app.descendants(matching: .any)["toolTile.compassError"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        sleep(1)
        XCTAssertTrue(status.label.contains("Last: 2.2° W · true 046.8°"), status.label)
        snap(app, "05-tools-grouped-after-compass")

        status.tap()
        XCTAssertTrue(app.navigationBars["Compass error"].waitForExistence(timeout: 5))
        type(app, "compassError.latitude.deg", "75")
        type(app, "compassError.declination.deg", "20")
        type(app, "compassError.declination.min", "15.3")
        XCTAssertTrue(app.staticTexts["compassError.declination.echo"].label.contains("20°15.3′ N"))
        type(app, "compassError.compass", "49")
        XCTAssertTrue(app.descendants(matching: .any)["compassError.polar"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["compass error"].exists)
        XCTAssertTrue(app.staticTexts["Sun doesn't rise or set here"].exists || app.descendants(matching: .any)["compassError.polar"].label.contains("Sun doesn't rise or set here"))
        app.swipeUp()
        sleep(1)
        snap(app, "06-compass-polar")
    }
}
