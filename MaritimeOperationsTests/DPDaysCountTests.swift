import XCTest
import Foundation
@testable import MaritimeOperations

/// Port of the locked reference (13 Oct 2026): 21 known answers and 4 bad-input cases (25/25).
final class DPDaysCountTests: XCTestCase {
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!
    private let utc = TimeZone(identifier: "UTC")!
    private let asOf = DPDaysCount.Day(year: 2026, month: 10, day: 13)

    // MARK: - Known answers

    /// Reference: "2h00 counts"
    func testTwoHoursCounts() throws {
        let result = try count([watch(2026, 5, 1, 8, to: 2026, 5, 1, 10)])
        XCTAssertEqual(result.days, 1)
    }

    /// Reference: "1h59 no"
    func testOneHourFiftyNineDoesNotCount() throws {
        let result = try count([watch(2026, 5, 1, 8, to: 2026, 5, 1, 9, 59)])
        XCTAssertEqual(result.days, 0)
    }

    /// Reference: "two short watches sum"
    func testTwoShortWatchesSum() throws {
        let result = try count([
            watch(2026, 5, 1, 8, to: 2026, 5, 1, 9),
            watch(2026, 5, 1, 20, to: 2026, 5, 1, 21),
        ])
        XCTAssertEqual(result.days, 1)
    }

    /// Reference: "midnight split 1h+1h -> 0"
    func testMidnightSplitOnePlusOneIsZero() throws {
        let result = try count([watch(2026, 5, 1, 23, to: 2026, 5, 2, 1)])
        XCTAssertEqual(result.days, 0)
    }

    /// Reference: "midnight split 3h+3h -> 2"
    func testMidnightSplitThreePlusThreeIsTwo() throws {
        let result = try count([watch(2026, 5, 1, 21, to: 2026, 5, 2, 3)])
        XCTAssertEqual(result.days, 2)
    }

    /// Reference: "pre-2015 1h counts"
    func testPre2015OneHourCounts() throws {
        let result = try count(
            [watch(2014, 12, 31, 8, to: 2014, 12, 31, 9)],
            asOf: DPDaysCount.Day(year: 2019, month: 6, day: 1)
        )
        XCTAssertEqual(result.days, 1)
    }

    /// Reference: "2015-01-01 1h no"
    func testFirstOf2015OneHourDoesNotCount() throws {
        let result = try count(
            [watch(2015, 1, 1, 8, to: 2015, 1, 1, 9)],
            asOf: DPDaysCount.Day(year: 2019, month: 6, day: 1)
        )
        XCTAssertEqual(result.days, 0)
    }

    /// Reference: "ROV ignored"
    func testROVIgnored() throws {
        let result = try count([watch(2026, 5, 1, 8, to: 2026, 5, 1, 12, kind: "ROV")])
        XCTAssertEqual(result.days, 0)
    }

    /// Reference: "Crane not topping up DP"
    func testCraneDoesNotTopUpDP() throws {
        let result = try count([
            watch(2026, 5, 1, 8, to: 2026, 5, 1, 9),
            watch(2026, 5, 1, 10, to: 2026, 5, 1, 12, kind: "Crane"),
        ])
        XCTAssertEqual(result.days, 0)
    }

    /// Reference: "cutoff day excluded"
    func testCutoffDayExcluded() throws {
        let result = try count([watch(2021, 10, 13, 8, to: 2021, 10, 13, 12)])
        XCTAssertEqual(result.days, 0)
    }

    /// Reference: "day after cutoff included"
    func testDayAfterCutoffIncluded() throws {
        let result = try count([watch(2021, 10, 14, 8, to: 2021, 10, 14, 12)])
        XCTAssertEqual(result.days, 1)
    }

    /// Reference: "as_of day included"
    func testAsOfDayIncluded() throws {
        let result = try count([watch(2026, 10, 13, 0, to: 2026, 10, 13, 3)])
        XCTAssertEqual(result.days, 1)
    }

    /// Reference: "future day excluded"
    func testFutureDayExcluded() throws {
        let result = try count([watch(2026, 10, 14, 0, to: 2026, 10, 14, 3)])
        XCTAssertEqual(result.days, 0)
    }

    /// Reference: "cert later start"
    func testCertificateLaterStart() throws {
        let result = try count(
            [
                watch(2023, 3, 1, 8, to: 2023, 3, 1, 12),
                watch(2024, 3, 1, 8, to: 2024, 3, 1, 12),
            ],
            certificate: DPDaysCount.Day(year: 2023, month: 6, day: 1)
        )
        XCTAssertEqual(result.days, 1)
    }

    /// Reference: "cert issue day excluded"
    func testCertificateIssueDayExcluded() throws {
        let result = try count(
            [watch(2023, 6, 1, 8, to: 2023, 6, 1, 12)],
            certificate: DPDaysCount.Day(year: 2023, month: 6, day: 1)
        )
        XCTAssertEqual(result.days, 0)
    }

    /// Reference: "old cert ignored"
    func testOldCertificateIgnored() throws {
        let result = try count(
            [watch(2022, 3, 1, 8, to: 2022, 3, 1, 12)],
            certificate: DPDaysCount.Day(year: 2015, month: 1, day: 1)
        )
        XCTAssertEqual(result.days, 1)
    }

