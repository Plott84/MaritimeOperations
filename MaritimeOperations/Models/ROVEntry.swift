import Foundation
import SwiftData

/// One ROV book entry (one shift with a dive count). Start (`date`) is the only required field;
/// everything else is optional with a nil default and starts empty on a new entry, except the
/// vessel, which the form prefills (BookVesselPrefill). Pickers and parsing: ROVCraneLogbook.swift.
@Model
final class ROVEntry {
    var id: UUID = UUID()
    /// Start date and time. Required. Also the sort and prefill date, like RigMove.date.
    var date: Date = Date.now
    var endTime: Date? = nil
    var vessel: String? = nil
    /// ROVGrade raw value (Position). Nil = "Not set".
    var gradeRaw: String? = nil
    /// Text for grade "Other". Nil unless the grade is Other.
    var gradeOther: String? = nil
    /// Nil = not set (not the same as No).
    var underTraining: Bool? = nil
    /// ROV system / vehicle name as known on board. Free text.
    var rovSystem: String? = nil
    /// ROVClass raw value ("I"…"V").
    var rovClassRaw: String? = nil
    /// Field or area name only. No coordinates.
    var fieldArea: String? = nil
    /// ROVJobType raw value.
    var jobTypeRaw: String? = nil
    /// ROVTask raw values joined with "|". Nil = none picked.
    var tasksRaw: String? = nil
    /// Own time at the controls, typed by hand. Not the shift length.
    var pilotingHours: Double? = nil
    var dives: Int? = nil
    /// ROVSupportSite raw value. Optional; nil = "Not set".
    var supportSiteRaw: String? = nil
    /// Text for support site "Other". Nil unless the site is Other.
    var supportSiteOther: String? = nil
    var remarks: String? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        date: Date = .now,
        endTime: Date? = nil,
        vessel: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.endTime = endTime
        self.vessel = vessel
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension ROVEntry {
    var rovClass: ROVClass? {
        get { rovClassRaw.flatMap(ROVClass.init(rawValue:)) }
        set { rovClassRaw = newValue?.rawValue }
    }

    var jobType: ROVJobType? {
        get { jobTypeRaw.flatMap(ROVJobType.init(rawValue:)) }
        set { jobTypeRaw = newValue?.rawValue }
    }

    var tasks: Set<ROVTask> {
        get { LogChoiceSet.decode(tasksRaw) }
        set { tasksRaw = LogChoiceSet.encode(newValue) }
    }

    var grade: ROVGrade? {
        get { gradeRaw.flatMap(ROVGrade.init(rawValue:)) }
        set { gradeRaw = newValue?.rawValue }
    }

    /// "ROV Supervisor", or the typed text for Other.
    var gradeLabel: String? {
        guard let grade else { return nil }
        return grade.isOther ? (gradeOther ?? grade.pickerLabel) : grade.pickerLabel
    }

    var supportSite: ROVSupportSite? {
        get { supportSiteRaw.flatMap(ROVSupportSite.init(rawValue:)) }
        set { supportSiteRaw = newValue?.rawValue }
    }

    /// "Vessel on DP", or the typed text for Other.
    var supportSiteLabel: String? {
        guard let supportSite else { return nil }
        return supportSite.isOther ? (supportSiteOther ?? supportSite.label) : supportSite.label
    }

    /// Shift length from start to end. Nil without an end or when end is before start.
    var durationHours: Double? {
        guard let endTime, endTime >= date else { return nil }
        return endTime.timeIntervalSince(date) / 3600
    }

    /// Row title: job type, or "ROV entry" when not set.
    var rowTitle: String { jobType?.label ?? "ROV entry" }

    /// "Vessel B · ROV System A".
    var vesselSystemLine: String { LogEntryCheck.joinedLine([vessel, rovSystem]) }

    var prefillCandidate: BookVesselPrefill.Candidate {
        BookVesselPrefill.Candidate(vessel: vessel ?? "", date: date, createdAt: createdAt)
    }
}
