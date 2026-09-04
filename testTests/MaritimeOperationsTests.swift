import Testing
import Foundation
@testable import test

struct MaritimeOperationsTests {
    @Test func eligibilityUsesConfiguredThreshold() {
        let config = EligibilityConfig(minimumHoursForEligibleDay: 1.0)
        #expect(config.isEligible(durationHours: 1.0))
        #expect(!config.isEligible(durationHours: 0.9))

        let twoHour = EligibilityConfig(minimumHoursForEligibleDay: 2.0)
        #expect(!twoHour.isEligible(durationHours: 1.5))
        #expect(twoHour.isEligible(durationHours: 2.0))
    }

    @Test func timerFormatterHandlesHours() {
        #expect(AppFormatters.timerString(from: 0) == "00:00")
        #expect(AppFormatters.timerString(from: 65) == "01:05")
        #expect(AppFormatters.timerString(from: 3661) == "01:01:01")
    }
}
