import Foundation

enum DPEntrySource: String, Codable, CaseIterable, Identifiable {
    case timed
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .timed: return "Timed session"
        case .manual: return "Manual"
        }
    }
}
