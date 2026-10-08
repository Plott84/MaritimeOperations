import Foundation

/// Distinct ship names from saved lines, most recently used first. No model of its own.
enum ShipNameSuggestions {
    struct Use {
        let name: String
        let usedAt: Date
    }

    /// Same ship when equal after trimming, ignoring case.
    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive], locale: nil)
    }

    /// One name per ship, spelled as in its most recent use, newest first.
    static func names(from uses: [Use]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for use in uses.sorted(by: { $0.usedAt > $1.usedAt }) {
            let name = use.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let k = key(name)
            guard !name.isEmpty, k != key("Vessel"), !seen.contains(k) else { continue }
            seen.insert(k)
            result.append(name)
        }
        return result
    }

    static func names(from entries: [DPEntry]) -> [String] {
        names(from: entries.map { Use(name: $0.vessel, usedAt: $0.updatedAt) })
    }

    static func filter(_ names: [String], query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return names }
        return names.filter { $0.localizedCaseInsensitiveContains(q) }
    }
}
