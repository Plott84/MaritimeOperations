import Foundation
import SwiftData

/// NI DP-day count for a rolling 5-year window. Port of the locked reference (13 Oct 2026).
///
/// - Only DP watches count. ROV and Crane watches are ignored.
/// - A watch splits at midnight in the given time zone. Minutes on one calendar day are summed,
///   including two short watches (team assumption).
/// - A day counts at 2 h, or at 1 h before 1 Jan 2015.
/// - Counted days are after max(as-of minus 5 years, the optional issue date) and on or before as-of.
///   29 Feb steps back to 28 Feb. The issue date itself is outside the window.
/// - One mixed day counts once, under the class with the most minutes. A tie goes to the higher class
///   (DP3, then DP2, then DP1).
/// - No target, or a target of 0, means no ratio.
nonisolated enum DPDaysCount {
    static let caption = "Rolling 5 years · days with 2 h or more on the DP desk"
    static let footer = "ROV and Crane hours are not counted."
    static let settingsHint = "Set a target in Settings to see progress ›"
    static let dpKind = "DP"
    static let classRank = ["DP1": 1, "DP2": 2, "DP3": 3]

    struct Day: Hashable, Comparable {
        var year: Int
        var month: Int
        var day: Int

        init(year: Int, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }

        init(instant: Date, timeZone: TimeZone) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.year, .month, .day], from: instant)
            year = parts.year ?? 1
            month = parts.month ?? 1
            day = parts.day ?? 1
        }

        static func < (lhs: Day, rhs: Day) -> Bool {
            if lhs.year != rhs.year { return lhs.year < rhs.year }
            if lhs.month != rhs.month { return lhs.month < rhs.month }
            return lhs.day < rhs.day
        }

        func minusYears(_ years: Int) -> Day {
            let year = self.year - years
            if month == 2, day == 29, !Self.isLeapYear(year) {
                return Day(year: year, month: 2, day: 28)
            }
            return Day(year: year, month: month, day: day)
        }

        func addingDays(_ days: Int, timeZone: TimeZone) -> Day {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let noon = DateComponents(
                calendar: calendar,
                timeZone: timeZone,
                year: year,
                month: month,
                day: day,
                hour: 12
            )
            guard let date = calendar.date(from: noon),
                  let shifted = calendar.date(byAdding: .day, value: days, to: date) else {
                return self
            }
            return Day(instant: shifted, timeZone: timeZone)
        }

        func date(timeZone: TimeZone) -> Date? {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(from: DateComponents(
                calendar: calendar,
                timeZone: timeZone,
                year: year,
                month: month,
                day: day,
                hour: 12
            ))
        }

        private static func isLeapYear(_ year: Int) -> Bool {
            (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        }
    }

    /// Absolute instant. `hasTimeZone == false` is the reference's naive datetime and is rejected.
    struct Moment: Equatable {
        var instant: Date
        var hasTimeZone: Bool
    }

    struct Watch: Equatable {
        var start: Moment
        var end: Moment
        var dpClass: String
        var kind: String
    }

    /// One saved DP line, already detached from the store, for the card count.
    struct LogInterval: Equatable {
        var start: Date?
        var end: Date?
        var date: Date
        var durationHours: Double
        var dpClassLevel: Int?
        var dpClassText: String
    }

    struct Result: Equatable {
        var days: Int
        var target: Int?
        var byClass: [String: Int]
        var windowStart: Day
        var windowEnd: Day

        /// Width of the bar as a fraction of the track. Nil when there is no ratio.
        var progressFraction: Double? {
            guard let target, target > 0 else { return nil }
            return min(Double(days) / Double(target), 1)
        }

        /// Class 1, then 2, then 3. Classes with no counted days are left out.
        var classPills: [ClassPill] {
            [1, 2, 3].compactMap { level in
                guard let code = DPDaysCount.classCode(level: level),
                      let count = byClass[code], count > 0 else { return nil }
                return ClassPill(level: level, days: count)
            }
        }
    }

    struct ClassPill: Hashable, Identifiable {
        var level: Int
        var days: Int
        var id: Int { level }
    }

    enum Failure: Error, Equatable {
        case naiveDateTime
        case endNotAfterStart
        case badDPClass
        case badTarget
    }

    static func dpDays(
        watches: [Watch],
        asOf: Day,
        timeZone: TimeZone,
        target: Int? = 150,
        certificateIssued: Day? = nil
    ) throws -> Result {
        if let target, target <= 0 {
            throw Failure.badTarget
        }
        var perDay: [Day: [String: Double]] = [:]
        for watch in watches {
            guard watch.kind == dpKind else { continue }
            guard classRank[watch.dpClass] != nil else { throw Failure.badDPClass }
            let parts = try splitMinutes(start: watch.start, end: watch.end, timeZone: timeZone)
            for (day, minutes) in parts {
                var classes = perDay[day] ?? [:]
                classes[watch.dpClass, default: 0] += minutes
                perDay[day] = classes
            }
        }
        var lower = asOf.minusYears(5)
        if let certificateIssued, certificateIssued > lower {
            lower = certificateIssued
        }
        var days = 0
        var byClass: [String: Int] = [:]
        for (day, classes) in perDay {
            guard lower < day, day <= asOf else { continue }
            let total = classes.values.reduce(0, +)
            let need = day < Day(year: 2015, month: 1, day: 1) ? 60.0 : 120.0
            guard total >= need else { continue }
            guard let winner = classes.max(by: { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                return (classRank[lhs.key] ?? 0) < (classRank[rhs.key] ?? 0)
            })?.key else { continue }
            days += 1
            byClass[winner, default: 0] += 1
        }
        return Result(days: days, target: target, byClass: byClass, windowStart: lower, windowEnd: asOf)
    }

    /// Card count. Lines without a class 1–3, or with no positive duration, are left out
    /// so one old line cannot blank the card. The pure `dpDays` still rejects a bad class.
    static func count(
        intervals: [LogInterval],
        asOf: Date,
        timeZone: TimeZone,
        target: Int?,
        certificateIssued: Day?
    ) -> Result {
        let today = Day(instant: asOf, timeZone: timeZone)
        let safeTarget: Int? = (target ?? 0) > 0 ? target : nil
        let watches = intervals.compactMap { watch(from: $0) }
        if let result = try? dpDays(
            watches: watches,
            asOf: today,
            timeZone: timeZone,
            target: safeTarget,
            certificateIssued: certificateIssued
        ) {
            return result
        }
        return (try? dpDays(
            watches: [],
            asOf: today,
            timeZone: timeZone,
            target: safeTarget,
            certificateIssued: certificateIssued
        )) ?? Result(days: 0, target: safeTarget, byClass: [:], windowStart: today, windowEnd: today)
    }

    static func watch(from interval: LogInterval) -> Watch? {
        guard let code = classCode(storedLevel: interval.dpClassLevel, text: interval.dpClassText) else {
            return nil
        }
        let start = interval.start ?? interval.date
        let end = interval.end ?? start.addingTimeInterval(interval.durationHours * 3600)
        guard end > start else { return nil }
        return Watch(
            start: Moment(instant: start, hasTimeZone: true),
            end: Moment(instant: end, hasTimeZone: true),
            dpClass: code,
            kind: dpKind
        )
    }

    static func classCode(level: Int) -> String? {
        switch level {
        case 1: return "DP1"
        case 2: return "DP2"
        case 3: return "DP3"
        default: return nil
        }
    }

    static func classLevel(stored: Int?, text: String) -> Int? {
        if let stored, (1...3).contains(stored) { return stored }
        return classLevel(fromText: text)
    }

    static func classCode(storedLevel: Int?, text: String) -> String? {
        guard let level = classLevel(stored: storedLevel, text: text) else { return nil }
        return classCode(level: level)
    }

    /// "DP2", "Class 2", "Class 1 (old text)", "2".
    static func classLevel(fromText text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let folded = trimmed.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        switch folded {
        case "DP1", "CLASS1", "1": return 1
        case "DP2", "CLASS2", "2": return 2
        case "DP3", "CLASS3", "3": return 3
        default: break
        }
        if let range = folded.range(of: "CLASS"),
           let digit = folded[range.upperBound...].first,
           let level = Int(String(digit)),
           (1...3).contains(level) {
            return level
        }
        if folded.hasPrefix("DP"),
           let digit = folded.dropFirst(2).first,
           let level = Int(String(digit)),
           (1...3).contains(level) {
            return level
        }
        return nil
    }

    /// "Window: 14 Oct 2021 – 13 Oct 2026". The first day shown is the day after the exclusive bound.
    static func windowLine(windowStart: Day, windowEnd: Day, timeZone: TimeZone) -> String {
        let first = windowStart.addingDays(1, timeZone: timeZone)
        return "Window: \(format(first, timeZone: timeZone)) – \(format(windowEnd, timeZone: timeZone))"
    }

    static func voiceOverSummary(days: Int, target: Int?) -> String {
        if let target {
            return "DP days, \(days) of \(target), rolling 5 years"
        }
        return "DP days, \(days) days, rolling 5 years"
    }

    static func format(_ day: Day, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let noon = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: day.year,
            month: day.month,
            day: day.day,
            hour: 12
        )
        guard let date = calendar.date(from: noon) else {
            return "\(day.day) \(day.month) \(day.year)"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private static func splitMinutes(start: Moment, end: Moment, timeZone: TimeZone) throws -> [Day: Double] {
        if !start.hasTimeZone || !end.hasTimeZone {
            throw Failure.naiveDateTime
        }
        if end.instant <= start.instant {
            throw Failure.endNotAfterStart
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var cursor = start.instant
        var totals: [Day: Double] = [:]
        while cursor < end.instant {
            let day = Day(instant: cursor, timeZone: timeZone)
            let dayStart = calendar.startOfDay(for: cursor)
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: dayStart)
                ?? cursor.addingTimeInterval(86_400)
            if nextMidnight <= cursor { break }
            let segmentEnd = min(nextMidnight, end.instant)
            totals[day, default: 0] += segmentEnd.timeIntervalSince(cursor) / 60
            cursor = segmentEnd
        }
        return totals
    }
}

extension DPEntry {
    var dpDaysInterval: DPDaysCount.LogInterval {
        DPDaysCount.LogInterval(
            start: startTime,
            end: endTime,
            date: date,
            durationHours: durationHours,
            dpClassLevel: dpClassLevel,
            dpClassText: dpClass
        )
    }
}
