import Foundation

/// Exclusive quick-range chips on the Export sheet.
enum ExportQuickRange: String, CaseIterable, Identifiable, Equatable {
    case thisYear
    case last90Days
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisYear: return "This year"
        case .last90Days: return "Last 90 days"
        case .allTime: return "All time"
        }
    }
}

/// Which books are included in a multi-book export. Defaults: all On.
struct ExportBookSelection: Equatable {
    var dp: Bool = true
    var anchorHandling: Bool = true
    var rov: Bool = true
    var crane: Bool = true

    var hasAnyBook: Bool {
        dp || anchorHandling || rov || crane
    }

    /// Share… is enabled only when at least one book is selected.
    var canShare: Bool { hasAnyBook }

    func isOn(_ book: LogBook) -> Bool {
        switch book {
        case .dp: return dp
        case .anchorHandling: return anchorHandling
        case .rov: return rov
        case .crane: return crane
        }
    }

    mutating func set(_ book: LogBook, on: Bool) {
        switch book {
        case .dp: dp = on
        case .anchorHandling: anchorHandling = on
        case .rov: rov = on
        case .crane: crane = on
        }
    }

    var selectedBooks: [LogBook] {
        LogBook.allCases.filter { isOn($0) }
    }

    var includedSummary: String {
        let names = selectedBooks.map(\.title)
        guard !names.isEmpty else { return "None" }
        return names.joined(separator: ", ")
    }
}

/// Date filter for Export. `allTime` clears From/To (no invented dates).
struct ExportDateFilter: Equatable {
    var quickRange: ExportQuickRange?
    /// Inclusive start-of-day. Nil when All time.
    var from: Date?
    /// Inclusive end-of-day. Nil when All time.
    var to: Date?

    var isAllTime: Bool { quickRange == .allTime || (from == nil && to == nil) }

    /// Default: This year chip · From = 1 Jan this year (or earliest entry if later) · To = today.
    static func defaults(
        earliestEntry: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ExportDateFilter {
        applied(.thisYear, earliestEntry: earliestEntry, now: now, calendar: calendar)
    }

    static func applied(
        _ range: ExportQuickRange,
        earliestEntry: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ExportDateFilter {
        let today = calendar.startOfDay(for: now)
        switch range {
        case .thisYear:
            let jan1 = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1))!
            let fromDay = calendar.startOfDay(for: jan1)
            let resolvedFrom: Date
            if let earliest = earliestEntry {
                let earliestDay = calendar.startOfDay(for: earliest)
                resolvedFrom = max(fromDay, earliestDay)
            } else {
                resolvedFrom = fromDay
            }
            return ExportDateFilter(quickRange: .thisYear, from: resolvedFrom, to: today)
        case .last90Days:
            let fromDay = calendar.date(byAdding: .day, value: -90, to: today) ?? today
            return ExportDateFilter(quickRange: .last90Days, from: fromDay, to: today)
        case .allTime:
            return ExportDateFilter(quickRange: .allTime, from: nil, to: nil)
        }
    }

    /// Whether `date` falls inside the active filter (calendar-day inclusive).
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        if isAllTime { return true }
        let day = calendar.startOfDay(for: date)
        if let from {
            let fromDay = calendar.startOfDay(for: from)
            if day < fromDay { return false }
        }
        if let to {
            let toDay = calendar.startOfDay(for: to)
            if day > toDay { return false }
        }
        return true
    }
}

/// Filtered live counts for the preview and desk card. DP hours are DP-book only.
struct ExportSnapshot: Equatable {
    var dpEntries: Int = 0
    var dpHours: Double = 0
    var rigMoves: Int = 0
    /// Sum of AH worked hours (PDF detail only — preview line uses move count).
    var anchorHours: Double = 0
    var rovEntries: Int = 0
    var rovHours: Double = 0
    var craneEntries: Int = 0
    var craneHours: Double = 0

    /// True when every selected book contributes zero matching rows.
    func isEmpty(for books: ExportBookSelection) -> Bool {
        guard books.hasAnyBook else { return true }
        var any = false
        if books.dp { any = any || dpEntries > 0 }
        if books.anchorHandling { any = any || rigMoves > 0 }
        if books.rov { any = any || rovEntries > 0 }
        if books.crane { any = any || craneEntries > 0 }
        return !any
    }

