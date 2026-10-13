import XCTest
import Foundation
import SwiftData
@testable import MaritimeOperations

/// Vessel and DP class only, from the latest DP line. The draft is a copy.
final class DPStartPrefillTests: XCTestCase {
    func testLatestDateWinsAndDoesNotCarryTheRest() {
        let older = candidate("Old Ship", level: 1, text: "", day: 1, created: 20)
        let latest = candidate("Seven Falcon", level: 2, text: "Class 9", day: 10, created: 2)
        var source = [older, latest]
        let snapshot = source
        var draft = DPStartPrefill.make(from: source)
        XCTAssertEqual(draft.vessel, "Seven Falcon")
        XCTAssertEqual(draft.dpClassLevel, 2)
        XCTAssertTrue(draft.hasPreviousEntry)
        draft.vessel = "Island Constructor"
        draft.dpClassLevel = 3
        XCTAssertEqual(source, snapshot)
        XCTAssertEqual(draft.vessel, "Island Constructor")
        XCTAssertEqual(draft.dpClassLevel, 3)
    }

    func testSameDateUsesLaterCreatedLine() {
        let first = candidate("Alpha", level: 1, text: "", day: 5, created: 1)
        let second = candidate("Beta", level: 3, text: "", day: 5, created: 4)
        let draft = DPStartPrefill.make(from: [first, second])
        XCTAssertEqual(draft.vessel, "Beta")
        XCTAssertEqual(draft.dpClassLevel, 3)
    }

    func testEmptyLatestVesselDoesNotFallThrough() {
        let older = candidate("Seven Falcon", level: 2, text: "", day: 1, created: 1)
        let latest = candidate("  ", level: nil, text: "", day: 8, created: 2)
        let draft = DPStartPrefill.make(from: [older, latest])
        XCTAssertEqual(draft.vessel, "")
        XCTAssertNil(draft.dpClassLevel)
        XCTAssertTrue(draft.hasPreviousEntry)
    }

    func testNoEntries() {
        let draft = DPStartPrefill.make(from: [DPStartPrefill.Candidate]())
        XCTAssertFalse(draft.hasPreviousEntry)
        XCTAssertEqual(draft.vessel, "")
        XCTAssertNil(draft.dpClassLevel)
    }

    func testPlaceholderVesselAndLegacyClassText() {
        let draft = DPStartPrefill.make(from: [
            candidate(" Vessel ", level: nil, text: "Class 1 (old text)", day: 3, created: 3)
        ])
        XCTAssertEqual(draft.vessel, "")
        XCTAssertEqual(draft.dpClassLevel, 1)
        XCTAssertTrue(draft.hasPreviousEntry)
    }

    func testPrefillCopy() {
        XCTAssertEqual(DPStartPrefill.title, "START DP · NEW WATCH")
        XCTAssertEqual(DPStartPrefill.fromLastEntry, "From your last entry")
        XCTAssertEqual(DPStartPrefill.noPreviousEntry, "No previous entry")
        XCTAssertEqual(DPStartPrefill.addVessel, "Add vessel")
        XCTAssertEqual(DPStartPrefill.chooseClass, "Choose DP class")
    }

    @MainActor
    func testSavingTheNewWatchDoesNotChangeThePreviousEntry() throws {
        let schema = Schema([DPEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let original = DPEntry(
            source: .manual,
            date: started,
            startTime: started,
            endTime: started.addingTimeInterval(3 * 3600),
            durationHours: 3,
            vessel: "Seven Falcon",
            dpClass: "Class 2",
            activityCode: "kept-activity",
            notes: "keep me",
            dpClassLevel: 2,
            createdAt: started
        )
        context.insert(original)
        try context.save()

        var draft = DPStartPrefill.make(from: [original])
        draft.vessel = "Island Constructor"
        draft.dpClassLevel = 3

        let newStart = Date(timeIntervalSince1970: 1_800_000_000)
        let newEntry = DPEntry(
            source: .timed,
            date: newStart,
            startTime: newStart,
            endTime: newStart.addingTimeInterval(3600),
            durationHours: 1,
            vessel: draft.vessel,
            dpClass: "Class \(draft.dpClassLevel ?? 0)",
            dpClassLevel: draft.dpClassLevel,
            createdAt: newStart
        )
        context.insert(newEntry)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<DPEntry>())
        let previous = try XCTUnwrap(stored.first { $0.id == original.id })
        let savedNew = try XCTUnwrap(stored.first { $0.id == newEntry.id })
        XCTAssertEqual(previous.vessel, "Seven Falcon")
        XCTAssertEqual(previous.dpClassLevel, 2)
        XCTAssertEqual(previous.notes, "keep me")
        XCTAssertEqual(previous.activityCode, "kept-activity")
        XCTAssertEqual(previous.durationHours, 3)
        XCTAssertEqual(previous.startTime, started)
        XCTAssertEqual(savedNew.vessel, "Island Constructor")
        XCTAssertEqual(savedNew.dpClassLevel, 3)
        XCTAssertNil(savedNew.notes)
        XCTAssertNil(savedNew.activityCode)
        XCTAssertEqual(savedNew.startTime, newStart)
        XCTAssertNotEqual(savedNew.startTime, previous.startTime)
    }

    private func candidate(
        _ vessel: String,
        level: Int?,
        text: String,
        day: Int,
        created: Int
    ) -> DPStartPrefill.Candidate {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return DPStartPrefill.Candidate(
            vessel: vessel,
            dpClassLevel: level,
            dpClassText: text,
            date: base.addingTimeInterval(Double(day) * 86_400),
            createdAt: base.addingTimeInterval(Double(created) * 86_400)
        )
    }
}
