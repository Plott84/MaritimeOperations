import Foundation
import SwiftData

/// One Crane book entry (one shift on one crane, like a G5 logbook row). Start (`date`) is the
/// only required field; everything else is optional with a nil default and starts empty on a new
/// entry, except the vessel, which the form prefills (BookVesselPrefill).
@Model
final class CraneEntry {
    var id: UUID = UUID()
    /// Start date and time. Required. Also the sort and prefill date.
    var date: Date = Date.now
    var endTime: Date? = nil
    var vessel: String? = nil
    /// CrewRank raw value (AH Position list). Nil = "Not set".
    var rank: String? = nil
    var underTraining: Bool? = nil
    /// Crane name / ID as signed on board. Free text.
    var craneName: String? = nil
    /// CraneType raw value.
    var craneTypeRaw: String? = nil
    /// Text for crane type "Other". Nil unless the type is Other.
    var craneTypeOther: String? = nil
    /// Field or area name only. No coordinates.
    var fieldArea: String? = nil
    /// Own time at the controls, typed by hand. Not the shift length.
    var hoursOperated: Double? = nil
    /// CraneLiftType raw values joined with "|". Nil = none picked.
    var liftTypesRaw: String? = nil
    /// CraneDayNight raw value.
    var dayNightRaw: String? = nil
    /// Own observation, metres per second.
    var windMS: Double? = nil
    /// Own observation (Hs), metres.
    var waveHeightM: Double? = nil
    /// CraneMode raw value.
    var craneModeRaw: String? = nil
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

extension CraneEntry {
    var craneType: CraneType? {
        get { craneTypeRaw.flatMap(CraneType.init(rawValue:)) }
        set { craneTypeRaw = newValue?.rawValue }
    }

    var liftTypes: Set<CraneLiftType> {
        get { LogChoiceSet.decode(liftTypesRaw) }
        set { liftTypesRaw = LogChoiceSet.encode(newValue) }
    }

    /// "Offshore crane", or the typed text for Other.
    var craneTypeLabel: String? {
        guard let craneType else { return nil }
        return craneType.isOther ? (craneTypeOther ?? craneType.label) : craneType.label
    }

    var dayNight: CraneDayNight? {
        get { dayNightRaw.flatMap(CraneDayNight.init(rawValue:)) }
        set { dayNightRaw = newValue?.rawValue }
    }

    var craneMode: CraneMode? {
        get { craneModeRaw.flatMap(CraneMode.init(rawValue:)) }
        set { craneModeRaw = newValue?.rawValue }
    }

    var crewRank: CrewRank? { rank.flatMap(CrewRank.init(rawValue:)) }

    var durationHours: Double? {
        guard let endTime, endTime >= date else { return nil }
        return endTime.timeIntervalSince(date) / 3600
    }

    /// Row title: lift types in fixed order ("Deck, Supply vessel"), or "Crane entry".
    var rowTitle: String {
        let picked = CraneLiftType.allCases.filter { liftTypes.contains($0) }.map(\.label)
        return picked.isEmpty ? "Crane entry" : picked.joined(separator: ", ")
    }

    /// "Vessel B · Crane A".
    var vesselCraneLine: String { LogEntryCheck.joinedLine([vessel, craneName]) }

    var prefillCandidate: BookVesselPrefill.Candidate {
        BookVesselPrefill.Candidate(vessel: vessel ?? "", date: date, createdAt: createdAt)
    }
}

extension BookVesselPrefill {
    /// Newest ship across all four books.
    static func vessel(
        dpLines: [DPEntry],
        ahEntries: [RigMove],
        rovEntries: [ROVEntry],
        craneEntries: [CraneEntry]
    ) -> String {
        vessel(from:
            dpLines.map { Candidate(vessel: $0.vessel, date: $0.date, createdAt: $0.createdAt) }
            + ahEntries.map { Candidate(vessel: $0.vessel, date: $0.date, createdAt: $0.createdAt) }
            + rovEntries.map(\.prefillCandidate)
            + craneEntries.map(\.prefillCandidate)
        )
    }

    /// Ship names for the "Pick a logged ship" sheet, from all four books, newest first.
    static func loggedShipNames(
        dpLines: [DPEntry],
        ahEntries: [RigMove],
        rovEntries: [ROVEntry],
        craneEntries: [CraneEntry]
    ) -> [String] {
        ShipNameSuggestions.names(
            from: dpLines.map { ShipNameSuggestions.Use(name: $0.vessel, usedAt: $0.updatedAt) }
                + ahEntries.map { ShipNameSuggestions.Use(name: $0.vessel, usedAt: $0.createdAt) }
                + rovEntries.map { ShipNameSuggestions.Use(name: $0.vessel ?? "", usedAt: $0.updatedAt) }
                + craneEntries.map { ShipNameSuggestions.Use(name: $0.vessel ?? "", usedAt: $0.updatedAt) }
        )
    }
}
