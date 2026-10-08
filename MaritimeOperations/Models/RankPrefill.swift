import Foundation

/// Which rank a new DP line starts with: the rank of the line with the latest DP date
/// (`DPEntry.date`), skipping lines without a rank. Ties go to the later-created line.
/// `updatedAt` is deliberately ignored so editing an old line never changes the prefill.
enum RankPrefill {
    struct Candidate: Equatable {
        var rank: String?
        var dpDate: Date
        var createdAt: Date
    }

    static func rank(from candidates: [Candidate]) -> String {
        candidates
            .compactMap { candidate -> (rank: String, candidate: Candidate)? in
                let trimmed = candidate.rank?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : (trimmed, candidate)
            }
            .max { lhs, rhs in
                if lhs.candidate.dpDate != rhs.candidate.dpDate {
                    return lhs.candidate.dpDate < rhs.candidate.dpDate
                }
                return lhs.candidate.createdAt < rhs.candidate.createdAt
            }?
            .rank ?? ""
    }

    static func rank(from entries: [DPEntry]) -> String {
        rank(from: entries.map { Candidate(rank: $0.rank, dpDate: $0.date, createdAt: $0.createdAt) })
    }
}
