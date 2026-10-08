import Foundation

// Anchor handling (AH) fields stored on the existing RigMove record.
// Every AH property on RigMove is optional with a nil default, so rows saved before these
// fields existed load unchanged (SwiftData lightweight migration) and never block saving.

/// Job type picker. Nil on a row means "Rig move" (older rows, and the default for new rows).
enum AHJobType: String, CaseIterable, Identifiable {
    case rigMove = "rigMove"
    case preLay = "preLay"
    case rigTow = "rigTow"
    case otherAH = "otherAH"

    var id: String { rawValue }

    static let `default`: AHJobType = .rigMove

    var label: String {
        switch self {
        case .rigMove: return "Rig move"
        case .preLay: return "Pre-lay"
        case .rigTow: return "Rig tow"
        case .otherAH: return "Other AH"
        }
    }

    var spokenLabel: String {
        self == .otherAH ? "Other anchor handling" : label
    }
}

enum AHUnitType: String, CaseIterable, Identifiable {
    case semiSubmersible = "semiSubmersible"
    case jackUp = "jackUp"
    case barge = "barge"
    case mooredFloating = "mooredFloating"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .semiSubmersible: return "Semi-submersible"
        case .jackUp: return "Jack-up"
        case .barge: return "Barge"
        case .mooredFloating: return "Moored floating installation"
        case .other: return "Other"
        }
    }
}

/// Tasks done chips (multi-select). Stored as raw values joined with "|".
enum AHTask: String, CaseIterable, Identifiable {
    case recoverAnchor = "recoverAnchor"
    case runAnchor = "runAnchor"
    case receivePCP = "receivePCP"
    case deliverPCP = "deliverPCP"
    case chaseOutBack = "chaseOutBack"
    case deckAnchor = "deckAnchor"
    case piggyback = "piggyback"
    case buoyOff = "buoyOff"
    case towConnect = "towConnect"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recoverAnchor: return "Recover anchor"
        case .runAnchor: return "Run anchor"
        case .receivePCP: return "Receive PCP"
        case .deliverPCP: return "Deliver PCP"
        case .chaseOutBack: return "Chase out/back"
        case .deckAnchor: return "Deck anchor"
        case .piggyback: return "Piggyback"
        case .buoyOff: return "Buoy off"
        case .towConnect: return "Tow connect"
        }
    }

    var spokenLabel: String {
        switch self {
        case .receivePCP: return "Receive permanent chaser pennant"
        case .deliverPCP: return "Deliver permanent chaser pennant"
        case .chaseOutBack: return "Chase out or back"
        default: return label
        }
    }

    static let separator: Character = "|"

    /// Unknown raw values are dropped, never crash. Order follows `allCases`.
    static func decode(_ raw: String?) -> Set<AHTask> {
        guard let raw, !raw.isEmpty else { return [] }
        return Set(raw.split(separator: separator).compactMap { AHTask(rawValue: String($0)) })
    }

    /// Nil when nothing is picked, so an untouched row stays nil.
    static func encode(_ tasks: Set<AHTask>) -> String? {
        let ordered = allCases.filter { tasks.contains($0) }
        guard !ordered.isEmpty else { return nil }
        return ordered.map(\.rawValue).joined(separator: String(separator))
    }
}

enum AHControlMode: String, CaseIterable, Identifiable {
    case dp = "dp"
    case manual = "manual"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dp: return "DP"
        case .manual: return "Manual"
        }
    }
}

enum AHNumber {
    /// Optional number field: empty → nil; comma or dot decimal; negatives and junk → nil.
    static func parse(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// Text for a stored value: "120", "1.5". Empty for nil.
    static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        nf.usesGroupingSeparator = false
        nf.decimalSeparator = "."
        return nf.string(from: NSNumber(value: value)) ?? ""
    }
}

enum AHFormat {
    /// "11 h 30 min", "45 min", "6 h". Nil when end is before start.
    static func duration(start: Date, end: Date) -> String? {
        guard end >= start else { return nil }
        let minutes = Int((end.timeIntervalSince(start) / 60).rounded())
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }
}

