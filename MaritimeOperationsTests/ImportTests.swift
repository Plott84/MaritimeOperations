import Testing
import Foundation
import SwiftData
@testable import MaritimeOperations

/// Import: CSV/PDF parse, merge, replace scope, and the gates that keep a bad file from writing.
struct ImportTests {
    private let cal: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Copy

    @Test func disclaimerAndCaptionMatchExport() {
        #expect(
            ExportDisclaimer.text
                == "Personal aid only. This export is not an official IMCA DP Logbook record, and it is not a sign-off or certificate."
        )
        #expect(ExportDisclaimer.booksCaption == "ROV and Crane hours are never added to DP totals.")
        #expect(ImportCopy.inlineError == "Couldn\u{2019}t read this file")
        #expect(ImportCopy.emptyPreview == "Choose a file to preview books and entry counts.")
        #expect(ImportCopy.replaceWarning == "Replace will overwrite books that are in this file. Other books are left alone.")
        #expect(ImportCopy.mergeHelper == "Adds entries from the file. Exact duplicates are skipped.")
    }

    @Test func everyReadErrorUsesTheSameInlineMessage() {
        let cases: [ImportReadError] = [
            .unsupportedType, .notMaritimeExport, .legacySummaryOnly, .countMismatch, .duplicateIdentity
        ]
        for error in cases {
            #expect(error.inlineMessage == ImportCopy.inlineError)
        }
    }

    // MARK: - Gates (IM-01, IM-05, IM-08, IM-11)

    @Test func noFileCannotImportAndMergeIsTheDefault() {
        let session = ImportSession()
        #expect(session.source == .empty)
        #expect(session.mode == .merge)
        #expect(!session.canImport)
        #expect(session.inlineError == nil)
        #expect(!ImportWriteGate.shouldWrite(canImport: session.canImport, mode: session.mode, replaceConfirmed: false))
        #expect(!ImportWriteGate.shouldWrite(canImport: session.canImport, mode: .replaceBooks, replaceConfirmed: true))
    }

    @Test func invalidFileStaysDisabledAndResetsToMerge() {
        var session = ImportSession()
        session.mode = .replaceBooks
        session.receiveFile(name: "random.pdf", data: Data("%PDF-1.4\n%%EOF\n".utf8))
        #expect(!session.canImport)
        #expect(session.mode == .merge)
        #expect(session.inlineError == ImportCopy.inlineError)
        #expect(session.payload == nil)
        #expect(!ImportWriteGate.shouldWrite(canImport: session.canImport, mode: .replaceBooks, replaceConfirmed: true))
    }

    @Test func replaceWritesOnlyAfterConfirmAndCancelDoesNot() {
        #expect(!ImportWriteGate.shouldWrite(canImport: true, mode: .replaceBooks, replaceConfirmed: false))
        #expect(ImportWriteGate.shouldWrite(canImport: true, mode: .replaceBooks, replaceConfirmed: true))
        #expect(ImportWriteGate.shouldWrite(canImport: true, mode: .merge, replaceConfirmed: false))
        #expect(!ImportWriteGate.shouldWrite(canImport: false, mode: .merge, replaceConfirmed: true))
    }

    @Test func choosingAValidFileEnablesImportAndSelectsMerge() throws {
        let entry = DPEntry(source: .manual, date: day(2026, 6, 1), durationHours: 4, vessel: "North")
        let csv = try encode(dp: [entry])
        var session = ImportSession()
        session.mode = .replaceBooks
        session.receiveFile(name: "MaritimeOperations-Export.csv", data: Data(csv.utf8))
        #expect(session.canImport)
        #expect(session.mode == .merge)
        #expect(session.payload?.dp.count == 1)
        #expect(session.inlineError == nil)
        #expect(ImportWriteGate.shouldWrite(canImport: session.canImport, mode: session.mode, replaceConfirmed: false))
    }

    // MARK: - Parse

    @Test func disclaimerCommaStaysInsideOneField() throws {
        let rows = try ImportExchange.csvRows("disclaimer,\"\(ExportDisclaimer.text)\"\n")
        #expect(rows == [["disclaimer", ExportDisclaimer.text]])
    }

    @Test func unterminatedQuoteIsRejected() {
        expectError(.notMaritimeExport) {
            _ = try ImportExchange.csvRows("\"abc")
        }
    }

    @Test func summaryHeaderAndRecordsRoundTripWithoutMixingDPHours() throws {
        let dp = DPEntry(source: .manual, date: day(2026, 6, 1), durationHours: 10, vessel: "DP boat")
        let rov = ROVEntry(date: day(2026, 6, 2), vessel: "ROV boat")
        rov.pilotingHours = 50
        let csv = try encode(dp: [dp], rov: [rov])

        #expect(csv.hasPrefix("book,count,hours,notes\n"))
        #expect(csv.contains("\"DP\",1,10.0,\"DP book only; ROV/Crane excluded\""))
        #expect(csv.contains("\"ROV\",1,50.0,\"piloting hours\""))
        #expect(csv.contains("section,records,1"))
        #expect(csv.contains("disclaimer,\"\(ExportDisclaimer.text)\""))

        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "export.csv")
        let snapshot = payload.exportSnapshot()
        #expect(snapshot.dpHours == 10)
        #expect(snapshot.rovHours == 50)
        #expect(snapshot.dpHours != snapshot.dpHours + snapshot.rovHours)
        #expect(payload.previewLines() == payload.exportSnapshot().previewLines(for: selection(payload.booksPresent)))
    }

    @Test func previewUsesRigMovesAndOmitsBooksThatAreNotInTheFile() throws {
        var hours = Array(repeating: 7.0, count: 11)
        hours.append(10.5)
        let dp = hours.map { value in
            DPEntry(source: .manual, date: day(2026, 6, 1), durationHours: value, vessel: "DP")
        }
        let moves = (0..<3).map { RigMove(rigName: "Rig \($0)", date: day(2026, 6, 2)) }
        let rov = (0..<4).map { _ -> ROVEntry in
            let entry = ROVEntry(date: day(2026, 6, 3), vessel: "ROV")
            entry.pilotingHours = 5.5
            return entry
        }
        let craneEntries = [
            crane(hours: 6),
            crane(hours: 3.5)
        ]
        let csv = try encode(dp: dp, moves: moves, rov: rov, crane: craneEntries)
        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "EXPORT.CSV")
        let snapshot = payload.exportSnapshot()
        #expect(snapshot.dpEntries == 12)
        #expect(snapshot.dpHours == 87.5)
        #expect(snapshot.rigMoves == 3)
        #expect(snapshot.rovEntries == 4)
        #expect(snapshot.rovHours == 22)
        #expect(snapshot.craneEntries == 2)
        #expect(snapshot.craneHours == 9.5)
        #expect(payload.previewLines().contains("Anchor handling · 3 rig moves"))
        #expect(payload.previewLines() == [
            snapshot.previewLine(for: .dp),
            snapshot.previewLine(for: .anchorHandling),
            snapshot.previewLine(for: .rov),
            snapshot.previewLine(for: .crane)
        ])

        let partialBooks = ExportBookSelection(dp: true, anchorHandling: false, rov: false, crane: false)
        let partial = try encode(books: partialBooks, dp: dp, moves: moves, rov: rov, crane: craneEntries)
        let partialPayload = try ImportExchange.parse(data: Data(partial.utf8), filename: "partial.csv")
        #expect(partialPayload.booksPresent == [.dp])
        #expect(partialPayload.moves.isEmpty)
        #expect(partialPayload.rov.isEmpty)
        #expect(partialPayload.crane.isEmpty)
        #expect(partialPayload.exportSnapshot().dpHours == 87.5)
    }

    @Test func rejectsLegacySummaryUnknownTypesAndCorruptCounts() throws {
        let entry = DPEntry(source: .manual, date: day(2026, 6, 1), durationHours: 2, vessel: "A")
        let csv = try encode(dp: [entry])

        let legacy = String(csv[..<csv.range(of: "section,records,1")!.lowerBound])
        expectError(.legacySummaryOnly) {
            _ = try ImportExchange.parse(data: Data(legacy.utf8), filename: "MaritimeOperations-Export-old.csv")
        }
        expectError(.unsupportedType) {
            _ = try ImportExchange.parse(data: Data(csv.utf8), filename: "notes.txt")
        }
        expectError(.notMaritimeExport) {
            _ = try ImportExchange.parse(data: Data("%PDF-1.4\n%%EOF\n".utf8), filename: "scan.pdf")
        }
        expectError(.notMaritimeExport) {
            _ = try ImportExchange.parse(data: Data("hello\n".utf8), filename: "notes.csv")
        }

        var mismatched = csv
        let summary = "\"DP\",1,"
        let range = mismatched.range(of: summary)!
        mismatched.replaceSubrange(range, with: "\"DP\",9,")
        expectError(.countMismatch) {
            _ = try ImportExchange.parse(data: Data(mismatched.utf8), filename: "bad.csv")
        }

        let rewritten = csv.replacingOccurrences(of: "Personal aid only", with: "Personal note only")
        expectError(.notMaritimeExport) {
            _ = try ImportExchange.parse(data: Data(rewritten.utf8), filename: "bad.csv")
        }

        let duplicate = DPEntry(id: entry.id, source: .manual, date: day(2026, 6, 1), durationHours: 2, vessel: "A")
        let dupCSV = try encode(dp: [entry, duplicate])
        expectError(.duplicateIdentity) {
            _ = try ImportExchange.parse(data: Data(dupCSV.utf8), filename: "dup.csv")
        }

        var bom = Data([0xEF, 0xBB, 0xBF])
        bom.append(Data(csv.utf8))
        let withBOM = try ImportExchange.parse(data: bom, filename: "export.csv")
        #expect(withBOM.dp.map(\.id) == [entry.id])
    }

    @Test func pdfTrailerRoundTripsAndLeavesTheDrawnBytesInPlace() throws {
        let entry = DPEntry(source: .manual, date: day(2026, 6, 1), durationHours: 3, vessel: "PDF")
        let csv = try encode(dp: [entry])
        let drawn = Data("%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF".utf8)
        let file = ImportExchange.embedCSV(csv, in: drawn)
        #expect(file.starts(with: drawn))
        let payload = try ImportExchange.parse(data: file, filename: "MaritimeOperations-Export.PDF")
        #expect(payload.dp.map(\.id) == [entry.id])
        #expect(payload.dp.first?.vessel == "PDF")

        expectError(.notMaritimeExport) {
            _ = try ImportExchange.parse(data: drawn, filename: "MaritimeOps-Export-2026-10-12.pdf")
        }
    }

    @Test func dateFilterAndUnselectedBooksStayOutOfTheFile() throws {
        let inside = DPEntry(source: .manual, date: day(2026, 6, 1), durationHours: 4, vessel: "In")
        let outside = DPEntry(source: .manual, date: day(2025, 12, 1), durationHours: 99, vessel: "Out")
        let rov = ROVEntry(date: day(2026, 6, 1), vessel: "Hidden")
        rov.pilotingHours = 40
        let filter = ExportDateFilter.applied(.thisYear, earliestEntry: nil, now: day(2026, 10, 12), calendar: cal)
        let books = ExportBookSelection(dp: true, anchorHandling: false, rov: false, crane: false)
        let csv = try encode(books: books, filter: filter, dp: [inside, outside], rov: [rov], calendar: cal)
        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "year.csv")
        #expect(payload.booksPresent == [.dp])
        #expect(payload.dp.map(\.id) == [inside.id])
        #expect(payload.rov.isEmpty)
        #expect(payload.exportSnapshot().dpHours == 4)
    }

    @Test func recordsRoundTripEveryStoredField() throws {
        let start = Date(timeIntervalSince1970: 1_780_000_000.125)
        let end = Date(timeIntervalSince1970: 1_780_003_600.5)
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let updated = Date(timeIntervalSince1970: 1_700_000_100.25)

        let dp = DPEntry(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            source: .timed,
            date: start,
            startTime: start,
            endTime: end,
            durationHours: 4.25,
            vessel: "Island Constructor",
            rig: "Troll A",
            vesselType: "PSV",
            dpClass: "Class 2",
            mode: "Auto",
            activityCode: "DP",
            notes: "line1\n\"quoted\", tail",
            masterInitials: "HO",
            locationName: "Troll field",
            client: "Equinor",
            locationFromPhone: true,
            latitudeText: "60 10.5 N",
            longitudeText: "3 30.0 E",
            dpClassLevel: 2,
            rank: "chiefOfficer",
            createdAt: created,
            updatedAt: updated
        )
        dp.sourceRaw = "deck-watch"

        let move = RigMove(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            rigName: "Deepsea Atlantic",
            date: start,
            startTime: start,
            endTime: end,
            operation: .project,
            notes: "move, notes",
            isDone: true,
            createdAt: created,
            client: "Client",
            fromLocation: "Bergen",
            toLocation: "Troll",
            vessel: "AH vessel",
            rank: "mate",
            projectText: "Pre-lay",
            anchorLineCount: 8,
            hasChain: true,
            hasWire: false,
            hasFiber: true,
            hasSubBuoys: false,
            hasOther: true,
            otherEquipment: "Grapnel"
        )
        move.operationRaw = "CustomOp"
        move.ahJobTypeRaw = "preLay"
        move.ahUnderTraining = true
        move.ahUnitTypeRaw = "semiSubmersible"
        move.ahFieldArea = "Troll"
        move.ahTasksRaw = "recoverAnchor|runAnchor"
        move.ahControlModeRaw = "dp"
        move.ahSupervised = false
        move.ahAnchorIDs = "1, 2"
        move.ahWaterDepthM = 120.5
        move.ahMaxPaidOutM = 800
        move.ahPeakTensionT = 40.25
        move.ahWaveHeightM = 2.5
        move.ahWindKn = 18
        move.ahWindDirection = "NW"
        move.photoJPEG = Data([1, 2, 3, 4])

        let rov = ROVEntry(id: UUID(), date: start, endTime: end, vessel: "ROV vessel", createdAt: created)
        rov.gradeRaw = "supervisor"
        rov.gradeOther = nil
        rov.underTraining = false
        rov.rovSystem = "TRITON"
        rov.rovClassRaw = "III"
        rov.fieldArea = "Troll"
        rov.jobTypeRaw = "construction"
        rov.tasksRaw = "piloting|tms"
        rov.pilotingHours = 5.5
        rov.dives = 3
        rov.supportSiteRaw = "other"
        rov.supportSiteOther = "Barge"
        rov.remarks = "calm"
        rov.updatedAt = updated

        let craneEntry = CraneEntry(id: UUID(), date: start, endTime: end, vessel: "Crane vessel", createdAt: created)
        craneEntry.rank = "craneOperator"
        craneEntry.underTraining = true
        craneEntry.craneName = "Knuckle 1"
        craneEntry.craneTypeRaw = "other"
        craneEntry.craneTypeOther = "Module crane"
        craneEntry.fieldArea = "Oseberg"
        craneEntry.hoursOperated = 9.5
        craneEntry.liftTypesRaw = "deck|supply"
        craneEntry.dayNightRaw = "night"
        craneEntry.windMS = 12.25
        craneEntry.waveHeightM = 2.5
        craneEntry.craneModeRaw = "harbour"
        craneEntry.remarks = "night shift"
        craneEntry.updatedAt = updated

        let dpRecord = DPRecord(dp)
        #expect(dpRecord.sourceRaw == "deck-watch")
        #expect(dpRecord.notes == "line1\n\"quoted\", tail")
        #expect(dpRecord.locationFromPhone)
        #expect(dpRecord.dpClassLevel == 2)
        #expect(dpRecord.latitudeText == "60 10.5 N")
        #expect(dpRecord.updatedAt == updated)

        let moveRecord = RigMoveRecord(move)
        #expect(moveRecord.operationRaw == "CustomOp")
        #expect(moveRecord.ahTasksRaw == "recoverAnchor|runAnchor")
        #expect(moveRecord.ahPeakTensionT == 40.25)
        #expect(moveRecord.otherEquipment == "Grapnel")
        #expect(moveRecord.workedHours == RigMoveCheck.workedHours(start: start, finish: end))

        let csv = try encode(dp: [dp], moves: [move], rov: [rov], crane: [craneEntry])
        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "full.csv")
        #expect(payload.dp == [dpRecord])
        #expect(payload.moves == [moveRecord])
        #expect(payload.rov == [ROVRecord(rov)])
        #expect(payload.crane == [CraneRecord(craneEntry)])
        #expect(DPRecord(payload.dp[0].makeModel()) == dpRecord)
        #expect(RigMoveRecord(payload.moves[0].makeModel()) == moveRecord)
        #expect(payload.moves[0].makeModel().photoJPEG == nil)
        #expect(ROVRecord(payload.rov[0].makeModel()) == ROVRecord(rov))
        #expect(CraneRecord(payload.crane[0].makeModel()) == CraneRecord(craneEntry))
    }

    // MARK: - Merge and replace

    @Test func mergeSkipsSameIdAndLeavesOtherBooksAlone() throws {
        let keptID = UUID()
        let old = DPEntry(id: keptID, source: .manual, date: day(2026, 1, 2), durationHours: 1, vessel: "Old")
        old.notes = "old notes"
        let replacement = DPEntry(id: keptID, source: .manual, date: day(2026, 1, 2), durationHours: 8, vessel: "New")
        replacement.notes = "new notes"
        let added = DPEntry(source: .manual, date: day(2026, 1, 3), durationHours: 2, vessel: "Added")
        let craneAdded = crane(hours: 3)
        let keptROV = ROVEntry(date: day(2026, 1, 1), vessel: "Stay")
        keptROV.pilotingHours = 11

        let books = ExportBookSelection(dp: true, anchorHandling: false, rov: false, crane: true)
        let csv = try encode(books: books, dp: [replacement, added], crane: [craneAdded])
        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "merge.csv")
        let existing = ImportLibrary(dp: [DPRecord(old)], rov: [ROVRecord(keptROV)])
        let plan = ImportPlanner.plan(mode: .merge, existing: existing, payload: payload)
        let result = existing.applying(plan)

        #expect(result.rov == existing.rov)
        #expect(result.rov.first?.pilotingHours == 11)
        #expect(result.dp.first { $0.id == keptID }?.notes == "old notes")
        #expect(result.dp.contains { $0.id == added.id })
        #expect(result.crane.map(\.id) == [craneAdded.id])
        #expect(plan.deleteDP.isEmpty)
        #expect(plan.deleteROV.isEmpty)
        #expect(plan.report.added == 2)
        #expect(plan.report.skippedDuplicates == 1)
        #expect(plan.report.booksChanged == [.dp, .crane])
        #expect(plan.report.logPath == [])
        #expect(plan.report.toastText == "Added 2 entries. Skipped 1 duplicate.")
        #expect(result.exportHours().dp == existing.exportHours().dp + added.durationHours)
        #expect(result.exportHours().dp != result.exportHours().dp + result.exportHours().crane)
    }

    @Test func replaceOverwritesOnlyBooksInTheFile() throws {
        let oldDP = DPEntry(source: .manual, date: day(2026, 3, 1), durationHours: 6, vessel: "Old DP")
        let newDP = DPEntry(source: .manual, date: day(2026, 3, 2), durationHours: 1.5, vessel: "File DP")
        let oldMove = RigMove(rigName: "Old rig", date: day(2026, 3, 1))
        let newMove = RigMove(rigName: "File rig", date: day(2026, 3, 2))
        let rov = ROVEntry(date: day(2026, 3, 1), vessel: "Keep ROV")
        rov.pilotingHours = 14
        let keptCrane = crane(hours: 4, name: "Keep crane")

        let books = ExportBookSelection(dp: true, anchorHandling: true, rov: false, crane: false)
        let csv = try encode(books: books, dp: [newDP], moves: [newMove])
        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "replace.csv")
        let existing = ImportLibrary(
            dp: [DPRecord(oldDP)],
            moves: [RigMoveRecord(oldMove)],
            rov: [ROVRecord(rov)],
            crane: [CraneRecord(keptCrane)]
        )
        let plan = ImportPlanner.plan(mode: .replaceBooks, existing: existing, payload: payload)
        let result = existing.applying(plan)

        #expect(result.dp.map(\.id) == [newDP.id])
        #expect(result.dp.first?.vessel == "File DP")
        #expect(result.moves.map(\.id) == [newMove.id])
        #expect(result.rov == existing.rov)
        #expect(result.crane == existing.crane)
        #expect(plan.deleteROV.isEmpty)
        #expect(plan.deleteCrane.isEmpty)
        #expect(plan.deleteDP == [oldDP.id])
        #expect(plan.report.skippedDuplicates == 0)
        #expect(plan.report.booksChanged == [.dp, .anchorHandling])
        #expect(plan.report.added == 2)
        #expect(plan.report.toastText == "Replaced DP, Anchor handling. 2 entries.")
        #expect(result.exportHours().rov == 14)
        #expect(result.exportHours().dp == 1.5)
    }

    @Test func replaceClearsASelectedBookThatHasNoRowsAndKeepsTheOthers() throws {
        let oldDP = DPEntry(source: .manual, date: day(2026, 4, 1), durationHours: 3, vessel: "Gone")
        let kept = crane(hours: 2, name: "Stay")
        let books = ExportBookSelection(dp: true, anchorHandling: false, rov: false, crane: false)
        let csv = try encode(books: books, dp: [])
        #expect(csv.contains("\"DP\",0,0.0,\"DP book only; ROV/Crane excluded\""))
        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "empty-dp.csv")
        #expect(payload.booksPresent == [.dp])
        let existing = ImportLibrary(dp: [DPRecord(oldDP)], crane: [CraneRecord(kept)])
        let result = existing.applying(ImportPlanner.plan(mode: .replaceBooks, existing: existing, payload: payload))
        #expect(result.dp.isEmpty)
        #expect(result.crane == existing.crane)
        let oneBook = ImportPlanner.plan(mode: .replaceBooks, existing: existing, payload: payload).report
        #expect(oneBook.logPath == [.dp])
        #expect(oneBook.toastText == "Replaced DP. 0 entries.")
    }

    @Test func reportCopyForSingleAndEmptyResults() {
        #expect(
            ImportReport(added: 1, skippedDuplicates: 0, booksChanged: [.rov], mode: .merge).toastText
                == "Added 1 entry."
        )
        #expect(
            ImportReport(added: 0, skippedDuplicates: 1, booksChanged: [], mode: .merge).toastText
                == "Added 0 entries. Skipped 1 duplicate."
        )
        #expect(ImportReport(added: 1, skippedDuplicates: 0, booksChanged: [.rov], mode: .merge).logPath == [.rov])
        #expect(
            ImportReport(added: 0, skippedDuplicates: 0, booksChanged: [], mode: .replaceBooks).toastText
                == "Replaced 0 books. 0 entries."
        )
    }

    @Test func securityScopedReadParsesALocalCSV() throws {
        let entry = DPEntry(source: .manual, date: day(2026, 8, 1), durationHours: 1, vessel: "Disk")
        let csv = try encode(dp: [entry])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-\(UUID().uuidString).csv")
        try Data(csv.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try ImportFileAccess.read(url: url)
        #expect(file.name == url.lastPathComponent)
        let payload = try ImportExchange.parse(data: file.data, filename: file.name)
        #expect(payload.dp.map(\.vessel) == ["Disk"])
    }

    // MARK: - Helpers

    private func encode(
        books: ExportBookSelection = ExportBookSelection(),
        filter: ExportDateFilter = ExportDateFilter(quickRange: .allTime, from: nil, to: nil),
        dp: [DPEntry] = [],
        moves: [RigMove] = [],
        rov: [ROVEntry] = [],
        crane: [CraneEntry] = [],
        calendar: Calendar? = nil
    ) throws -> String {
        try ImportExchange.encodeCSV(
            books: books,
            filter: filter,
            dp: dp,
            moves: moves,
            rov: rov,
            crane: crane,
            calendar: calendar ?? cal
        )
    }

    private func crane(hours: Double, name: String = "Crane") -> CraneEntry {
        let entry = CraneEntry(date: day(2026, 6, 4), vessel: "Crane vessel")
        entry.hoursOperated = hours
        entry.craneName = name
        return entry
    }

    private func selection(_ books: [LogBook]) -> ExportBookSelection {
        var booksOn = ExportBookSelection(dp: false, anchorHandling: false, rov: false, crane: false)
        for book in books {
            booksOn.set(book, on: true)
        }
        return booksOn
    }

    private func expectError(_ expected: ImportReadError, _ body: () throws -> Void) {
        do {
            try body()
            Issue.record("Expected \(expected)")
        } catch let error as ImportReadError {
            #expect(error == expected)
            #expect(error.inlineMessage == ImportCopy.inlineError)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
}

private extension ImportLibrary {
    func exportHours() -> (dp: Double, rov: Double, crane: Double) {
        let snapshot = ImportPayload(booksPresent: LogBook.allCases, dp: dp, moves: moves, rov: rov, crane: crane).exportSnapshot()
        return (snapshot.dpHours, snapshot.rovHours, snapshot.craneHours)
    }
}

/// SwiftData apply: replace must not delete books missing from the file, and rig-move photos stay.
@MainActor
struct ImportStoreTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([DPEntry.self, RigMove.self, ROVEntry.self, CraneEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test func replacePersistsOnlyTheBooksInTheFileAndKeepsTheRigPhoto() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let oldDP = DPEntry(source: .manual, date: .now, durationHours: 2, vessel: "Old")
        let rov = ROVEntry(date: .now, vessel: "Stay")
        rov.pilotingHours = 5
        let keptCrane = CraneEntry(date: .now, vessel: "Stay")
        keptCrane.craneName = "Main crane"
        keptCrane.hoursOperated = 1
        let moveID = UUID()
        let move = RigMove(id: moveID, rigName: "Old rig", date: .now)
        move.photoJPEG = Data([9, 8, 7, 6])
        context.insert(oldDP)
        context.insert(rov)
        context.insert(keptCrane)
        context.insert(move)
        try context.save()

        let newDP = DPEntry(source: .manual, date: .now, durationHours: 4, vessel: "From file")
        let rewritten = RigMove(id: moveID, rigName: "Rewritten", date: .now)
        let books = ExportBookSelection(dp: true, anchorHandling: true, rov: false, crane: false)
        let csv = try ImportExchange.encodeCSV(
            books: books,
            filter: ExportDateFilter(quickRange: .allTime, from: nil, to: nil),
            dp: [newDP],
            moves: [rewritten],
            rov: [],
            crane: []
        )
        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "store.csv")
        let report = try ImportStore.apply(mode: .replaceBooks, payload: payload, context: context)

        let dp = try context.fetch(FetchDescriptor<DPEntry>())
        let moves = try context.fetch(FetchDescriptor<RigMove>())
        let rovRows = try context.fetch(FetchDescriptor<ROVEntry>())
        let craneRows = try context.fetch(FetchDescriptor<CraneEntry>())

        #expect(dp.count == 1)
        #expect(dp.first?.id == newDP.id)
        #expect(dp.first?.vessel == "From file")
        #expect(moves.count == 1)
        #expect(moves.first?.id == moveID)
        #expect(moves.first?.rigName == "Rewritten")
        #expect(moves.first?.photoJPEG == Data([9, 8, 7, 6]))
        #expect(rovRows.map(\.id) == [rov.id])
        #expect(rovRows.first?.pilotingHours == 5)
        #expect(craneRows.map(\.id) == [keptCrane.id])
        #expect(craneRows.first?.craneName == "Main crane")
        #expect(report.booksChanged == [.dp, .anchorHandling])
        #expect(!report.booksChanged.contains(.rov))
        #expect(!report.booksChanged.contains(.crane))
    }

    @Test func mergeInsertsNewRowsAndSkipsTheExistingId() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keptID = UUID()
        let existing = DPEntry(id: keptID, source: .manual, date: .now, durationHours: 1, vessel: "Kept")
        existing.notes = "original"
        let untouched = ROVEntry(date: .now, vessel: "ROV")
        untouched.pilotingHours = 2
        context.insert(existing)
        context.insert(untouched)
        try context.save()

        let same = DPEntry(id: keptID, source: .manual, date: .now, durationHours: 9, vessel: "Ignored")
        same.notes = "should not replace"
        let added = DPEntry(source: .manual, date: .now, durationHours: 3, vessel: "Added")
        let csv = try ImportExchange.encodeCSV(
            books: ExportBookSelection(dp: true, anchorHandling: false, rov: false, crane: false),
            filter: ExportDateFilter(quickRange: .allTime, from: nil, to: nil),
            dp: [same, added],
            moves: [],
            rov: [],
            crane: []
        )
        let payload = try ImportExchange.parse(data: Data(csv.utf8), filename: "merge.csv")
        let report = try ImportStore.apply(mode: .merge, payload: payload, context: context)

        let dp = try context.fetch(FetchDescriptor<DPEntry>())
        let rov = try context.fetch(FetchDescriptor<ROVEntry>())
        #expect(dp.count == 2)
        #expect(dp.first { $0.id == keptID }?.notes == "original")
        #expect(dp.first { $0.id == keptID }?.vessel == "Kept")
        #expect(dp.contains { $0.id == added.id && $0.vessel == "Added" })
        #expect(rov.map(\.id) == [untouched.id])
        #expect(rov.first?.pilotingHours == 2)
        #expect(report.added == 1)
        #expect(report.skippedDuplicates == 1)
        #expect(report.booksChanged == [.dp])
        #expect(report.logPath == [.dp])
        #expect(report.toastText == "Added 1 entry. Skipped 1 duplicate.")
    }
}