    func count(for book: LogBook) -> Int {
        switch book {
        case .dp: return dpEntries
        case .anchorHandling: return rigMoves
        case .rov: return rovEntries
        case .crane: return craneEntries
        }
    }

    func hours(for book: LogBook) -> Double? {
        switch book {
        case .dp: return dpHours
        case .anchorHandling: return anchorHours
        case .rov: return rovHours
        case .crane: return craneHours
        }
    }

    /// Preview line value after the book name, e.g. "12 entries · 87.5 h" / "3 rig moves".
    func previewValue(for book: LogBook) -> String {
        switch book {
        case .dp:
            return "\(LogBookStats.entriesText(dpEntries)) · \(Self.hoursText(dpHours))"
        case .anchorHandling:
            return rigMoves == 1 ? "1 rig move" : "\(rigMoves) rig moves"
        case .rov:
            return "\(LogBookStats.entriesText(rovEntries)) · \(Self.hoursText(rovHours))"
        case .crane:
            return "\(LogBookStats.entriesText(craneEntries)) · \(Self.hoursText(craneHours))"
        }
    }

    func previewLine(for book: LogBook) -> String {
        "\(book.title) · \(previewValue(for: book))"
    }

    func previewLines(for books: ExportBookSelection) -> [String] {
        books.selectedBooks.map { previewLine(for: $0) }
    }

    /// Clipboard text: preview lines + disclaimer footer.
    func copySummary(for books: ExportBookSelection, dateFilter: ExportDateFilter) -> String {
        var lines: [String] = ["Maritime Operations — Export summary"]
        lines.append(periodLine(dateFilter))
        lines.append("Including: \(books.includedSummary)")
        lines.append("")
        if books.hasAnyBook {
            if isEmpty(for: books) {
                lines.append(ExportDisclaimer.emptyPreview)
            } else {
                lines.append(contentsOf: previewLines(for: books))
            }
        } else {
            lines.append("No books selected.")
        }
        lines.append("")
        lines.append(ExportDisclaimer.previewFooter)
        lines.append(ExportDisclaimer.text)
        return lines.joined(separator: "\n")
    }

    func periodLine(_ filter: ExportDateFilter, calendar: Calendar = .current) -> String {
        if filter.isAllTime { return "Period: All time" }
        let df = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let fromText = filter.from.map { $0.formatted(df) } ?? "—"
        let toText = filter.to.map { $0.formatted(df) } ?? "—"
        return "Period: \(fromText) – \(toText)"
    }

    static func hoursText(_ hours: Double) -> String {
        "\(LogBookStats.hoursNumber(hours)) h"
    }
}

/// Builds an `ExportSnapshot` from live SwiftData rows ∩ date filter.
/// ROV / Crane never fold into DP hours (see `DPHoursScope`).
enum ExportAggregator {
    static func earliestEntryDate(
        dp: [DPEntry],
        moves: [RigMove],
        rov: [ROVEntry],
        crane: [CraneEntry]
    ) -> Date? {
        let dates = dp.map(\.date) + moves.map(\.date) + rov.map(\.date) + crane.map(\.date)
        return dates.min()
    }

    static func snapshot(
        dp: [DPEntry],
        moves: [RigMove],
        rov: [ROVEntry],
        crane: [CraneEntry],
        filter: ExportDateFilter,
        calendar: Calendar = .current
    ) -> ExportSnapshot {
        let dpRows = dp.filter { filter.contains($0.date, calendar: calendar) }
        let moveRows = moves.filter { filter.contains($0.date, calendar: calendar) }
        let rovRows = rov.filter { filter.contains($0.date, calendar: calendar) }
        let craneRows = crane.filter { filter.contains($0.date, calendar: calendar) }

        // DP hours = DP book only. Never add ROV piloting or Crane operated hours
        // (DPHoursScope.books == [.dp]; ROV/Crane excluded by construction below).

        return ExportSnapshot(
            dpEntries: dpRows.count,
            dpHours: dpRows.reduce(0) { $0 + $1.durationHours },
            rigMoves: moveRows.count,
            anchorHours: moveRows.reduce(0) { $0 + ($1.workedHours ?? 0) },
            rovEntries: rovRows.count,
            rovHours: rovRows.reduce(0) { $0 + ($1.pilotingHours ?? 0) },
            craneEntries: craneRows.count,
            // Hours operated only. Lift weight and wire out stay on the Crane entry.
            craneHours: craneRows.reduce(0) { $0 + ($1.hoursOperated ?? 0) }
        )
    }
}