extension RigMove {
    /// Nil or unknown stored value reads as Rig move, so older rows show as rig moves.
    var ahJobType: AHJobType {
        get { ahJobTypeRaw.flatMap(AHJobType.init(rawValue:)) ?? .default }
        set { ahJobTypeRaw = newValue.rawValue }
    }

    var ahUnitType: AHUnitType? {
        get { ahUnitTypeRaw.flatMap(AHUnitType.init(rawValue:)) }
        set { ahUnitTypeRaw = newValue?.rawValue }
    }

    var ahTasks: Set<AHTask> {
        get { AHTask.decode(ahTasksRaw) }
        set { ahTasksRaw = AHTask.encode(newValue) }
    }

    var ahControlMode: AHControlMode? {
        get { ahControlModeRaw.flatMap(AHControlMode.init(rawValue:)) }
        set { ahControlModeRaw = newValue?.rawValue }
    }

    /// Rank picked on this row, if it is a known rank.
    var crewRank: CrewRank? { CrewRank(rawValue: rank) }

    /// True when anything in the form's "More details" section has a value (opens it on edit).
    var hasAHMoreDetails: Bool {
        ahSupervised != nil || anchorLineCount > 0
            || !(ahAnchorIDs ?? "").isEmpty || ahWaterDepthM != nil
            || ahMaxPaidOutM != nil || ahPeakTensionT != nil
            || ahWaveHeightM != nil || ahWindKn != nil
            || !(ahWindDirection ?? "").isEmpty
            || !client.isEmpty || !fromLocation.isEmpty || !toLocation.isEmpty
            || hasChain || hasWire || hasFiber || hasSubBuoys || hasOther
            || photoJPEG != nil || isDone
            || operation != .anchorHandling
    }

    /// "Rig A · Vessel B", skipping empty parts.
    var rigVesselLine: String {
        [rigName, vessel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// Yes / No / not set, for "Supervised". Not set is not the same as No.
enum AHYesNo: String, CaseIterable, Identifiable {
    case yes
    case no

    var id: String { rawValue }

    init?(_ value: Bool?) {
        guard let value else { return nil }
        self = value ? .yes : .no
    }

    var boolValue: Bool { self == .yes }

    var label: String { self == .yes ? "Yes" : "No" }
}

enum AHText {
    /// Trimmed text, or nil when empty, so untouched text fields stay nil.
    static func optional(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Typed number fields on the AH form. Empty is fine (not set); junk text blocks Save with a message.
struct AHNumberInput {
    var anchorCount: String
    var waterDepth: String
    var paidOut: String
    var tension: String
    var waveHeight: String
    var wind: String

    var anchorCountValue: Int? {
        let trimmed = anchorCount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    var waterDepthValue: Double? { AHNumber.parse(waterDepth) }
    var paidOutValue: Double? { AHNumber.parse(paidOut) }
    var tensionValue: Double? { AHNumber.parse(tension) }
    var waveHeightValue: Double? { AHNumber.parse(waveHeight) }
    var windValue: Double? { AHNumber.parse(wind) }

    /// UI label of the first filled-in field that isn't a valid number, else nil.
    var firstInvalidField: String? {
        func bad(_ text: String, _ valid: Bool) -> Bool {
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !valid
        }
        if bad(anchorCount, anchorCountValue != nil) { return "Anchor count" }
        if bad(waterDepth, waterDepthValue != nil) { return "Water depth" }
        if bad(paidOut, paidOutValue != nil) { return "Max wire paid out" }
        if bad(tension, tensionValue != nil) { return "Peak tension" }
        if bad(waveHeight, waveHeightValue != nil) { return "Wave height" }
        if bad(wind, windValue != nil) { return "Wind" }
        return nil
    }
}

/// Vessel a NEW Anchor handling entry starts with: the ship of the newest DP line or AH entry
/// (by its own date; ties go to the later-created record), skipping records without a ship.
/// Only the vessel is prefilled. Position / rank always starts empty ("Not set").
enum AHVesselPrefill {
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

    static func vessel(dpLines: [DPEntry], ahEntries: [RigMove]) -> String {
        vessel(from: dpLines.map { Candidate(vessel: $0.vessel, date: $0.date, createdAt: $0.createdAt) }
            + ahEntries.map { Candidate(vessel: $0.vessel, date: $0.date, createdAt: $0.createdAt) })
    }
}
