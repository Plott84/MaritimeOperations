import Foundation

/// Optional rank on a DP line. Stored as its raw String on DPEntry.rank.
enum CrewRank: String, CaseIterable, Identifiable {
    case engineer = "Eng."
    case chiefEngineer = "Ch. Eng."
    case electrician = "Elec."
    case dpo = "DPO"
    case chiefOfficer = "Ch. Off."
    case master = "Master"

    var id: String { rawValue }
}
