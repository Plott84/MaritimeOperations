import Testing
import Foundation
@testable import MaritimeOperations

/// Export tab: date-range filtering, DP isolation, zero-books share gate, empty range, disclaimer.
struct ExportSelectionTests {
    private let cal = Calendar(identifier: .gregorian)
    private let day: (Int, Int, Int) -> Date = { y, m, d in
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: Disclaimer

    @Test func disclaimerExactString() {
        #expect(
            ExportDisclaimer.text
                == "Personal aid only. This export is not an official IMCA DP Logbook record, and it is not a sign-off or certificate."
        )
    }

    // MARK: Defaults / chips

    @Test func defaultsThisYearUsesJan1OrEarliestIfLater() {
        let now = day(2026, 10, 12)
        let jan1 = day(2026, 1, 1)
        let early = ExportDateFilter.defaults(earliestEntry: day(2025, 6, 1), now: now, calendar: cal)
        #expect(early.quickRange == .thisYear)
        #expect(cal.isDate(early.from!, inSameDayAs: jan1))
        #expect(cal.isDate(early.to!, inSameDayAs: now))

        let lateEarliest = day(2026, 3, 15)
        let late = ExportDateFilter.defaults(earliestEntry: lateEarliest, now: now, calendar: cal)
        #expect(cal.isDate(late.from!, inSameDayAs: lateEarliest))
    }

    @Test func allTimeClearsDates() {
        let filter = ExportDateFilter.applied(.allTime, earliestEntry: day(2026, 1, 1), now: day(2026, 10, 12), calendar: cal)
        #expect(filter.isAllTime)
        #expect(filter.from == nil)
        #expect(filter.to == nil)
        #expect(filter.contains(day(2019, 5, 1), calendar: cal))
    }

    @Test func last90DaysWindow() {
        let now = day(2026, 10, 12)
        let filter = ExportDateFilter.applied(.last90Days, earliestEntry: nil, now: now, calendar: cal)
        #expect(filter.quickRange == .last90Days)
        #expect(filter.contains(day(2026, 7, 15), calendar: cal))
        #expect(!filter.contains(day(2026, 7, 13), calendar: cal))
        #expect(filter.contains(now, calendar: cal))
    }

    // MARK: Share gate

    @Test func shareDisabledWhenZeroBooks() {
        var books = ExportBookSelection(dp: false, anchorHandling: false, rov: false, crane: false)
        #expect(!books.canShare)
        #expect(!books.hasAnyBook)
        books.dp = true
        #expect(books.canShare)
    }

    // MARK: DP isolation + filtering

    @Test func snapshotKeepsROVAndCraneOutOfDPHours() {
        let inRange = day(2026, 6, 1)
        let dp = [
            DPEntry(source: .manual, date: inRange, durationHours: 10, vessel: "A"),
            DPEntry(source: .manual, date: inRange, durationHours: 5.5, vessel: "B")
        ]
        let moves = [RigMove(rigName: "Rig", date: inRange)]
        let rov = [
            ROVEntry(date: inRange, vessel: "V").withPiloting(8),
            ROVEntry(date: inRange, vessel: "V").withPiloting(4)
        ]
        let crane = [
            CraneEntry(date: inRange, vessel: "V").withOperated(3),
            CraneEntry(date: inRange, vessel: "V").withOperated(2.5)
        ]
        let filter = ExportDateFilter(quickRange: .allTime, from: nil, to: nil)
        let snap = ExportAggregator.snapshot(
            dp: dp, moves: moves, rov: rov, crane: crane, filter: filter, calendar: cal
        )

        #expect(snap.dpHours == 15.5)
        #expect(snap.dpEntries == 2)
        #expect(snap.rovHours == 12)
        #expect(snap.craneHours == 5.5)
        // Hard isolation: DP must not equal sum of everything.
        #expect(snap.dpHours != snap.dpHours + snap.rovHours + snap.craneHours)
        #expect(snap.dpHours == dp.reduce(0) { $0 + $1.durationHours })
        #expect(DPHoursScope.counts(.dp))
        #expect(!DPHoursScope.counts(.rov))
        #expect(!DPHoursScope.counts(.crane))
        #expect(!DPHoursScope.counts(.anchorHandling))
    }

    @Test func dateRangeFiltersEntries() {
        let inside = day(2026, 5, 10)
        let outside = day(2025, 12, 1)
        let dp = [
            DPEntry(source: .manual, date: inside, durationHours: 4, vessel: "In"),
            DPEntry(source: .manual, date: outside, durationHours: 99, vessel: "Out")
        ]
        let filter = ExportDateFilter.applied(
            .thisYear, earliestEntry: nil, now: day(2026, 10, 12), calendar: cal
        )
        let snap = ExportAggregator.snapshot(
            dp: dp, moves: [], rov: [], crane: [], filter: filter, calendar: cal
        )
        #expect(snap.dpEntries == 1)
        #expect(snap.dpHours == 4)
    }

    @Test func emptyRangeDetection() {
        let books = ExportBookSelection()
        let empty = ExportSnapshot()
        #expect(empty.isEmpty(for: books))

        let withDP = ExportSnapshot(dpEntries: 2, dpHours: 3)
        #expect(!withDP.isEmpty(for: books))

        var noBooks = ExportBookSelection(dp: false, anchorHandling: false, rov: false, crane: false)
        #expect(withDP.isEmpty(for: noBooks))
        noBooks.rov = true
        #expect(withDP.isEmpty(for: noBooks)) // DP rows don't count when ROV-only selected
    }

    @Test func previewLinesOmitOffBooksAndAHUsesMoves() {
        let snap = ExportSnapshot(
            dpEntries: 12, dpHours: 87.5,
            rigMoves: 3, anchorHours: 18,
            rovEntries: 4, rovHours: 22,
            craneEntries: 2, craneHours: 9.5
        )
        var books = ExportBookSelection()
        let all = snap.previewLines(for: books)
        #expect(all.count == 4)
        #expect(all[0] == snap.previewLine(for: .dp))
        #expect(all.contains("Anchor handling · 3 rig moves"))
        #expect(snap.previewValue(for: .dp) == "\(LogBookStats.entriesText(12)) · \(ExportSnapshot.hoursText(87.5))")
        #expect(snap.previewValue(for: .rov).contains(LogBookStats.hoursNumber(22)))
        #expect(snap.previewValue(for: .crane).contains(LogBookStats.hoursNumber(9.5)))
        books.crane = false
        books.rov = false
        let partial = snap.previewLines(for: books)
        #expect(partial.count == 2)
        #expect(partial.allSatisfy { !$0.hasPrefix("ROV") && !$0.hasPrefix("Crane") })
    }

    @Test func copySummaryIncludesDisclaimer() {
        let snap = ExportSnapshot(dpEntries: 1, dpHours: 2)
        let text = snap.copySummary(
            for: ExportBookSelection(dp: true, anchorHandling: false, rov: false, crane: false),
            dateFilter: ExportDateFilter(quickRange: .allTime, from: nil, to: nil)
        )
        #expect(text.contains(ExportDisclaimer.text))
        #expect(text.contains(ExportDisclaimer.previewFooter))
        #expect(text.contains("DP ·"))
    }
}

// MARK: - Test helpers (mutate optional hour fields)

private extension ROVEntry {
    func withPiloting(_ hours: Double) -> ROVEntry {
        pilotingHours = hours
        return self
    }
}

private extension CraneEntry {
    func withOperated(_ hours: Double) -> CraneEntry {
        hoursOperated = hours
        return self
    }
}
