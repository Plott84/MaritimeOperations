import CoreGraphics
import XCTest

/// QA pass rules for Catenary Depth while the keyboard is up.
///
/// 1. The field and its unit sit at least 16 pt above the raised bar
///    (tab buttons or keyboard top, whichever is higher) at Large and at
///    accessibility extra large. `ToolsKeyboardPass.aboveRaisedBar` is that 16 pt.
/// 2. Done does not cover the unit.
/// 3. The tab bar is not hittable while the keyboard is up, and after Done the
///    same Tools tab is still selected on Catenary. Large also requires the
///    Tools tab to be hittable. Accessibility extra large taps Export and waits
///    for `exportBook_dp`.
///
/// The official `CatenaryDepthReachabilityUITests` stay as they are.
/// Authoring VM had no Xcode; this test was not executed there.
final class ToolsKeyboardChromeUITests: XCTestCase {
    /// Same gap as `ToolsKeyboardPass.aboveRaisedBar`.
    private static let aboveRaisedBar: CGFloat = 16

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testKeyboardPassRulesAtLarge() throws {
        try exercise(.large)
    }

    func testKeyboardPassRulesAtAccessibilityExtraLarge() throws {
        try exercise(.accessibilityExtraLarge)
    }

    /// KB-AXL-01. Wire diameter is the row above Barrel diameter.
    func testKBAXL01WinchBarrelUnitClearsKeyboardToolbar() throws {
        let app = XCUIApplication.launchedClean(extraArguments: ContentSize.accessibilityExtraLarge.launchArguments)
        openTool(app, tile: "toolTile.winch", title: "Winch capacity")
        focusField(app, identifier: "winchField.wireDia")
        let keyboard = waitForKeyboard(app)
        let done = keyboardDone(app)
        let barrel = app.textFields["winchField.barrelD0"]
        XCTAssertTrue(barrel.waitForExistence(timeout: 3), "Barrel diameter field missing")
        XCTAssertTrue(
            waitUntil(timeout: 3) {
                guard let toolbarTop = self.toolbarMinY(app, keyboard: keyboard, done: done) else { return false }
                guard let unit = self.unitBeside(barrel, in: app, label: "mm") else { return false }
                return unit.frame.height > 1
                    && unit.frame.maxY <= toolbarTop - Self.aboveRaisedBar + 0.5
                    && barrel.isHittable
            },
            "Barrel diameter mm is not 16 pt above the keyboard toolbar, or the field is not hittable. toolbar=\(toolbarMinY(app, keyboard: keyboard, done: done).map { "\($0)" } ?? "missing") barrel=\(barrel.frame) unit=\(unitBeside(barrel, in: app, label: "mm")?.frame.debugDescription ?? "missing")"
        )
        let toolbarTop = try XCTUnwrap(toolbarMinY(app, keyboard: keyboard, done: done), "Keyboard toolbar missing")
        let unit = try XCTUnwrap(unitBeside(barrel, in: app, label: "mm"), "Barrel diameter mm missing")
        XCTAssertLessThanOrEqual(
            unit.frame.maxY,
            toolbarTop - Self.aboveRaisedBar + 0.5,
            "Barrel diameter mm maxY \(unit.frame.maxY) is not 16 pt above the toolbar \(toolbarTop)"
        )
        XCTAssertTrue(barrel.isHittable, "Barrel diameter field is not hittable")
    }

    /// KB-AXL-02. Load is the row above Sling length.
    func testKBAXL02RiggingSlingLengthClearsKeyboardToolbar() throws {
        let app = XCUIApplication.launchedClean(extraArguments: ContentSize.accessibilityExtraLarge.launchArguments)
        openTool(app, tile: "toolTile.rigging", title: "Slinging & Rigging")
        focusField(app, identifier: "rigging.load")
        let keyboard = waitForKeyboard(app)
        let done = keyboardDone(app)
        let length = app.textFields["rigging.length"]
        XCTAssertTrue(length.waitForExistence(timeout: 3), "Sling length field missing")
        XCTAssertTrue(
            waitUntil(timeout: 3) {
                guard let toolbarTop = self.toolbarMinY(app, keyboard: keyboard, done: done) else { return false }
                let frame = length.frame
                return frame.height > 1 && frame.maxY <= toolbarTop + 0.5 && length.isHittable
            },
            "Sling length is not fully above the keyboard toolbar, or the field is not hittable. toolbar=\(toolbarMinY(app, keyboard: keyboard, done: done).map { "\($0)" } ?? "missing") field=\(length.frame)"
        )
        let toolbarTop = try XCTUnwrap(toolbarMinY(app, keyboard: keyboard, done: done), "Keyboard toolbar missing")
        XCTAssertLessThanOrEqual(
            length.frame.maxY,
            toolbarTop + 0.5,
            "Sling length maxY \(length.frame.maxY) is not above the toolbar \(toolbarTop)"
        )
        XCTAssertGreaterThan(length.frame.minY, contentTop(app), "Sling length has no frame below the navigation bar")
        XCTAssertTrue(length.isHittable, "Sling length field is not hittable")
    }

