import Testing
import Foundation
import SwiftData
@testable import MaritimeOperations

/// The RigMove schema as it was before the Anchor handling fields (committed model, before
/// any optional extras). Used to prove an existing on-disk store opens with the new model.
enum RigMoveSchemaBeforeAH: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [RigMove.self] }

    @Model
    final class RigMove {
        var id: UUID
        var rigName: String
        var date: Date
        var startTime: Date?
        var endTime: Date?
        var operationRaw: String
        var notes: String
        var isDone: Bool
        var createdAt: Date

        init(id: UUID, rigName: String, date: Date, startTime: Date?, endTime: Date?, operationRaw: String, notes: String, isDone: Bool, createdAt: Date) {
            self.id = id
            self.rigName = rigName
            self.date = date
            self.startTime = startTime
            self.endTime = endTime
            self.operationRaw = operationRaw
            self.notes = notes
            self.isDone = isDone
            self.createdAt = createdAt
        }
    }
}

@MainActor
struct AnchorHandlingModelTests {
    // MARK: Defaults

    @Test func newRigMoveHasEmptyAHFieldsAndRigMoveJobType() {
        let move = RigMove(rigName: "Rig A")
        #expect(move.ahJobTypeRaw == nil)
        #expect(move.ahJobType == .rigMove)
        #expect(move.ahJobType.label == "Rig move")
        #expect(move.ahUnderTraining == nil)
        #expect(move.ahUnitTypeRaw == nil)
        #expect(move.ahUnitType == nil)
        #expect(move.ahFieldArea == nil)
        #expect(move.ahTasksRaw == nil)
        #expect(move.ahTasks.isEmpty)
        #expect(move.ahControlModeRaw == nil)
        #expect(move.ahControlMode == nil)
        #expect(move.ahSupervised == nil)
        #expect(move.ahAnchorIDs == nil)
        #expect(move.ahWaterDepthM == nil)
        #expect(move.ahMaxPaidOutM == nil)
        #expect(move.ahPeakTensionT == nil)
        #expect(move.ahWaveHeightM == nil)
        #expect(move.ahWindKn == nil)
        #expect(move.ahWindDirection == nil)
        #expect(move.rank == "")
        #expect(move.crewRank == nil)
    }

    @Test func unknownStoredValuesFallBackSafely() {
        let move = RigMove(rigName: "Rig A")
        move.ahJobTypeRaw = "somethingNew"
        move.ahUnitTypeRaw = "?"
        move.ahControlModeRaw = "?"
        move.ahTasksRaw = "runAnchor|bogus||recoverAnchor"
        #expect(move.ahJobType == .rigMove)
        #expect(move.ahUnitType == nil)
        #expect(move.ahControlMode == nil)
        #expect(move.ahTasks == [.runAnchor, .recoverAnchor])
    }

    @Test func tasksRoundTripInFixedOrderAndEmptyIsNil() {
        let move = RigMove(rigName: "Rig A")
        move.ahTasks = [.deckAnchor, .recoverAnchor]
        #expect(move.ahTasksRaw == "recoverAnchor|deckAnchor")
        #expect(move.ahTasks == [.recoverAnchor, .deckAnchor])
        move.ahTasks = []
        #expect(move.ahTasksRaw == nil)
    }

    @Test func numberInputEmptyIsNotSetAndJunkIsFlagged() {
        var input = AHNumberInput(anchorCount: "", waterDepth: "", paidOut: "", tension: "", waveHeight: "", wind: "")
        #expect(input.firstInvalidField == nil)
        #expect(input.waterDepthValue == nil)
        #expect(input.anchorCountValue == nil)

        input.waterDepth = "120,5"
        input.anchorCount = "8"
        #expect(input.waterDepthValue == 120.5)
        #expect(input.anchorCountValue == 8)
        #expect(input.firstInvalidField == nil)

        input.tension = "8x"
        #expect(input.firstInvalidField == "Peak tension")
        #expect(AHNumber.parse("-3") == nil)
        #expect(AHNumber.text(nil) == "")
        #expect(AHNumber.text(1.5) == "1.5")
        #expect(AHNumber.text(120) == "120")
    }

