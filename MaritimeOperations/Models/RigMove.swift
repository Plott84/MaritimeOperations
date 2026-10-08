import Foundation
import SwiftData

enum RigMoveOperation: String, CaseIterable, Identifiable {
    case towing = "Towing"
    case anchorHandling = "Anchor Handling"
    case prelay = "Prelay"
    case project = "Project"

    var id: String { rawValue }

    /// Display copy. Stored value stays "Prelay" so existing rows still match.
    var label: String {
        switch self {
        case .towing: return "Towing"
        case .anchorHandling: return "Anchor Handling"
        case .prelay: return "Pre-lay"
        case .project: return "Project"
        }
    }
}

enum RigMoveSaveBlock: Equatable {
    case missingRigName
    case finishBeforeStart
    case missingProjectText
    case missingOtherEquipment

    var message: String {
        switch self {
        case .missingRigName: return "Rig name is required."
        case .finishBeforeStart: return "Finish is before start."
        case .missingProjectText: return "Project text is required."
        case .missingOtherEquipment: return "Other equipment is required."
        }
    }
}

enum RigMoveCheck {
    static func block(
        rigName: String,
        start: Date,
        finish: Date,
        operation: RigMoveOperation,
        projectText: String,
        hasOther: Bool = false,
        otherEquipment: String = ""
    ) -> RigMoveSaveBlock? {
        if rigName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .missingRigName
        }
        if finish < start {
            return .finishBeforeStart
        }
        if operation == .project,
           projectText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .missingProjectText
        }
        if hasOther,
           otherEquipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .missingOtherEquipment
        }
        return nil
    }

    /// Hours from start to finish, including a finish after midnight. Nil when finish is earlier.
    static func workedHours(start: Date, finish: Date) -> Double? {
        guard finish >= start else { return nil }
        return finish.timeIntervalSince(start) / 3600
    }
}

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
    /// Client or operator. Empty on moves saved before this field existed.
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
    /// Optional personal note photo for this move only. Never part of hours export.
    @Attribute(.externalStorage) var photoJPEG: Data? = nil

    // MARK: Anchor handling (AH) fields
    // All optional with nil defaults: rows saved before these existed load as nil and still save.
    // Typed accessors (ahJobType, ahTasks, …) live in AnchorHandling.swift.
    /// AHJobType raw value. Nil reads as "Rig move".
    var ahJobTypeRaw: String? = nil
    /// Under training on this job. Nil = not set.
    var ahUnderTraining: Bool? = nil
    /// AHUnitType raw value. Nil = not set.
    var ahUnitTypeRaw: String? = nil
    /// Field or area name only. No coordinates.
    var ahFieldArea: String? = nil
    /// AHTask raw values joined with "|". Nil = none picked.
    var ahTasksRaw: String? = nil
    /// AHControlMode raw value (DP / Manual). Nil = not set.
    var ahControlModeRaw: String? = nil
    /// Supervised by an AH-experienced Master. Nil = not set (not the same as No).
    var ahSupervised: Bool? = nil
    var ahAnchorIDs: String? = nil
    var ahWaterDepthM: Double? = nil
    var ahMaxPaidOutM: Double? = nil
    /// Own approximate reading, tonnes.
    var ahPeakTensionT: Double? = nil
    var ahWaveHeightM: Double? = nil
    var ahWindKn: Double? = nil
    var ahWindDirection: String? = nil

    var operation: RigMoveOperation {
        get { RigMoveOperation(rawValue: operationRaw) ?? .anchorHandling }
        set { operationRaw = newValue.rawValue }
    }

    var workedHours: Double? {
        guard let startTime, let endTime else { return nil }
        return RigMoveCheck.workedHours(start: startTime, finish: endTime)
    }

    init(
        id: UUID = UUID(),
        rigName: String,
        date: Date = .now,
        startTime: Date? = nil,
        endTime: Date? = nil,
        operation: RigMoveOperation = .anchorHandling,
        notes: String = "",
        isDone: Bool = false,
        createdAt: Date = .now,
        client: String = "",
        fromLocation: String = "",
        toLocation: String = "",
        vessel: String = "",
        rank: String = "",
        projectText: String = "",
        anchorLineCount: Int = 0,
        hasChain: Bool = false,
        hasWire: Bool = false,
        hasFiber: Bool = false,
        hasSubBuoys: Bool = false,
        hasOther: Bool = false,
        otherEquipment: String = "",
        photoJPEG: Data? = nil
    ) {
        self.id = id
        self.rigName = rigName
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.operationRaw = operation.rawValue
        self.notes = notes
        self.isDone = isDone
        self.createdAt = createdAt
        self.client = client
        self.fromLocation = fromLocation
        self.toLocation = toLocation
        self.vessel = vessel
        self.rank = rank
        self.projectText = projectText
        self.anchorLineCount = anchorLineCount
        self.hasChain = hasChain
        self.hasWire = hasWire
        self.hasFiber = hasFiber
        self.hasSubBuoys = hasSubBuoys
        self.hasOther = hasOther
        self.otherEquipment = otherEquipment
        self.photoJPEG = photoJPEG
    }
}
