import Foundation

/// Always-on personal-aid disclaimer for the Export tab and export files.
/// Exact Pixel string — do not soften, shorten, or bury.
enum ExportDisclaimer {
    static let text =
        "Personal aid only. This export is not an official IMCA DP Logbook record, and it is not a sign-off or certificate."

    static let booksCaption = "ROV and Crane hours are never added to DP totals."
    static let previewFooter = "DP hours are only from the DP book."
    static let emptyPreview = "No entries in this range"
    static let emptyShareMessage = "No entries in this range. Nothing to share."
}
