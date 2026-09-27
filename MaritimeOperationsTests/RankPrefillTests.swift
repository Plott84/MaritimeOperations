import Testing
import Foundation
@testable import MaritimeOperations

@MainActor
struct RankPrefillTests {
    private func day(_ n: Double) -> Date { Date(timeIntervalSince1970: 1_750_000_000 + n * 86_400) }

    private func candidate(_ rank: String?, dpDay: Double, createdDay: Double) -> RankPrefill.Candidate {
        RankPrefill.Candidate(rank: rank, dpDate: day(dpDay), createdAt: day(createdDay))
    }

    @Test func latestDPDateWinsOverLaterCreatedOlderLine() {
        // Catch-up line for an old watch, created after the newest watch was logged.
        let rank = RankPrefill.rank(from: [
            candidate("DPO", dpDay: 10, createdDay: 10),
            candidate("Master", dpDay: 2, createdDay: 12),
        ])
        #expect(rank == "DPO")
    }

    @Test func editingAnOlderLineDoesNotChangePrefill() {
        let newest = DPEntry(source: .manual, date: day(10), durationHours: 2, vessel: "Far Sun",
                             rank: "DPO", createdAt: day(10), updatedAt: day(10))
        let olderEditedLater = DPEntry(source: .manual, date: day(3), durationHours: 2, vessel: "Skandi Africa",
                                       rank: "Ch. Off.", createdAt: day(11), updatedAt: day(20))
        #expect(RankPrefill.rank(from: [olderEditedLater, newest]) == "DPO")
        #expect(RankPrefill.rank(from: [newest, olderEditedLater]) == "DPO")
    }

    @Test func emptyRanksAreSkipped() {
        let rank = RankPrefill.rank(from: [
            candidate("Ch. Eng.", dpDay: 1, createdDay: 1),
            candidate(nil, dpDay: 9, createdDay: 9),
            candidate("", dpDay: 8, createdDay: 8),
            candidate("   ", dpDay: 7, createdDay: 7),
        ])
        #expect(rank == "Ch. Eng.")
    }

    @Test func tieOnDPDateGoesToLaterCreated() {
        let rank = RankPrefill.rank(from: [
            candidate("Elec.", dpDay: 5, createdDay: 9),
            candidate("Eng.", dpDay: 5, createdDay: 6),
        ])
        #expect(rank == "Elec.")
    }

    @Test func noRankedLinesGivesEmpty() {
        #expect(RankPrefill.rank(from: [RankPrefill.Candidate]()) == "")
        #expect(RankPrefill.rank(from: [candidate(nil, dpDay: 1, createdDay: 1)]) == "")
    }
}
