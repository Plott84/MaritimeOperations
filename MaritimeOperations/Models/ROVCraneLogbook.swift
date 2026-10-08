import Foundation

// ROV and Crane books: picker options and the pure logic behind the forms.
// Foundation only (no SwiftUI / SwiftData), so it can be unit-tested on its own.
// Raw values are stored on the phone: never rename them. New options go at the END.

// MARK: - Multi-select storage

/// Multi-select chips stored as raw values joined with "|". Same format as AHTask.
/// Unknown raw values are dropped (never crash); order always follows `allCases`;
/// nothing picked is stored as nil so an untouched row stays nil.
enum LogChoiceSet {
    static let separator: Character = "|"

    static func decode<T: RawRepresentable & CaseIterable & Hashable>(_ raw: String?, as type: T.Type = T.self) -> Set<T>
    where T.RawValue == String {
        guard let raw, !raw.isEmpty else { return [] }
        return Set(raw.split(separator: separator).compactMap { T(rawValue: String($0)) })
    }

    static func encode<T: RawRepresentable & CaseIterable & Hashable>(_ values: Set<T>) -> String?
    where T.RawValue == String {
        let ordered = T.allCases.filter { values.contains($0) }
        guard !ordered.isEmpty else { return nil }
        return ordered.map(\.rawValue).joined(separator: String(separator))
    }
}

// MARK: - "Other" with text

/// A picker option that means "Other": picking it needs a short text before Save is enabled
/// (same rule as Rig Moves' "Other equipment").
protocol LogOtherChoice {
    var isOther: Bool { get }
}

enum LogOtherText {
    /// True when Other is picked but its text is still empty (Save stays disabled).
    static func isMissing(_ choice: (any LogOtherChoice)?, text: String) -> Bool {
        guard let choice, choice.isOther else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Text to store: trimmed text when Other is picked, else nil (so switching away clears it).
    static func stored(_ choice: (any LogOtherChoice)?, text: String) -> String? {
        guard let choice, choice.isOther else { return nil }
        return LogEntryCheck.optionalText(text)
    }

    /// Label of the first field whose Other text is missing, else nil. Save is enabled only when nil.
    static func firstMissing(_ fields: [(label: String, choice: (any LogOtherChoice)?, text: String)]) -> String? {
        fields.first { isMissing($0.choice, text: $0.text) }?.label
    }

    /// Save message for a missing Other text.
    static func message(for label: String) -> String {
        "\(label) is Other: type what it is."
    }
}

// MARK: - Position pickers

/// One option in a book's Position picker, stored as its raw value string.
/// CrewRank (Crane book) and ROVGrade (ROV book) conform; each book stores its pick in its own
/// optional raw-value property, so one LogPositionRow serves both.
protocol LogPositionChoice: Identifiable, Hashable, LogOtherChoice {
    var rawValue: String { get }
    /// Text in the menu and on the row ("2nd Off.").
    var pickerLabel: String { get }
    /// VoiceOver ("Second Officer").
    var spokenName: String { get }
}

extension CrewRank: LogPositionChoice {
    var pickerLabel: String { rawValue }
    var isOther: Bool { false }
}

/// Position list per book. Change a book's list here only.
enum BookPositions {
    /// ROV: IMCA ROV grades (C 005), not ship ranks. Under training covers trainees.
    static var rov: [ROVGrade] { ROVGrade.allCases }
    /// Crane: Crane operator first, then the AH order.
    static var crane: [CrewRank] { CrewRank.cranePositionCases }
}

/// ROV Position: IMCA ROV grades. Stored as an optional raw value (ROVEntry.gradeRaw).
/// No "Trainee": the Under training toggle covers it. "Other" needs text (ROVEntry.gradeOther).
/// Raw values are stored: never rename them. Keep `.other` last.
enum ROVGrade: String, CaseIterable, LogPositionChoice {
    case pilotTechnicianGradeII
    case pilotTechnicianGradeI
    case seniorPilotTechnician
    case supervisor
    case superintendent
    case toolingTechnician
    case toolingSupervisor
    case other

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .pilotTechnicianGradeII: return "ROV Pilot/Technician Grade II"
        case .pilotTechnicianGradeI: return "ROV Pilot/Technician Grade I"
        case .seniorPilotTechnician: return "ROV Senior Pilot/Technician"
        case .supervisor: return "ROV Supervisor"
        case .superintendent: return "ROV Superintendent"
        case .toolingTechnician: return "ROV Tooling Technician"
        case .toolingSupervisor: return "ROV Tooling Supervisor"
        case .other: return "Other"
        }
    }

    var spokenName: String {
        switch self {
        case .pilotTechnicianGradeII: return "R O V Pilot or Technician, Grade 2"
        case .pilotTechnicianGradeI: return "R O V Pilot or Technician, Grade 1"
        case .seniorPilotTechnician: return "R O V Senior Pilot or Technician"
        case .supervisor: return "R O V Supervisor"
        case .superintendent: return "R O V Superintendent"
        case .toolingTechnician: return "R O V Tooling Technician"
        case .toolingSupervisor: return "R O V Tooling Supervisor"
        case .other: return "Other"
        }
    }

    var isOther: Bool { self == .other }
}

