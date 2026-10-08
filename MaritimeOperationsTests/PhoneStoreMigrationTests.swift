import Testing
import Foundation
import SwiftData
@testable import MaritimeOperations

/// Frozen copy of the store schema on Henning's phone: the build right before the Anchor handling
/// (ah…) fields. RigMove is the Mac tree as backed up before the AH edits (Models/RigMove.swift,
/// Oct 5 13:53, client…photoJPEG and no ah… fields); DPEntry is unchanged since then (Oct 5 16:41).
/// Never edit these classes to follow the app: they stand for data already on a device.
/// Property names, types, optionality, defaults and the photo's external storage must stay
/// exactly as shipped, or the test stops proving anything about the real store.
enum PhoneStoreSchemaBeforeAH: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] { [DPEntry.self, RigMove.self] }

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
        var client: String = ""
        var fromLocation: String = ""
        var toLocation: String = ""
        var vessel: String = ""
        var rank: String = ""
        var projectText: String = ""
        var anchorLineCount: Int = 0
        var hasChain: Bool = false
        var hasWire: Bool = false
        var hasFiber: Bool = false
        var hasSubBuoys: Bool = false
        var hasOther: Bool = false
        var otherEquipment: String = ""
        @Attribute(.externalStorage) var photoJPEG: Data? = nil

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

    @Model
    final class DPEntry {
        var id: UUID
        var sourceRaw: String
        var date: Date
        var startTime: Date?
        var endTime: Date?
        var durationHours: Double
        var vessel: String
        var rig: String
        var vesselType: String
        var dpClass: String
        var mode: String?
        var activityCode: String?
        var notes: String?
        var masterInitials: String?
        var locationName: String = ""
        var client: String = ""
        var locationFromPhone: Bool = false
        var latitudeText: String = ""
        var longitudeText: String = ""
        var dpClassLevel: Int? = nil
        var rank: String? = nil
        var createdAt: Date
        var updatedAt: Date

        init(id: UUID, sourceRaw: String, date: Date, startTime: Date?, endTime: Date?, durationHours: Double, vessel: String, rig: String, vesselType: String, dpClass: String, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.sourceRaw = sourceRaw
            self.date = date
            self.startTime = startTime
            self.endTime = endTime
            self.durationHours = durationHours
            self.vessel = vessel
            self.rig = rig
            self.vesselType = vesselType
            self.dpClass = dpClass
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

/// Opens a store written by the phone's pre-AH build (3 DP lines + 1 fully filled Rig Move with
/// a photo, all in one store) with today's schema. Two routes, because the phone may get the AH
/// build first or the AH + ROV/Crane build in one go.
///
/// No VersionedSchema or SchemaMigrationPlan is needed in the app: every change since this
/// schema is lightweight (optional ah… attributes with nil defaults, new ROVEntry/CraneEntry
/// entities), and SwiftData infers that migration when the container opens.
@MainActor
struct PhoneStoreMigrationTests {
    // MARK: Fixed data (whole seconds, so dates compare exactly after the round trip)

    private static let base = Date(timeIntervalSince1970: 1_790_000_000)
    private static func at(hours: Double) -> Date { base.addingTimeInterval(hours * 3600) }

    private struct DPRow {
        let id: UUID; let sourceRaw: String; let date: Date; let startTime: Date?; let endTime: Date?
        let durationHours: Double; let vessel: String; let rig: String; let vesselType: String; let dpClass: String
        let mode: String?; let activityCode: String?; let notes: String?; let masterInitials: String?
        let locationName: String; let client: String; let locationFromPhone: Bool
        let latitudeText: String; let longitudeText: String; let dpClassLevel: Int?; let rank: String?
        let createdAt: Date; let updatedAt: Date
    }

    private static let dpRows: [DPRow] = [
        DPRow(id: UUID(), sourceRaw: "timed", date: at(hours: 0), startTime: at(hours: 0), endTime: at(hours: 6.5),
              durationHours: 6.5, vessel: "MIG DP Ship", rig: "MIG Rig", vesselType: "PSV", dpClass: "DP2",
              mode: "Auto position", activityCode: "DP-OPS", notes: "Timed line", masterInitials: "HO",
              locationName: "Field A", client: "Client A", locationFromPhone: true,
              latitudeText: "60°12.345'N", longitudeText: "002°34.567'E", dpClassLevel: 2, rank: "2nd Off.",
              createdAt: at(hours: 6.5), updatedAt: at(hours: 6.5)),
        DPRow(id: UUID(), sourceRaw: "manual", date: at(hours: 24), startTime: at(hours: 24), endTime: at(hours: 36),
              durationHours: 12, vessel: "MIG DP Ship", rig: "", vesselType: "AHTS", dpClass: "",
              mode: "Joystick", activityCode: "DP-TRANS", notes: "Manual line", masterInitials: "KM",
              locationName: "Field B", client: "Client B", locationFromPhone: false,
              latitudeText: "58.9", longitudeText: "5.7", dpClassLevel: 3, rank: "DPO",
              createdAt: at(hours: 37), updatedAt: at(hours: 40)),
        // Oldest style: no start/end, free-text class only.
        DPRow(id: UUID(), sourceRaw: "manual", date: at(hours: 48), startTime: nil, endTime: nil,
              durationHours: 0.25, vessel: "Vessel", rig: "Rig C", vesselType: "MSV", dpClass: "Class 1 (old text)",
              mode: "Manual", activityCode: "DP-STBY", notes: "Old line", masterInitials: "AB",
              locationName: "Port", client: "Client C", locationFromPhone: false,
              latitudeText: "", longitudeText: "-", dpClassLevel: 1, rank: "Master",
              createdAt: at(hours: 49), updatedAt: at(hours: 49)),
    ]

    /// Typed "Old DP hours" (UserDefaults `dp.oldHoursText`, not in the store).
    private static let oldDPHoursText = "12.5"
    private static let expectedDPHours = 6.5 + 12 + 0.25 + 12.5

    private static let moveID = UUID()
    /// 256 KB "JPEG": above SwiftData's external-storage threshold, so it lives in the store's
    /// external data folder, the part most likely to get lost in a migration.
    private static let photo: Data = {
        var bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0]
        bytes += (0..<(256 * 1024)).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }
        bytes += [0xFF, 0xD9]
        return Data(bytes)
    }()

    // MARK: Tests

    /// Phone build → AH + ROV/Crane build (`LaunchEnvironment.models`) in one step.
    @Test func phoneStoreOpensWithCurrentSchemaKeepingEveryValue() throws {
        try withPhoneStore { url in
            try checkCurrentStore(at: url)
        }
    }

    /// Phone build → AH-only build (DPEntry + RigMove) → AH + ROV/Crane build.
    @Test func phoneStoreSurvivesAHBuildThenROVCraneBuild() throws {
        try withPhoneStore { url in
            do {
                let ahSchema = Schema([DPEntry.self, RigMove.self])
                let ahOnly = try ModelContainer(for: ahSchema, configurations: [ModelConfiguration(schema: ahSchema, url: url)])
                let context = ModelContext(ahOnly)
                #expect(try context.fetchCount(FetchDescriptor<DPEntry>()) == 3)
                let moves = try context.fetch(FetchDescriptor<RigMove>())
                #expect(moves.count == 1)
                #expect(moves.first?.photoJPEG == Self.photo)
            }
            try checkCurrentStore(at: url)
        }
    }

    // MARK: Helpers

    /// Writes the pre-AH store to a temp folder, runs `body`, then deletes the folder
    /// (store, -wal/-shm and the external data folder).
    private func withPhoneStore(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("phone-store-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")

        do {
            let oldSchema = Schema(versionedSchema: PhoneStoreSchemaBeforeAH.self)
            let old = try ModelContainer(for: oldSchema, configurations: [ModelConfiguration(schema: oldSchema, url: url)])
            let context = ModelContext(old)
            for row in Self.dpRows {
                let line = PhoneStoreSchemaBeforeAH.DPEntry(
                    id: row.id, sourceRaw: row.sourceRaw, date: row.date, startTime: row.startTime, endTime: row.endTime,
                    durationHours: row.durationHours, vessel: row.vessel, rig: row.rig, vesselType: row.vesselType,
                    dpClass: row.dpClass, createdAt: row.createdAt, updatedAt: row.updatedAt
                )
                line.mode = row.mode
                line.activityCode = row.activityCode
                line.notes = row.notes
                line.masterInitials = row.masterInitials
                line.locationName = row.locationName
                line.client = row.client
                line.locationFromPhone = row.locationFromPhone
                line.latitudeText = row.latitudeText
                line.longitudeText = row.longitudeText
                line.dpClassLevel = row.dpClassLevel
                line.rank = row.rank
                context.insert(line)
            }

            let move = PhoneStoreSchemaBeforeAH.RigMove(
                id: Self.moveID, rigName: "MIG Rig", date: Self.at(hours: 72),
                startTime: Self.at(hours: 72), endTime: Self.at(hours: 81.5),
                operationRaw: "Prelay", notes: "Kept note", isDone: true, createdAt: Self.at(hours: 82)
            )
            move.client = "MIG Client"
            move.fromLocation = "Bergen"
            move.toLocation = "Field A"
            move.vessel = "MIG DP Ship"
            move.rank = "Ch. Off."
            move.projectText = "MIG Project"
            move.anchorLineCount = 8
            move.hasChain = true
            move.hasWire = true
            move.hasFiber = true
            move.hasSubBuoys = true
            move.hasOther = true
            move.otherEquipment = "Shark jaw"
            move.photoJPEG = Self.photo
            context.insert(move)
            try context.save()

            // Sanity: the old build's own totals, so "unchanged" below compares like with like.
            let oldLines = try context.fetch(FetchDescriptor<PhoneStoreSchemaBeforeAH.DPEntry>())
            #expect(oldLines.count == 3)
            #expect(oldLines.reduce(0) { $0 + $1.durationHours } + 12.5 == Self.expectedDPHours)
        }

        try body(url)
    }

    /// Opens `url` with today's schema and checks every pre-AH value, the empty ah… fields,
    /// the DP totals, the empty new books, and that the migrated rows save again.
    private func checkCurrentStore(at url: URL) throws {
        let schema = Schema(LaunchEnvironment.models)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = ModelContext(container)

        // DP lines: all three, every field.
        let lines = try context.fetch(FetchDescriptor<DPEntry>())
        #expect(lines.count == Self.dpRows.count)
        for row in Self.dpRows {
            let line = try #require(lines.first { $0.id == row.id }, "DP line \(row.vessel) \(row.durationHours) h lost")
            #expect(line.sourceRaw == row.sourceRaw)
            #expect(line.source.rawValue == row.sourceRaw)
            #expect(line.date == row.date)
            #expect(line.startTime == row.startTime)
            #expect(line.endTime == row.endTime)
            #expect(line.durationHours == row.durationHours)
            #expect(line.vessel == row.vessel)
            #expect(line.rig == row.rig)
            #expect(line.vesselType == row.vesselType)
            #expect(line.dpClass == row.dpClass)
            #expect(line.mode == row.mode)
            #expect(line.activityCode == row.activityCode)
            #expect(line.notes == row.notes)
            #expect(line.masterInitials == row.masterInitials)
            #expect(line.locationName == row.locationName)
            #expect(line.client == row.client)
            #expect(line.locationFromPhone == row.locationFromPhone)
            #expect(line.latitudeText == row.latitudeText)
            #expect(line.longitudeText == row.longitudeText)
            #expect(line.dpClassLevel == row.dpClassLevel)
            #expect(line.rank == row.rank)
            #expect(line.rank.flatMap(CrewRank.init(rawValue:)) != nil, "Stored rank still maps to a CrewRank")
            #expect(line.createdAt == row.createdAt)
            #expect(line.updatedAt == row.updatedAt)
        }

        // Rig Move: every pre-AH field, photo included.
        let moves = try context.fetch(FetchDescriptor<RigMove>())
        #expect(moves.count == 1)
        let move = try #require(moves.first)
        #expect(move.id == Self.moveID)
        #expect(move.rigName == "MIG Rig")
        #expect(move.date == Self.at(hours: 72))
        #expect(move.startTime == Self.at(hours: 72))
        #expect(move.endTime == Self.at(hours: 81.5))
        #expect(move.operationRaw == "Prelay")
        #expect(move.operation == .prelay)
        #expect(move.workedHours == 9.5)
        #expect(move.notes == "Kept note")
        #expect(move.isDone)
        #expect(move.createdAt == Self.at(hours: 82))
        #expect(move.client == "MIG Client")
        #expect(move.fromLocation == "Bergen")
        #expect(move.toLocation == "Field A")
        #expect(move.vessel == "MIG DP Ship")
        #expect(move.rank == "Ch. Off.")
        #expect(move.crewRank == .chiefOfficer)
        #expect(move.projectText == "MIG Project")
        #expect(move.anchorLineCount == 8)
        #expect(move.hasChain)
        #expect(move.hasWire)
        #expect(move.hasFiber)
        #expect(move.hasSubBuoys)
        #expect(move.hasOther)
        #expect(move.otherEquipment == "Shark jaw")
        #expect(move.photoJPEG == Self.photo, "Photo bytes changed or lost (external storage)")

        // All 14 ah… fields read as not set.
        #expect(move.ahJobTypeRaw == nil)
        #expect(move.ahUnderTraining == nil)
        #expect(move.ahUnitTypeRaw == nil)
        #expect(move.ahFieldArea == nil)
        #expect(move.ahTasksRaw == nil)
        #expect(move.ahControlModeRaw == nil)
        #expect(move.ahSupervised == nil)
        #expect(move.ahAnchorIDs == nil)
        #expect(move.ahWaterDepthM == nil)
        #expect(move.ahMaxPaidOutM == nil)
        #expect(move.ahPeakTensionT == nil)
        #expect(move.ahWaveHeightM == nil)
        #expect(move.ahWindKn == nil)
        #expect(move.ahWindDirection == nil)
        #expect(move.ahJobType == .rigMove)
        #expect(move.ahTasks.isEmpty)

        // DP totals: unchanged, and ROV/Crane add nothing.
        let rovEntries = try context.fetch(FetchDescriptor<ROVEntry>())
        let craneEntries = try context.fetch(FetchDescriptor<CraneEntry>())
        #expect(rovEntries.isEmpty)
        #expect(craneEntries.isEmpty)
        let stats = LogBookStats(entries: lines, moves: moves, rovEntries: rovEntries, craneEntries: craneEntries, oldDPHoursText: Self.oldDPHoursText)
        #expect(stats.dpHours == Self.expectedDPHours)
        #expect(stats.dpEntries == 3)
        #expect(stats.rigMoves == 1)
        #expect(stats.logSpokenValue(for: .dp) == "\(LogBookStats.hoursNumber(31.25)) hours total, 3 entries")

        // The migrated store takes writes: an AH edit on the old row and a new ROV entry.
        move.ahJobType = .rigTow
        move.ahWaterDepthM = 120
        context.insert(ROVEntry(date: Self.at(hours: 100), vessel: move.vessel))
        try context.save()

        let reread = ModelContext(container)
        let again = try #require(try reread.fetch(FetchDescriptor<RigMove>()).first)
        #expect(again.ahJobType == .rigTow)
        #expect(again.ahWaterDepthM == 120)
        #expect(again.photoJPEG == Self.photo)
        #expect(again.otherEquipment == "Shark jaw")
        #expect(try reread.fetchCount(FetchDescriptor<DPEntry>()) == 3)
        #expect(try reread.fetchCount(FetchDescriptor<ROVEntry>()) == 1)
    }
}
