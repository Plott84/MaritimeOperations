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
    var locationName: String = ""
    var latitudeText: String = ""
    var longitudeText: String = ""
    /// IMO DP class 1 / 2 / 3. Nil on lines saved before this field existed.
    var dpClassLevel: Int? = nil
    /// Optional rank (CrewRank raw value). Nil on older lines.
    var rank: String? = nil
    var createdAt: Date
    var updatedAt: Date

    var source: DPEntrySource {
        get { DPEntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// "Class 2" from the picker, else the older free-text class if any.
    var dpClassLabel: String {
        if let dpClassLevel { return "Class \(dpClassLevel)" }
        return dpClass
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
        locationName: String = "",
        latitudeText: String = "",
        longitudeText: String = "",
        dpClassLevel: Int? = nil,
        rank: String? = nil,
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
        self.locationName = locationName
        self.latitudeText = latitudeText
        self.longitudeText = longitudeText
        self.dpClassLevel = dpClassLevel
        self.rank = rank
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
