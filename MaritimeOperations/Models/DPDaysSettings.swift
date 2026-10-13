import Foundation

/// DP day target and the optional issue date. Empty target text, or 0, means no ratio and no bar.
nonisolated enum DPDaysSettings {
    static let targetTextKey = "dp.dayTargetText"
    static let certificateKey = "dp.certificateIssued"
    static let defaultTargetText = "150"

    /// Missing, blank, or not a positive whole number → nil (no ratio).
    static func parsedTarget(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    static func parsedCertificate(_ iso: String) -> DPDaysCount.Day? {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "GMT") ?? .current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        return DPDaysCount.Day(year: year, month: month, day: day)
    }

    static func isoString(from date: Date, timeZone: TimeZone) -> String {
        let day = DPDaysCount.Day(instant: date, timeZone: timeZone)
        return String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }
}