/// ROV support site (IMCA R 004 §7.8). Optional: starts "Not set" and never blocks Save,
/// except "Other" with blank text. Stored as ROVEntry.supportSiteRaw (+ supportSiteOther).
/// Keep `.other` last.
enum ROVSupportSite: String, CaseIterable, Identifiable, LogOtherChoice {
    case vesselOnDP
    case vesselMoored
    case mobileOffshoreUnit
    case fixedInstallation
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vesselOnDP: return "Vessel on DP"
        case .vesselMoored: return "Vessel moored / anchored"
        case .mobileOffshoreUnit: return "Mobile offshore unit"
        case .fixedInstallation: return "Fixed installation"
        case .other: return "Other"
        }
    }

    var spokenLabel: String {
        switch self {
        case .vesselOnDP: return "Vessel on D P"
        case .vesselMoored: return "Vessel moored or anchored"
        default: return label
        }
    }

    var isOther: Bool { self == .other }
}

// MARK: - ROV pickers

/// ROV class (IMCA R 004 §3). Single pick, may be cleared.
enum ROVClass: String, CaseIterable, Identifiable {
    case one = "I"
    case two = "II"
    case three = "III"
    case four = "IV"
    case five = "V"

    var id: String { rawValue }

    /// Roman numeral shown on the segment.
    var label: String { rawValue }

    var name: String {
        switch self {
        case .one: return "Observation"
        case .two: return "Observation with payload option"
        case .three: return "Work-class"
        case .four: return "Towed / bottom-crawling"
        case .five: return "Prototype / development"
        }
    }

    /// "Class III · Work-class", the caption under the picker.
    var caption: String { "Class \(rawValue) · \(name)" }

    var spokenLabel: String {
        let number: String
        switch self {
        case .one: number = "1"
        case .two: number = "2"
        case .three: number = "3"
        case .four: number = "4"
        case .five: number = "5"
        }
        return "Class \(number), \(name)"
    }
}

/// ROV job type (IMCA R 004 §4.1–4.6). Single pick. Nil = not set.
enum ROVJobType: String, CaseIterable, Identifiable {
    case observation
    case survey
    case inspection
    case construction
    case intervention
    case burialTrenching

    var id: String { rawValue }

    var label: String {
        switch self {
        case .observation: return "Observation"
        case .survey: return "Survey"
        case .inspection: return "Inspection"
        case .construction: return "Construction"
        case .intervention: return "Intervention"
        case .burialTrenching: return "Burial & trenching"
        }
    }

    var spokenLabel: String {
        self == .burialTrenching ? "Burial and trenching" : label
    }
}

/// ROV "Tasks done" chips (multi-select), from Pixel's mock.
enum ROVTask: String, CaseIterable, Identifiable {
    case launchRecovery
    case tms
    case piloting
    case manipulator
    case torqueTool
    case inspection

    var id: String { rawValue }

    var label: String {
        switch self {
        case .launchRecovery: return "Launch & recovery"
        case .tms: return "TMS"
        case .piloting: return "Piloting"
        case .manipulator: return "Manipulator"
        case .torqueTool: return "Torque tool"
        case .inspection: return "Inspection"
        }
    }

    var spokenLabel: String {
        switch self {
        case .launchRecovery: return "Launch and recovery"
        case .tms: return "T M S, tether management system"
        default: return label
        }
    }
}

// MARK: - Crane pickers

/// Crane type (by duty). Single pick from a menu. Nil = not set. "Other" needs text (craneTypeOther).
/// Keep `.other` last.
enum CraneType: String, CaseIterable, Identifiable, LogOtherChoice {
    case offshore
    case subseaAHC
    case lightOffshore
    case deck
    case floating
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .offshore: return "Offshore crane"
        case .subseaAHC: return "Subsea / AHC crane"
        case .lightOffshore: return "Light offshore crane"
        case .deck: return "Deck crane"
        case .floating: return "Floating crane"
        case .other: return "Other"
        }
    }

    var spokenLabel: String {
        self == .subseaAHC ? "Subsea or active heave compensated crane" : label
    }

    var isOther: Bool { self == .other }
}

/// Crane lift types (multi-select chips).
enum CraneLiftType: String, CaseIterable, Identifiable {
    case deck
    case supplyVessel
    case overside
    case subsea
    case blind
    case tandem
    case personnel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deck: return "Deck"
        case .supplyVessel: return "Supply vessel"
        case .overside: return "Overside"
        case .subsea: return "Subsea"
        case .blind: return "Blind"
        case .tandem: return "Tandem"
        case .personnel: return "Personnel"
        }
    }

    var spokenLabel: String { "\(label) lift" }
}

