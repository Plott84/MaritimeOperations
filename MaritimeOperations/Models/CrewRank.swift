import Foundation

/// Optional rank on a DP line or rig move. Stored as its raw String (DPEntry.rank, RigMove.rank).
/// Raw values are stored on the phone: never rename them. New ranks go at the END.
enum CrewRank: String, CaseIterable, Identifiable {
    case engineer = "Eng."
    case chiefEngineer = "Ch. Eng."
    case electrician = "Elec."
    case dpo = "DPO"
    case chiefOfficer = "Ch. Off."
    case secondOfficer = "2nd Off."
    case master = "Master"
    // Added for the Anchor handling Position picker only.
    case secondEngineer = "2nd Eng."
    case thirdEngineer = "3rd Eng."
    case ableSeaman = "AB"
    // Added for the Crane book Position picker only.
    case craneOperator = "Crane operator"

    var id: String { rawValue }

    /// DP line rank picker. Unchanged list and order: the AH-only ranks are left out.
    static let dpPickerCases: [CrewRank] = [
        .engineer, .chiefEngineer, .electrician, .dpo, .chiefOfficer, .secondOfficer, .master
    ]

    /// Anchor handling Position picker: deck officers, then engineers, then AB.
    /// Unchanged: Crane operator is left out.
    static let ahPositionCases: [CrewRank] = [
        .master, .chiefOfficer, .secondOfficer, .dpo,
        .chiefEngineer, .secondEngineer, .thirdEngineer, .engineer, .electrician,
        .ableSeaman
    ]

    /// Crane book Position picker: Crane operator first, then the AH order.
    static let cranePositionCases: [CrewRank] = [.craneOperator] + ahPositionCases

    /// Spoken name for VoiceOver (abbreviations read badly).
    var spokenName: String {
        switch self {
        case .engineer: return "Engineer"
        case .chiefEngineer: return "Chief Engineer"
        case .electrician: return "Electrician"
        case .dpo: return "D P O"
        case .chiefOfficer: return "Chief Officer"
        case .secondOfficer: return "Second Officer"
        case .master: return "Master"
        case .secondEngineer: return "Second Engineer"
        case .thirdEngineer: return "Third Engineer"
        case .ableSeaman: return "Able Seaman"
        case .craneOperator: return "Crane operator"
        }
    }
}
