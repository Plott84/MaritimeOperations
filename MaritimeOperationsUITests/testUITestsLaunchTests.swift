import XCTest

final class testUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

    func testLaunch() throws {
        let app = XCUIApplication.launchedClean()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