    /// Reference: "leap as_of"
    func testLeapAsOfWindowStart() throws {
        let result = try count([], asOf: DPDaysCount.Day(year: 2028, month: 2, day: 29))
        XCTAssertEqual(result.windowStart, DPDaysCount.Day(year: 2023, month: 2, day: 28))
    }

    /// Reference: "tz: UTC 23:00 is next day Shanghai"
    func testUTCEveningIsNextDayInShanghai() throws {
        let start = moment(2026, 5, 1, 23, timeZone: utc)
        let end = moment(2026, 5, 2, 2, timeZone: utc)
        let result = try count([DPDaysCount.Watch(start: start, end: end, dpClass: "DP2", kind: "DP")])
        XCTAssertEqual(result.days, 1)
    }

    /// Reference: "class by majority"
    func testClassByMajority() throws {
        let result = try count([
            watch(2026, 5, 1, 0, to: 2026, 5, 1, 3, dpClass: "DP3"),
            watch(2026, 5, 1, 4, to: 2026, 5, 1, 5, dpClass: "DP2"),
        ])
        XCTAssertEqual(result.byClass, ["DP3": 1])
    }

    /// Reference: "class tie -> higher"
    func testClassTieGoesToHigher() throws {
        let result = try count([
            watch(2026, 5, 1, 0, to: 2026, 5, 1, 2, dpClass: "DP1"),
            watch(2026, 5, 1, 4, to: 2026, 5, 1, 6, dpClass: "DP2"),
        ])
        XCTAssertEqual(result.byClass, ["DP2": 1])
    }

    /// Reference: "no target -> None"
    func testNoTargetStaysNil() throws {
        let result = try count([], target: nil)
        XCTAssertNil(result.target)
    }

    // MARK: - Bad input (the reference's four ValueError cases)

    /// Reference: "end<=start"
    func testEndNotAfterStartThrows() {
        let start = moment(2026, 5, 1, 9, timeZone: shanghai)
        assertFailure(.endNotAfterStart) {
            try self.count([DPDaysCount.Watch(start: start, end: start, dpClass: "DP2", kind: "DP")])
        }
    }

    /// Reference: "naive dt"
    func testNaiveDateTimeThrows() {
        let start = DPDaysCount.Moment(instant: Date(timeIntervalSince1970: 0), hasTimeZone: false)
        let end = DPDaysCount.Moment(instant: Date(timeIntervalSince1970: 7_200), hasTimeZone: false)
        assertFailure(.naiveDateTime) {
            try self.count([DPDaysCount.Watch(start: start, end: end, dpClass: "DP2", kind: "DP")])
        }
    }

    /// Reference: "bad class"
    func testBadClassThrows() {
        assertFailure(.badDPClass) {
            try self.count([self.watch(2026, 5, 1, 8, to: 2026, 5, 1, 10, dpClass: "DP9")])
        }
    }

    /// Reference: "target 0". Non-positive targets are the same rejection (Swift has no non-Int target).
    func testTargetZeroThrows() {
        assertFailure(.badTarget) {
            try self.count([], target: 0)
        }
        assertFailure(.badTarget) {
            try self.count([], target: -1)
        }
    }

    // MARK: - Card copy and the day-after window line

    func testWindowLineMatchesTheMockDates() throws {
        let result = try count([])
        XCTAssertEqual(
            DPDaysCount.windowLine(windowStart: result.windowStart, windowEnd: result.windowEnd, timeZone: shanghai),
            "Window: 14 Oct 2021 – 13 Oct 2026"
        )
    }

    func testWindowLineStartsTheDayAfterTheIssueDate() throws {
        let result = try count([], certificate: DPDaysCount.Day(year: 2023, month: 6, day: 1))
        XCTAssertEqual(
            DPDaysCount.windowLine(windowStart: result.windowStart, windowEnd: result.windowEnd, timeZone: shanghai),
            "Window: 2 Jun 2023 – 13 Oct 2026"
        )
    }

    func testCardCopyDoesNotUseSchemeWords() {
        let copy = [
            DPDaysCount.caption,
            DPDaysCount.footer,
            DPDaysCount.settingsHint,
            DPDaysCount.voiceOverSummary(days: 87, target: 150),
            DPDaysCount.voiceOverSummary(days: 87, target: nil),
        ].joined(separator: "\n")
        XCTAssertEqual(DPDaysCount.caption, "Rolling 5 years · days with 2 h or more on the DP desk")
        XCTAssertEqual(DPDaysCount.footer, "ROV and Crane hours are not counted.")
        XCTAssertEqual(DPDaysCount.settingsHint, "Set a target in Settings to see progress ›")
        XCTAssertEqual(DPDaysCount.voiceOverSummary(days: 87, target: 150), "DP days, 87 of 150, rolling 5 years")
        XCTAssertEqual(DPDaysCount.voiceOverSummary(days: 87, target: nil), "DP days, 87 days, rolling 5 years")
        for word in ["elig" + "ible", "certif" + "ied", "verif" + "ied"] {
            XCTAssertFalse(copy.localizedCaseInsensitiveContains(word))
        }
    }