/// Day / Night / Both (G5 logbook column "Natt/Dag"). Nil = not set.
enum CraneDayNight: String, CaseIterable, Identifiable {
    case day
    case night
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Day"
        case .night: return "Night"
        case .both: return "Both"
        }
    }

    var spokenLabel: String { self == .both ? "Day and night" : label }
}

/// Crane mode. Takes the AH "DP or Manual" slot. Nil = not set.
enum CraneMode: String, CaseIterable, Identifiable {
    case normal
    case ahc
    case constantTension

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .ahc: return "AHC"
        case .constantTension: return "Constant tension"
        }
    }

    var spokenLabel: String {
        self == .ahc ? "Active heave compensation" : label
    }
}

// MARK: - Numbers

/// Typed numbers on the ROV and Crane forms. Empty = not set (nil). Junk blocks Save.
enum LogNumber {
    /// Hours at the controls for one entry (one shift): 0…24, comma or dot decimal.
    static let maxHoursPerEntry: Double = 24

    /// Decimal ≥ 0, comma or dot. Empty, negative, junk → nil.
    static func decimal(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// Hours for one entry: decimal from 0 to 24.
    static func hours(_ raw: String) -> Double? {
        guard let value = decimal(raw), value <= maxHoursPerEntry else { return nil }
        return value
    }

    /// Whole number ≥ 0 ("2"). "1.5", "-1", junk → nil.
    static func count(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    /// Text for a stored value: "3.5", "12". Empty for nil.
    static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        nf.usesGroupingSeparator = false
        nf.decimalSeparator = "."
        return nf.string(from: NSNumber(value: value)) ?? ""
    }

    static func text(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    static func isBlank(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// ROV form numbers. `firstProblem` is the Save message, or nil when Save may go ahead.
struct ROVNumberInput {
    var pilotingHours: String
    var dives: String

    var pilotingHoursValue: Double? { LogNumber.hours(pilotingHours) }
    var divesValue: Int? { LogNumber.count(dives) }

    var firstProblem: String? {
        if !LogNumber.isBlank(pilotingHours), pilotingHoursValue == nil {
            return "Piloting hours must be a number from 0 to 24."
        }
        if !LogNumber.isBlank(dives), divesValue == nil {
            return "Dives must be a whole number."
        }
        return nil
    }
}

/// Crane form numbers.
struct CraneNumberInput {
    var hoursOperated: String
    var wind: String
    var waveHeight: String

    var hoursOperatedValue: Double? { LogNumber.hours(hoursOperated) }
    var windValue: Double? { LogNumber.decimal(wind) }
    var waveHeightValue: Double? { LogNumber.decimal(waveHeight) }

    var firstProblem: String? {
        if !LogNumber.isBlank(hoursOperated), hoursOperatedValue == nil {
            return "Hours operated must be a number from 0 to 24."
        }
        if !LogNumber.isBlank(wind), windValue == nil {
            return "Wind must be a number."
        }
        if !LogNumber.isBlank(waveHeight), waveHeightValue == nil {
            return "Wave height must be a number."
        }
        return nil
    }
}

// MARK: - Save rule and copy

enum LogEntryCheck {
    /// Start is the only required field (it always has a value). End may not be before start.
    static func block(start: Date, end: Date) -> String? {
        end < start ? "End is before start." : nil
    }

    /// Optional text: trimmed, or nil when empty, so untouched fields stay nil.
    static func optionalText(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Same rule as the AH form: on → true; off → false only if it was set before, else stays nil.
    static func underTraining(isOn: Bool, previous: Bool?) -> Bool? {
        isOn ? true : (previous == nil ? nil : false)
    }

    /// "Vessel B · ROV System A", skipping empty parts.
    static func joinedLine(_ parts: [String?]) -> String {
        parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

// MARK: - Vessel prefill (all four books)

/// Vessel a NEW DP-book-family entry starts with: the ship of the newest DP line, AH, ROV or
/// Crane entry (by its own date; ties go to the later-created record), skipping records
/// without a ship. Only the vessel is prefilled. Position always starts "Not set".
/// Same rule as `AHVesselPrefill`, widened to four books.
enum BookVesselPrefill {
    struct Candidate: Equatable {
        var vessel: String
        var date: Date
        var createdAt: Date
    }

    static func vessel(from candidates: [Candidate]) -> String {
        candidates
            .compactMap { c -> (String, Candidate)? in
                let name = c.vessel.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : (name, c)
            }
            .max { lhs, rhs in
                if lhs.1.date != rhs.1.date { return lhs.1.date < rhs.1.date }
                return lhs.1.createdAt < rhs.1.createdAt
            }?
            .0 ?? ""
    }
}