    /// KB-AXL-03. `tab_export` is not checked with `isHittable`; AXL reports that as a false negative.
    func testKBAXL03WinchAndRiggingLastFieldDoneLeavesExportReachable() throws {
        let app = XCUIApplication.launchedClean(extraArguments: ContentSize.accessibilityExtraLarge.launchArguments)
        openTool(app, tile: "toolTile.winch", title: "Winch capacity")
        focusField(app, labeled: "1st-layer pull (optional)")
        _ = waitForKeyboard(app)
        assertExportReachableAfterDone(app)

        openTool(app, tile: "toolTile.rigging", title: "Slinging & Rigging")
        focusField(app, identifier: "rigging.tag")
        _ = waitForKeyboard(app)
        assertExportReachableAfterDone(app)
    }

    private func exercise(_ size: ContentSize) throws {
        let app = XCUIApplication.launchedClean(extraArguments: size.launchArguments)
        openCatenary(app)
        let row = try depthRow(app)
        scrollUntilClearOfTabs(app, row: row)
        assertContentSize(size, caption: row.label, field: row.field)

        let tools = app.buttons["tab_tools"]
        XCTAssertTrue(tools.isSelected)
        row.field.tap()
        XCTAssertTrue(app.navigationBars["Catenary"].waitForExistence(timeout: 3))
        XCTAssertTrue(tools.isSelected, "Focusing Depth changed the selected tab")

        let keyboard = waitForKeyboard(app)
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3), "Keyboard Done must stay reachable")

        XCTAssertTrue(
            waitUntil(timeout: 3) {
                self.inputClearsRaisedBar(row, app: app, keyboard: keyboard)
                    && !self.doneCoversUnit(row.unit, done: done)
                    && tools.exists
                    && !tools.isHittable
            },
            """
            Keyboard pass rules failed at \(size.snapshot).
            The field and unit must sit at least \(Self.aboveRaisedBar) pt above the raised bar,
            Done must not cover the unit, and the tab bar must hide while the keyboard is up.
            \(geometry(app, row: row, keyboard: keyboard, done: done))
            """
        )
        for identifier in ["tab_main", "tab_log", "tab_tools", "tab_export"] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.exists, "\(identifier) missing while the keyboard is up")
            XCTAssertGreaterThan(button.frame.height, 1, "\(identifier) has no frame while the keyboard is up")
            XCTAssertFalse(button.isHittable, "\(identifier) is still hittable while the keyboard is up")
        }
        XCTAssertTrue(done.isHittable, "Keyboard Done is not hittable")
        XCTAssertFalse(
            doneCoversUnit(row.unit, done: done),
            "Done covers the Depth unit. \(geometry(app, row: row, keyboard: keyboard, done: done))"
        )
        XCTAssertTrue(
            inputClearsRaisedBar(row, app: app, keyboard: keyboard),
            "Depth input is not \(Self.aboveRaisedBar) pt above the raised bar. \(geometry(app, row: row, keyboard: keyboard, done: done))"
        )

        done.tap()
        let keyboardGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter().wait(for: [keyboardGone], timeout: 5), .completed, "Done did not dismiss the keyboard")
        switch size {
        case .large:
            XCTAssertTrue(
                waitUntil(timeout: 3) { tools.isHittable && tools.isSelected },
                "Tab bar did not return on the Tools tab after Done"
            )
            XCTAssertTrue(app.navigationBars["Catenary"].exists, "Done left Catenary")
            XCTAssertFalse(app.buttons["tab_log"].isSelected, "Done selected Entries")
            XCTAssertFalse(app.buttons["tab_main"].isSelected, "Done selected Main")
            XCTAssertFalse(app.buttons["tab_export"].isSelected, "Done selected Export")
        case .accessibilityExtraLarge:
            XCTAssertTrue(tools.isSelected, "Tools tab was not selected after Done")
            let export = app.buttons["tab_export"]
            XCTAssertTrue(export.waitForExistence(timeout: 5), "Export tab missing after Done")
            export.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)["exportBook_dp"].waitForExistence(timeout: 5),
                "Export did not open"
            )
        }
    }

    // MARK: - Rules

    private func inputClearsRaisedBar(_ row: DepthRow, app: XCUIApplication, keyboard: XCUIElement) -> Bool {
        guard let raised = raisedBarTop(app, keyboard: keyboard) else { return false }
        let limit = raised - Self.aboveRaisedBar
        return [row.field, row.unit].allSatisfy { part in
            let frame = part.frame
            return frame.width > 1 && frame.height > 1 && frame.maxY <= limit + 0.5
        }
    }

    private func doneCoversUnit(_ unit: XCUIElement, done: XCUIElement) -> Bool {
        guard done.exists, unit.exists else { return true }
        let unitFrame = unit.frame
        let doneFrame = done.frame
        guard unitFrame.width > 1, unitFrame.height > 1, doneFrame.width > 1, doneFrame.height > 1 else { return true }
        return unitFrame.intersects(doneFrame)
    }

    private func raisedBarTop(_ app: XCUIApplication, keyboard: XCUIElement) -> CGFloat? {
        var candidates: [CGFloat] = []
        let buttons = tabButtonTop(app)
        if buttons > 1 { candidates.append(buttons) }
        if keyboard.exists, keyboard.frame.height > 100, keyboard.frame.minY > 1 {
            candidates.append(keyboard.frame.minY)
        }
        return candidates.min()
    }

    // MARK: - Navigation

    private func openCatenary(_ app: XCUIApplication) {
        let tools = app.buttons["tab_tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 8), "Tools tab missing")
        tools.tap()
        XCTAssertTrue(app.navigationBars["Tools"].waitForExistence(timeout: 5))
        let tile = app.descendants(matching: .any)["toolTile.catenary"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "Catenary tile missing")
        scrollUntil(app, element: tile, isClear: { element in
            element.frame.height > 1 && element.frame.maxY <= self.tabButtonTop(app) + 0.5
        })
        tile.tap()
        XCTAssertTrue(app.navigationBars["Catenary"].waitForExistence(timeout: 5))
    }

    private struct DepthRow {
        let label: XCUIElement
        let field: XCUIElement
        let unit: XCUIElement
    }

    private func depthRow(_ app: XCUIApplication) throws -> DepthRow {
        let label = app.staticTexts.matching(NSPredicate(format: "label == %@", "Depth (optional)")).firstMatch
        let field = app.textFields.matching(NSPredicate(format: "label == %@", "Depth (optional)")).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 3), "Depth caption missing")
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Depth field missing")
        scrollUntil(app, element: field, isClear: { _ in self.unitBeside(field, in: app) != nil })
        let unit = try XCTUnwrap(unitBeside(field, in: app), "No single “m” beside Depth")
        return DepthRow(label: label, field: field, unit: unit)
    }

    private func unitBeside(_ field: XCUIElement, in app: XCUIApplication, label: String = "m") -> XCUIElement? {
        let units = app.staticTexts.matching(NSPredicate(format: "label == %@", label))
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
        switch size {
        case .large:
            XCTAssertGreaterThan(height, 10, "Depth caption has no frame", file: file, line: line)
            XCTAssertLessThan(height, 28, "Content size is larger than large. \(height)", file: file, line: line)
        case .accessibilityExtraLarge:
            XCTAssertGreaterThan(height, 34, "accessibility-extra-large did not apply. \(height)", file: file, line: line)
        }
        XCTAssertGreaterThan(field.frame.height, 1, file: file, line: line)
    }

    private func scrollUntilClearOfTabs(_ app: XCUIApplication, row: DepthRow) {
        let floor = contentTop(app)
        let clear = {
            [row.label, row.field, row.unit].allSatisfy { part in
                let frame = part.frame
                return frame.height > 1 && frame.minY >= floor - 0.5 && frame.maxY <= self.tabButtonTop(app) + 0.5
            }
        }
        scrollUntil(app, element: row.field, isClear: { _ in clear() })
        for _ in 0..<4 {
            if clear() { return }
            if row.label.frame.minY < floor - 0.5 {
                guard drag(app, up: false, watching: row.field) else { return }
            } else {
                return
            }
        }
    }

    private func scrollUntil(_ app: XCUIApplication, element: XCUIElement, isClear: (XCUIElement) -> Bool) {
        if isClear(element) { return }
        for _ in 0..<16 {
            if isClear(element) { return }
            guard drag(app, up: true, watching: element) else { return }
        }
    }

    /// Finger drag in the open column, above the tab buttons. Distances match the reachability test’s gesture, not the 16 pt gap.
    @discardableResult
    private func drag(_ app: XCUIApplication, up: Bool, watching element: XCUIElement) -> Bool {
        let before = element.frame.maxY
        let top = contentTop(app) + 24
        let bottom = tabButtonTop(app) - 24
        guard bottom - top > 80 else { return false }
        let travel = min(160, bottom - top - 16)
        let startY = up ? bottom - 8 : top + 8
        let endY = up ? startY - travel : startY + travel
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY))
        let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        _ = waitUntil(timeout: 1.2) { abs(element.frame.maxY - before) >= 0.5 }
        return abs(element.frame.maxY - before) >= 0.5
    }

    private func contentTop(_ app: XCUIApplication) -> CGFloat {
        for title in ["Catenary", "Winch capacity", "Slinging & Rigging", "Tools"] {
            let bar = app.navigationBars[title]
            if bar.exists, bar.frame.maxY > 1 {
                return bar.frame.maxY
            }
        }
        return app.navigationBars.firstMatch.frame.maxY
    }

    private func openTool(_ app: XCUIApplication, tile identifier: String, title: String) {
        let tools = app.buttons["tab_tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 8), "Tools tab missing")
        tools.tap()
        XCTAssertTrue(app.navigationBars["Tools"].waitForExistence(timeout: 5))
        let tile = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "\(identifier) missing")
        scrollUntil(app, element: tile, isClear: { element in
            element.frame.height > 1
                && element.frame.maxY <= self.tabButtonTop(app) + 0.5
                && element.isHittable
        })
        tile.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), title)
    }

    @discardableResult
    private func focusField(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), identifier)
        revealAboveTabs(app, field)
        field.tap()
        return field
    }

    @discardableResult
    private func focusField(_ app: XCUIApplication, labeled label: String) -> XCUIElement {
        let field = app.textFields.matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), label)
        revealAboveTabs(app, field)
        field.tap()
        return field
    }

    private func revealAboveTabs(_ app: XCUIApplication, _ element: XCUIElement) {
        scrollUntil(app, element: element, isClear: { element in
            let frame = element.frame
            return frame.height > 1
                && frame.minY >= self.contentTop(app) - 0.5
                && frame.maxY <= self.tabButtonTop(app) + 0.5
                && element.isHittable
        })
    }

    private func keyboardDone(_ app: XCUIApplication) -> XCUIElement {
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3), "Keyboard Done must stay reachable")
        return done
    }

    /// Toolbar that contains Done. Prefer the bar inside the keyboard, then any toolbar whose frame holds Done.
    private func keyboardToolbar(in app: XCUIApplication, keyboard: XCUIElement, done: XCUIElement) -> XCUIElement {
        let keyboardBars = keyboard.toolbars.containing(NSPredicate(format: "label == %@", "Done"))
        if keyboardBars.firstMatch.exists, keyboardBars.firstMatch.frame.height > 1 {
            return nearestBar(in: keyboardBars, to: done)
        }
        let bars = app.toolbars.containing(NSPredicate(format: "label == %@", "Done"))
        return nearestBar(in: bars, to: done)
    }

    private func nearestBar(in bars: XCUIElementQuery, to done: XCUIElement) -> XCUIElement {
        var best: XCUIElement?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for index in 0..<bars.count {
            let bar = bars.element(boundBy: index)
            let frame = bar.frame
            guard frame.height > 1, frame.intersects(done.frame) else { continue }
            let distance = abs(frame.midY - done.frame.midY)
            if distance < bestDistance {
                bestDistance = distance
                best = bar
            }
        }
        return best ?? bars.firstMatch
    }

    private func toolbarMinY(_ app: XCUIApplication, keyboard: XCUIElement, done: XCUIElement) -> CGFloat? {
        let bar = keyboardToolbar(in: app, keyboard: keyboard, done: done)
        guard bar.exists, bar.frame.height > 1, bar.frame.minY > 1 else { return nil }
        return bar.frame.minY
    }

    private func assertExportReachableAfterDone(_ app: XCUIApplication) {
        let done = keyboardDone(app)
        done.tap()
        let keyboardGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter().wait(for: [keyboardGone], timeout: 5), .completed, "Done did not dismiss the keyboard")
        let export = app.buttons["tab_export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5), "Export tab missing after Done")
        export.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["exportBook_dp"].waitForExistence(timeout: 5),
            "Export did not open"
        )
    }

    private func tabButtonTop(_ app: XCUIApplication) -> CGFloat {
        ["tab_main", "tab_log", "tab_tools", "tab_export"]
            .map { app.buttons[$0].frame.minY }
            .min() ?? .greatestFiniteMagnitude
    }

    private func waitForKeyboard(_ app: XCUIApplication) -> XCUIElement {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard did not open")
        XCTAssertTrue(waitUntil(timeout: 3) { keyboard.frame.height > 150 }, "Keyboard frame did not settle")
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

    private func geometry(_ app: XCUIApplication, row: DepthRow, keyboard: XCUIElement, done: XCUIElement) -> String {
        func box(_ name: String, _ element: XCUIElement) -> String {
            let frame = element.frame
            return "\(name) y=\(frame.minY) maxY=\(frame.maxY) h=\(frame.height)"
        }
        let raised = raisedBarTop(app, keyboard: keyboard).map { "\($0)" } ?? "missing"
        return "\(box("field", row.field)); \(box("unit", row.unit)); \(box("done", done)); raised=\(raised); keyboardTop=\(keyboard.frame.minY)"
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