    @Test func durationCopy() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(AHFormat.duration(start: start, end: start.addingTimeInterval(11.5 * 3600)) == "11 h 30 min")
        #expect(AHFormat.duration(start: start, end: start.addingTimeInterval(6 * 3600)) == "6 h")
        #expect(AHFormat.duration(start: start, end: start.addingTimeInterval(45 * 60)) == "45 min")
        #expect(AHFormat.duration(start: start, end: start.addingTimeInterval(-60)) == nil)
    }

    @Test func oldRowWithEmptyAHFieldsNeverBlocksSave() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let old = RigMove(rigName: "Old Rig", date: start, startTime: start, endTime: start.addingTimeInterval(3600))
        #expect(
            RigMoveCheck.block(
                rigName: old.rigName,
                start: old.startTime ?? old.date,
                finish: old.endTime ?? old.date,
                operation: old.operation,
                projectText: old.projectText,
                hasOther: old.hasOther,
                otherEquipment: old.otherEquipment
            ) == nil
        )
        // A legacy row with only a date (no start/end) opens with start == end: still saves.
        let legacy = RigMove(rigName: "Legacy", date: start)
        #expect(
            RigMoveCheck.block(
                rigName: legacy.rigName,
                start: legacy.startTime ?? legacy.date,
                finish: legacy.endTime ?? legacy.startTime ?? legacy.date,
                operation: legacy.operation,
                projectText: legacy.projectText
            ) == nil
        )
    }

    // MARK: Migration

    @Test func storeSavedBeforeAHFieldsOpensWithNewModel() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ah-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("old.store")

        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        do {
            let oldSchema = Schema(versionedSchema: RigMoveSchemaBeforeAH.self)
            let oldContainer = try ModelContainer(
                for: oldSchema,
                configurations: [ModelConfiguration(schema: oldSchema, url: url)]
            )
            let context = ModelContext(oldContainer)
            context.insert(
                RigMoveSchemaBeforeAH.RigMove(
                    id: id,
                    rigName: "Old Rig",
                    date: start,
                    startTime: start,
                    endTime: start.addingTimeInterval(4 * 3600),
                    operationRaw: "Prelay",
                    notes: "Kept note",
                    isDone: true,
                    createdAt: start
                )
            )
            try context.save()
        }

        let newSchema = Schema([DPEntry.self, RigMove.self])
        let newContainer = try ModelContainer(
            for: newSchema,
            configurations: [ModelConfiguration(schema: newSchema, url: url)]
        )
        let context = ModelContext(newContainer)
        let rows = try context.fetch(FetchDescriptor<RigMove>())
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.id == id)
        #expect(row.rigName == "Old Rig")
        #expect(row.notes == "Kept note")
        #expect(row.isDone)
        #expect(row.operation == .prelay)
        #expect(row.workedHours == 4)
        // New fields read as not set; job type reads as Rig move.
        #expect(row.ahJobTypeRaw == nil)
        #expect(row.ahJobType == .rigMove)
        #expect(row.ahTasks.isEmpty)
        #expect(row.ahSupervised == nil)
        #expect(row.ahWaterDepthM == nil)
        #expect(row.rank == "")
        #expect(row.vessel == "")

        // Old row saves with new AH values.
        row.ahJobType = .rigTow
        row.ahTasks = [.towConnect]
        row.ahWaterDepthM = 95
        try context.save()
        let again = try ModelContext(newContainer).fetch(FetchDescriptor<RigMove>())
        #expect(again.first?.ahJobType == .rigTow)
        #expect(again.first?.ahTasks == [.towConnect])
        #expect(again.first?.ahWaterDepthM == 95)
    }

    // MARK: Ranks

    @Test func existingRankRawValuesAreUnchangedAndNewOnesAreAppended() {
        #expect(CrewRank.allCases.map(\.rawValue) == [
            "Eng.", "Ch. Eng.", "Elec.", "DPO", "Ch. Off.", "2nd Off.", "Master",
            "2nd Eng.", "3rd Eng.", "AB",
            "Crane operator"
        ])
    }

    @Test func dpPickerIsUnchanged() {
        #expect(CrewRank.dpPickerCases.map(\.rawValue) == [
            "Eng.", "Ch. Eng.", "Elec.", "DPO", "Ch. Off.", "2nd Off.", "Master"
        ])
        #expect(!CrewRank.dpPickerCases.contains(.secondEngineer))
        #expect(!CrewRank.dpPickerCases.contains(.thirdEngineer))
        #expect(!CrewRank.dpPickerCases.contains(.ableSeaman))
    }

    @Test func ahPositionOrderIsDeckThenEngineersThenAB() {
        let order = CrewRank.ahPositionCases
        #expect(order.map(\.rawValue) == [
            "Master", "Ch. Off.", "2nd Off.", "DPO",
            "Ch. Eng.", "2nd Eng.", "3rd Eng.", "Eng.", "Elec.",
            "AB"
        ])
        // Every rank except the Crane-only one is offered once.
        #expect(Set(order) == Set(CrewRank.allCases).subtracting([.craneOperator]))
        #expect(order.count == CrewRank.allCases.count - 1)
        #expect(order.last == .ableSeaman)
        let firstEngineer = order.firstIndex(of: .chiefEngineer)!
        #expect(order.prefix(firstEngineer).allSatisfy { [.master, .chiefOfficer, .secondOfficer, .dpo].contains($0) })
    }

    // MARK: Log books

    @Test func starredBooksDefaultToDPAndToggle() {
        #expect(StarredBooks.decode(StarredBooks.defaultRaw) == [.dp])
        var raw = StarredBooks.toggled(.anchorHandling, in: StarredBooks.defaultRaw)
        #expect(StarredBooks.decode(raw) == [.dp, .anchorHandling])
        raw = StarredBooks.toggled(.dp, in: raw)
        raw = StarredBooks.toggled(.anchorHandling, in: raw)
        #expect(raw == "")
        #expect(StarredBooks.shownOnMain(raw) == [.dp], "Nothing starred shows DP")
        #expect(StarredBooks.decode("junk,anchorHandling") == [.anchorHandling])
    }

    // MARK: Vessel prefill (new AH entry)

    @Test func vesselPrefillTakesNewerOfDPLineAndAHEntry() {
        let t0 = Date(timeIntervalSince1970: 1_780_000_000)
        let dp = AHVesselPrefill.Candidate(vessel: "DP Ship", date: t0, createdAt: t0)
        let ah = AHVesselPrefill.Candidate(vessel: "AH Ship", date: t0.addingTimeInterval(3600), createdAt: t0)
        #expect(AHVesselPrefill.vessel(from: [dp, ah]) == "AH Ship")
        let newerDP = AHVesselPrefill.Candidate(vessel: " DP Ship 2 ", date: t0.addingTimeInterval(7200), createdAt: t0)
        #expect(AHVesselPrefill.vessel(from: [dp, ah, newerDP]) == "DP Ship 2")
        // Blank ships are skipped, not prefilled.
        let blankNewest = AHVesselPrefill.Candidate(vessel: "  ", date: t0.addingTimeInterval(9000), createdAt: t0)
        #expect(AHVesselPrefill.vessel(from: [dp, ah, blankNewest]) == "AH Ship")
        // Same date: the later-created record wins.
        let tieLater = AHVesselPrefill.Candidate(vessel: "Later", date: t0, createdAt: t0.addingTimeInterval(5))
        #expect(AHVesselPrefill.vessel(from: [dp, tieLater]) == "Later")
        #expect(AHVesselPrefill.vessel(from: []) == "")
    }

    @Test func vesselPrefillFromModelsIgnoresRank() {
        let t0 = Date(timeIntervalSince1970: 1_780_000_000)
        let line = DPEntry(source: .manual, date: t0, durationHours: 2, vessel: "DP Ship", rank: "DPO", createdAt: t0)
        let move = RigMove(rigName: "Rig A", date: t0.addingTimeInterval(-3600), vessel: "Old AH Ship", rank: "Master")
        #expect(AHVesselPrefill.vessel(dpLines: [line], ahEntries: [move]) == "DP Ship")
        move.date = t0.addingTimeInterval(3600)
        #expect(AHVesselPrefill.vessel(dpLines: [line], ahEntries: [move]) == "Old AH Ship")
    }
}
