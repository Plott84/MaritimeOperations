import Foundation

/// Configurable DP-day eligibility. Never hardcode 1h vs 2h scheme rules in call sites.
struct EligibilityConfig: Codable, Equatable, Sendable {
    /// Minimum hours engaged in DP to count as an eligible day for the user's book.
    var minimumHoursForEligibleDay: Double

    static let `default` = EligibilityConfig(minimumHoursForEligibleDay: 1.0)

    func isEligible(durationHours: Double) -> Bool {
        durationHours + 0.000_1 >= minimumHoursForEligibleDay
    }
}

enum EligibilitySettings {
    private static let key = "eligibilityConfig.minimumHoursForEligibleDay"

    static var current: EligibilityConfig {
        get {
            let stored = UserDefaults.standard.object(forKey: key) as? Double
            return EligibilityConfig(minimumHoursForEligibleDay: stored ?? EligibilityConfig.default.minimumHoursForEligibleDay)
        }
        set {
            UserDefaults.standard.set(newValue.minimumHoursForEligibleDay, forKey: key)
        }
    }
}