    func testProgressFractionCapsAtFull() throws {
        let under = try count([watch(2026, 5, 1, 8, to: 2026, 5, 1, 10)], target: 150)
        XCTAssertEqual(under.progressFraction ?? -1, 1.0 / 150.0, accuracy: 0.000_001)
        var over = under
        over.days = 400
        over.target = 150
        XCTAssertEqual(over.progressFraction ?? -1, 1, accuracy: 0.000_001)
        let open = try count([], target: nil)
        XCTAssertNil(open.progressFraction)
    }

    func testMixedClassMinutesSumTowardTwoHours() throws {
        let result = try count([
            watch(2026, 5, 1, 8, to: 2026, 5, 1, 9, 30, dpClass: "DP2"),
            watch(2026, 5, 1, 18, to: 2026, 5, 1, 18, 30, dpClass: "DP3"),
        ])
        XCTAssertEqual(result.days, 1)
        XCTAssertEqual(result.byClass, ["DP2": 1])
        XCTAssertEqual(result.classPills.map(\.level), [2])
        XCTAssertEqual(result.classPills.map(\.days), [1])
    }

    func testAdapterSkipsUnclassifiedAndNonPositiveLines() {
        let zone = shanghai
        let start = moment(2026, 5, 1, 8, timeZone: zone).instant
        let end = moment(2026, 5, 1, 12, timeZone: zone).instant
        let counted = DPDaysCount.LogInterval(
            start: start, end: end, date: start, durationHours: 4, dpClassLevel: 2, dpClassText: ""
        )
        let noClass = DPDaysCount.LogInterval(
            start: start, end: end, date: start, durationHours: 4, dpClassLevel: nil, dpClassText: ""
        )
        let backwards = DPDaysCount.LogInterval(
            start: end, end: start, date: start, durationHours: 4, dpClassLevel: 3, dpClassText: ""
        )
        let nextStart = moment(2026, 5, 2, 8, timeZone: zone).instant
        let nextEnd = moment(2026, 5, 2, 12, timeZone: zone).instant
        let legacy = DPDaysCount.LogInterval(
            start: nextStart, end: nextEnd, date: nextStart, durationHours: 4,
            dpClassLevel: nil, dpClassText: "Class 1 (old text)"
        )
        XCTAssertNil(DPDaysCount.watch(from: noClass))
        XCTAssertNil(DPDaysCount.watch(from: backwards))
        let result = DPDaysCount.count(
            intervals: [counted, noClass, backwards, legacy],
            asOf: moment(2026, 10, 13, 12, timeZone: zone).instant,
            timeZone: zone,
            target: 150,
            certificateIssued: nil
        )
        XCTAssertEqual(result.days, 2)
        XCTAssertEqual(result.byClass, ["DP1": 1, "DP2": 1])
    }

    func testClearedTargetAndIssueDateParsing() {
        XCTAssertEqual(DPDaysSettings.parsedTarget("150"), 150)
        XCTAssertEqual(DPDaysSettings.parsedTarget(" 150 "), 150)
        XCTAssertNil(DPDaysSettings.parsedTarget(""))
        XCTAssertNil(DPDaysSettings.parsedTarget("0"))
        XCTAssertNil(DPDaysSettings.parsedTarget("-3"))
        XCTAssertEqual(
            DPDaysSettings.parsedCertificate("2023-06-01"),
            DPDaysCount.Day(year: 2023, month: 6, day: 1)
        )
        XCTAssertNil(DPDaysSettings.parsedCertificate(""))
        XCTAssertNil(DPDaysSettings.parsedCertificate("2023-02-31"))
    }

    // MARK: - Helpers

    private func count(
        _ watches: [DPDaysCount.Watch],
        asOf: DPDaysCount.Day? = nil,
        target: Int? = 150,
        certificate: DPDaysCount.Day? = nil
    ) throws -> DPDaysCount.Result {
        try DPDaysCount.dpDays(
            watches: watches,
            asOf: asOf ?? self.asOf,
            timeZone: shanghai,
            target: target,
            certificateIssued: certificate
        )
    }

    private func watch(
        _ y1: Int, _ m1: Int, _ d1: Int, _ h1: Int,
        to y2: Int, _ m2: Int, _ d2: Int, _ h2: Int, _ min2: Int = 0,
        dpClass: String = "DP2",
        kind: String = "DP"
    ) -> DPDaysCount.Watch {
        DPDaysCount.Watch(
            start: moment(y1, m1, d1, h1, timeZone: shanghai),
            end: moment(y2, m2, d2, h2, minute: min2, timeZone: shanghai),
            dpClass: dpClass,
            kind: kind
        )
    }

    private func moment(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int,
        minute: Int = 0,
        timeZone: TimeZone
    ) -> DPDaysCount.Moment {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
        return DPDaysCount.Moment(instant: date, hasTimeZone: true)
    }

    private func assertFailure(
        _ expected: DPDaysCount.Failure,
        _ body: () throws -> DPDaysCount.Result,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as DPDaysCount.Failure {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}
