import Foundation

/// Shared number parsing for Tools screens (comma → dot, trim).
enum ToolsParse {
    /// Parses a finite Double from user text. Empty / non-numeric → nil.
    static func double(_ raw: String) -> Double? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }
        guard let v = Double(trimmed), v.isFinite else { return nil }
        return v
    }

    /// Empty string → nil (optional field). Non-empty must parse.
    static func optionalDouble(_ raw: String) -> Double?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .some(nil) }
        guard let v = double(raw) else { return nil }
        return .some(v)
    }

    static func format(_ value: Double, decimals: Int = 1) -> String {
        guard value.isFinite else { return "—" }
        return String(format: "%.\(decimals)f", value)
    }

    static let dash = "—"
}
