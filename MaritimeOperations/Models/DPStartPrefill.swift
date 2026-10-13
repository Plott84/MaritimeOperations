import Foundation
import SwiftData

/// Vessel and DP class for a new watch, copied from the latest DP line.
/// Hours, times, activity and notes are not part of this value.
/// `updatedAt` is ignored, so editing an older line does not change which line is used.
nonisolated enum DPStartPrefill {
    static let title = "START DP · NEW WATCH"
    static let fromLastEntry = "From your last entry"
    static let noPreviousEntry = "No previous entry"
    static let addVessel = "Add vessel"
    static let chooseClass = "Choose DP class"

    struct Candidate: Equatable {
        var vessel: String
        var dpClassLevel: Int?
        var dpClassText: String
        var date: Date
        var createdAt: Date
    }

    struct Draft: Equatable {
        var vessel: String
        var dpClassLevel: Int?
        var hasPreviousEntry: Bool
    }

    static func make(from candidates: [Candidate]) -> Draft {
        guard let latest = candidates.max(by: { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.createdAt < rhs.createdAt
        }) else {
            return Draft(vessel: "", dpClassLevel: nil, hasPreviousEntry: false)
        }
        return Draft(
            vessel: cleanedVessel(latest.vessel),
            dpClassLevel: DPDaysCount.classLevel(stored: latest.dpClassLevel, text: latest.dpClassText),
            hasPreviousEntry: true
        )
    }

    @MainActor
    static func make(from entries: [DPEntry]) -> Draft {
        make(from: entries.map {
            Candidate(
                vessel: $0.vessel,
                dpClassLevel: $0.dpClassLevel,
                dpClassText: $0.dpClass,
                date: $0.date,
                createdAt: $0.createdAt
            )
        })
    }

    /// The placeholder ship name used by older saves is not a real vessel.
    static func cleanedVessel(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if trimmed.compare("Vessel", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return ""
        }
        return trimmed
    }
}
