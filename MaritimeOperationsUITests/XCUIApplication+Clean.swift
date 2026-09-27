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
