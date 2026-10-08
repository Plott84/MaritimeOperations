import XCTest

extension XCUIApplication {
    /// Launch argument the app checks at startup (see LaunchEnvironment.swift in the app).
    static let resetStateArgument = "-UITestResetState"
    static let inMemoryStoreArgument = "-UITestInMemoryStore"

    /// Launches the app with an empty in-memory store, no running DP timer and no saved
    /// session defaults, in portrait. Every UI test starts here; tests that need data create it themselves.
    @discardableResult
    static func launchedClean(extraArguments: [String] = []) -> XCUIApplication {
        // The launch tests run per UI configuration and can leave the Simulator in landscape,
        // where the floating tab bar covers the Add pills and menus get cut off.
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        // Value "YES" so the flag never swallows the next argument in the defaults argument domain.
        app.launchArguments = extraArguments + [resetStateArgument, "YES"]
        app.launch()
        return app
    }

    /// Terminates and relaunches keeping saved defaults (e.g. a running timer), still with an in-memory store.
    func relaunchKeepingState() {
        terminate()
        var arguments = launchArguments
        if let index = arguments.firstIndex(of: Self.resetStateArgument) {
            arguments.removeSubrange(index...min(index + 1, arguments.count - 1))
        }
        launchArguments = arguments + [Self.inMemoryStoreArgument, "YES"]
        launch()
    }
}

/// Books on the Log tab (matches LogBook raw values in the app).
enum LogBookID: String {
    case dp
    case anchorHandling
    case rov
    case crane
}

extension XCUIApplication {
    /// Log tab → book. DP Entries and Rig Moves now live inside the Log tab.
    func openLogBook(_ book: LogBookID, file: StaticString = #filePath, line: UInt = #line) {
        let logTab = buttons["tab_log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 8), "Log tab missing", file: file, line: line)
        logTab.tap()
        let card = descendants(matching: .any)["logBook_\(book.rawValue)"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Book \(book.rawValue) missing on Log", file: file, line: line)
        // ROV and Crane sit below the fold on smaller phones and at large text sizes.
        var swipes = 0
        while !card.isHittable && swipes < 6 {
            swipeUp()
            swipes += 1
        }
        card.tap()
    }

    /// An Anchor handling book row; its spoken label carries job type, rig, vessel, date and hours.
    func ahRow(containing text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// A row in any book (ROV, Crane, …); rows read their key values in their spoken label.
    func bookRow(containing text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
