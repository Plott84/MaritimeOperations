import Foundation
import SwiftData

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
    var createdAt: Date
    var updatedAt: Date

    var source: DPEntrySource {
        get { DPEntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var isEligibleUnderCurrentRule: Bool {
        EligibilitySettings.current.isEligible(durationHours: durationHours)
    }

    init(
        id: UUID = UUID(),
        source: DPEntrySource,
        date: Date = .now,
        startTime: Date? = nil,
        endTime: Date? = nil,
        durationHours: Double,
        vessel: String,
        rig: String = "",
        vesselType: String = "",
        dpClass: String = "",
        mode: String? = nil,
        activityCode: String? = nil,
        notes: String? = nil,
        masterInitials: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.sourceRaw = source.rawValue
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.durationHours = durationHours
        self.vessel = vessel
        self.rig = rig
        self.vesselType = vesselType
        self.dpClass = dpClass
        self.mode = mode
        self.activityCode = activityCode
        self.notes = notes
        self.masterInitials = masterInitials
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
