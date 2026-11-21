import CoreGraphics
import Foundation
import XCTest

/// REL-01 regression for Catenary “Depth (optional)”.
///
/// Expected to fail on `cb88770` until the shared bottom inset keeps a focused
/// row above the floating tab bar. `isHittable` is recorded and is not a pass.
///
/// The Depth field ships with an empty `fieldAccessibilityIdentifier`. The row
/// is found by its visible label. No tab-bar container identifier is added:
/// a container id is copied onto the tab buttons and would hide `tab_*`.
///
/// Content size is UIKit’s launch argument, applied per launch by `launchedClean`:
/// `UICTContentSizeCategoryL` and `UICTContentSizeCategoryAccessibilityXL`
/// (simctl names `large` and `accessibility-extra-large`). The Depth caption
/// height must match that size before any overlap assertion runs.
///
/// `launchedClean()` uses the in-memory store. This file does not touch an
/// on-disk log store. Authoring VM had no Xcode; this test was not executed there.
final class CatenaryDepthReachabilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDepthRowClearsTabAndKeyboardAtLarge() throws {
        try exercise(.large)
    }

    func testDepthRowClearsTabAndKeyboardAtAccessibilityExtraLarge() throws {
        try exercise(.accessibilityExtraLarge)
    }

    private func exercise(_ size: ContentSize) throws {
        let app = XCUIApplication.launchedClean(extraArguments: size.launchArguments)
        assertFourTabs(app)
        openCatenary(app)
        let caption = app.staticTexts.matching(NSPredicate(format: "label == %@", "Depth (optional)")).firstMatch
        let value = app.textFields.matching(NSPredicate(format: "label == %@", "Depth (optional)")).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 3), "Depth caption missing")
        XCTAssertTrue(value.waitForExistence(timeout: 3), "Depth field missing")
        var layoutTries = 0
        while caption.frame.height <= 10 && layoutTries < 4 {
            guard drag(app, up: true, watching: value) else { break }
            layoutTries += 1
        }
        assertContentSize(size, caption: caption, field: value)
        let row = try depthRow(app)

        scrollUntilClear(app, row: row)
        snap(app, "\(size.snapshot)-scrolled")
        assertFullyVisible(
            row,
            app: app,
            keyboard: nil,
            context: "After scrolling, Depth is still covered by the floating tab bar"
        )

        row.field.tap()
        assertStillOnCatenary(app, context: "Tapping Depth switched tabs")
        let keyboard = waitForKeyboard(app)
        snap(app, "\(size.snapshot)-keyboard")
        assertFullyVisible(
            row,
            app: app,
            keyboard: keyboard,
            context: "With the keyboard open, Depth is covered by the tab bar or keyboard"
        )

        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3), "Keyboard Done must stay reachable")
        XCTAssertTrue(done.isHittable, "Keyboard Done is not hittable")
        if let existing = row.field.value as? String, existing.contains(where: \.isNumber) {
            row.field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        row.field.typeText("80")
        done.tap()

        let keyboardGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.firstMatch
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [keyboardGone], timeout: 5),
            .completed,
            "Done did not dismiss the keyboard"
        )
        snap(app, "\(size.snapshot)-after-done")
        assertStillOnCatenary(app, context: "Done left Catenary")
        let kept = (row.field.value as? String) ?? ""
        XCTAssertTrue(kept.contains("80"), "Depth value was not kept after Done: \(kept)")
        assertFourTabs(app)
    }

    // MARK: - Navigation

    private func openCatenary(_ app: XCUIApplication) {
        let tools = app.buttons["tab_tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 8), "Tools tab missing")
        tools.tap()
        XCTAssertTrue(app.navigationBars["Tools"].waitForExistence(timeout: 5))
        let tile = app.descendants(matching: .any)["toolTile.catenary"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "Catenary tile missing")
        scrollUntilClear(app, element: tile)
        XCTAssertLessThanOrEqual(
            tile.frame.maxY,
            tabGlassTop(app) + 0.5,
            "Catenary tile maxY \(tile.frame.maxY) is still under the tab bar \(tabGlassTop(app))"
        )
        tile.tap()
        XCTAssertTrue(app.navigationBars["Catenary"].waitForExistence(timeout: 5))
        assertStillOnCatenary(app, context: "Opening Catenary left Tools")
    }

    private func assertStillOnCatenary(_ app: XCUIApplication, context: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars["Catenary"].exists, "\(context): Catenary is not showing", file: file, line: line)
        XCTAssertFalse(app.navigationBars["Entries"].exists, "\(context): Entries is showing", file: file, line: line)
        XCTAssertFalse(app.staticTexts["Your logbooks"].exists, "\(context): Entries logbooks are showing", file: file, line: line)
        XCTAssertTrue(app.buttons["tab_tools"].isSelected, "\(context): Tools tab is not selected", file: file, line: line)
        XCTAssertFalse(app.buttons["tab_log"].isSelected, "\(context): Entries tab is selected", file: file, line: line)
    }

    private func assertFourTabs(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for identifier in ["tab_main", "tab_log", "tab_tools", "tab_export"] {
            XCTAssertTrue(app.buttons[identifier].exists, "Missing \(identifier)", file: file, line: line)
        }
    }

    // MARK: - Depth row

    private struct DepthRow {
        let label: XCUIElement
        let field: XCUIElement
        let unit: XCUIElement
        var parts: [(name: String, element: XCUIElement)] {
            [("label", label), ("value", field), ("unit", unit)]
        }
    }

    private func depthRow(_ app: XCUIApplication) throws -> DepthRow {
        let label = app.staticTexts.matching(NSPredicate(format: "label == %@", "Depth (optional)")).firstMatch
        let field = app.textFields.matching(NSPredicate(format: "label == %@", "Depth (optional)")).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 3), "Depth caption missing")
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Depth field missing")
        var unit = unitBeside(field, in: app)
        var attempts = 0
        while unit == nil && attempts < 6 {
            guard drag(app, up: true, watching: field) else { break }
            attempts += 1
            unit = unitBeside(field, in: app)
        }
        let matched = try XCTUnwrap(
            unit,
            "No single “m” unit aligned with Depth. \(geometry(app, label: label, field: field, unit: nil, keyboard: nil))"
        )
        XCTAssertLessThanOrEqual(
            label.frame.maxY,
            field.frame.minY + 2,
            "Depth caption should sit above the value. \(geometry(app, label: label, field: field, unit: matched, keyboard: nil))"
        )
        return DepthRow(label: label, field: field, unit: matched)
    }

    /// The unit is a separate text, and several rows say “m”. Keep the one beside this field.
    private func unitBeside(_ field: XCUIElement, in app: XCUIApplication) -> XCUIElement? {
        let units = app.staticTexts.matching(NSPredicate(format: "label == %@", "m"))
        var best: (element: XCUIElement, dy: CGFloat)?
        var runnerUp = CGFloat.greatestFiniteMagnitude
        for index in 0..<units.count {
            let candidate = units.element(boundBy: index)
            let frame = candidate.frame
            guard frame.width > 1, frame.height > 1, frame.minX >= field.frame.midX else { continue }
            let dy = abs(frame.midY - field.frame.midY)
            let band = max(field.frame.height, frame.height) / 2 + 8
            guard dy <= band else { continue }
            if let current = best {
                if dy < current.dy {
                    runnerUp = current.dy
                    best = (candidate, dy)
                } else if dy < runnerUp {
                    runnerUp = dy
                }
            } else {
                best = (candidate, dy)
            }
        }
        guard let best, runnerUp - best.dy >= 8 else { return nil }
        return best.element
    }

    private func assertContentSize(_ size: ContentSize, caption: XCUIElement, field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let height = caption.frame.height
        let detail = "Depth caption height \(height), value height \(field.frame.height). Launch argument \(size.argument)."
        switch size {
        case .large:
            // Caption 1 at large is 12 pt on 16 pt leading. AX3 is far above this.
            XCTAssertGreaterThan(height, 10, "Depth caption has no frame. \(detail)", file: file, line: line)
            XCTAssertLessThan(height, 28, "Content size is larger than large. \(detail)", file: file, line: line)
        case .accessibilityExtraLarge:
            // Caption 1 at accessibility extra large (AX3) is 32 pt on 39 pt leading.
            XCTAssertGreaterThan(
                height,
                34,
                "accessibility-extra-large did not apply. Refusing this as the enlarged-text pass. \(detail)",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Visibility

    /// Capsule top. `FloatingTabBar` pads 6 pt above the buttons before `glassEffect`.
    /// The buttons keep `tab_*`; the bar itself has no identifier.
    private func tabGlassTop(_ app: XCUIApplication) -> CGFloat {
        tabButtonTop(app) - 6
    }

    private func contentTop(_ app: XCUIApplication) -> CGFloat {
        let bar = app.navigationBars["Catenary"].exists
            ? app.navigationBars["Catenary"]
            : app.navigationBars["Tools"]
        return bar.frame.maxY
    }

    private func tabButtonTop(_ app: XCUIApplication) -> CGFloat {
        ["tab_main", "tab_log", "tab_tools", "tab_export"]
            .map { app.buttons[$0].frame.minY }
            .min() ?? .greatestFiniteMagnitude
    }

    private func assertFullyVisible(
        _ row: DepthRow,
        app: XCUIApplication,
        keyboard: XCUIElement?,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let floor = contentTop(app)
        let buttonTop = tabButtonTop(app)
        XCTAssertGreaterThan(floor, 40, "Navigation bar has no usable frame", file: file, line: line)
        XCTAssertGreaterThan(buttonTop, floor, "Tab buttons have no usable frame below the navigation bar", file: file, line: line)
        XCTAssertTrue(
            rowIsClear(row, app: app, keyboard: keyboard),
            "\(context). isHittable is not acceptance. \(geometry(app, label: row.label, field: row.field, unit: row.unit, keyboard: keyboard))",
            file: file,
            line: line
        )
    }

    private func rowIsClear(_ row: DepthRow, app: XCUIApplication, keyboard: XCUIElement?) -> Bool {
        let floor = contentTop(app)
        let ceiling = obscuringTop(app, keyboard: keyboard)
        return row.parts.allSatisfy { part in
            let frame = part.element.frame
            return frame.width > 1
                && frame.height > 1
                && frame.minY >= floor - 0.5
                && frame.maxY <= ceiling + 0.5
        }
    }

    private func obscuringTop(_ app: XCUIApplication, keyboard: XCUIElement?) -> CGFloat {
        let glass = tabGlassTop(app)
        guard let keyboard, keyboard.exists else { return glass }
        let top = keyboard.frame.minY
        // Ignore a keyboard frame that does not sit in the lower screen. The raised tab bar is the nearer cover.
        guard top > contentTop(app) + 40, keyboard.frame.height > 100 else { return glass }
        return min(glass, top)
    }

    private func geometry(
        _ app: XCUIApplication,
        label: XCUIElement,
        field: XCUIElement,
        unit: XCUIElement?,
        keyboard: XCUIElement?
    ) -> String {
        func box(_ name: String, _ element: XCUIElement?) -> String {
            guard let element, element.exists else { return "\(name)=missing" }
            let frame = element.frame
            return "\(name) x=\(frame.minX) y=\(frame.minY) maxY=\(frame.maxY) h=\(frame.height) hittable=\(element.isHittable)"
        }
        let keyboardTop = (keyboard?.exists == true) ? "\(keyboard!.frame.minY)" : "hidden"
        return [
            box("label", label),
            box("value", field),
            box("unit", unit),
            "tabButtonTop=\(tabButtonTop(app))",
            "tabGlassTop=\(tabGlassTop(app))",
            "navBottom=\(contentTop(app))",
            "keyboardTop=\(keyboardTop)"
        ].joined(separator: "; ")
    }

    // MARK: - Scrolling

    private func scrollUntilClear(_ app: XCUIApplication, row: DepthRow) {
        for _ in 0..<16 {
            if rowIsClear(row, app: app, keyboard: nil) { return }
            guard drag(app, up: true, watching: row.field) else { break }
        }
        for _ in 0..<4 {
            if rowIsClear(row, app: app, keyboard: nil) { return }
            if row.label.frame.minY < contentTop(app) - 0.5 {
                guard drag(app, up: false, watching: row.field) else { return }
            } else {
                return
            }
        }
    }

    /// Scroll one element fully into the band above the tab bar. Used for the Catenary tile.
    private func scrollUntilClear(_ app: XCUIApplication, element: XCUIElement) {
        for _ in 0..<12 {
            let frame = element.frame
            if frame.height > 1,
               frame.minY >= contentTop(app) - 0.5,
               frame.maxY <= tabGlassTop(app) + 0.5 {
                return
            }
            guard drag(app, up: true, watching: element) else { return }
        }
    }

    /// Finger drag in the open column, above the tab buttons, so the gesture cannot hit a tab.
    /// Returns whether the watched edge moved.
    @discardableResult
    private func drag(_ app: XCUIApplication, up: Bool, watching element: XCUIElement) -> Bool {
        let before = element.frame.maxY
        let top = contentTop(app) + 24
        let bottom = tabGlassTop(app) - 24
        guard bottom - top > 80 else { return false }
        let travel = min(160, bottom - top - 16)
        let startY = up ? bottom - 8 : top + 8
        let endY = up ? startY - travel : startY + travel
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY))
        let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        _ = waitUntil(timeout: 1.2) {
            abs(element.frame.maxY - before) >= 0.5
        }
        return abs(element.frame.maxY - before) >= 0.5
    }

    private func waitForKeyboard(_ app: XCUIApplication) -> XCUIElement {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard did not open")
        XCTAssertTrue(waitUntil(timeout: 3) { keyboard.frame.height > 150 }, "Keyboard frame did not settle: \(keyboard.frame)")
        return keyboard
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if condition() { return true }
            let pending = XCTNSPredicateExpectation(predicate: NSPredicate(value: false), object: nil)
            _ = XCTWaiter().wait(for: [pending], timeout: 0.1)
        }
        return false
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private enum ContentSize {
        case large
        case accessibilityExtraLarge

        var argument: String {
            switch self {
            case .large: return "UICTContentSizeCategoryL"
            case .accessibilityExtraLarge: return "UICTContentSizeCategoryAccessibilityXL"
            }
        }

        var launchArguments: [String] {
            ["-UIPreferredContentSizeCategoryName", argument]
        }

        var snapshot: String {
            switch self {
            case .large: return "large"
            case .accessibilityExtraLarge: return "accessibility-extra-large"
            }
        }
    }
}
