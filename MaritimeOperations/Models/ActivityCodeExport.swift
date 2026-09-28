import Foundation

/// The one place that turns a stored activity code into export text.
/// Use this for any PDF / share / summary output.
enum ActivityCodeExport {
    static func text(for stored: String?) -> String {
        let trimmed = (stored ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let mine = MyActivityCode(rawValue: trimmed) {
            return mine.exportText
        }
        return trimmed
    }
}
