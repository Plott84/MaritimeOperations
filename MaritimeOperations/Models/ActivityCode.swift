import Foundation

/// Activity codes from the IMCA DP Logbook, Part 7, in book order.
/// Only codes are shown for now: meanings are pending verified wording (see `title`).
enum ActivityCode: String, CaseIterable, Identifiable {
    case accomm = "ACCOMM"
    case a = "A"
    case d = "D"
    case drill = "DRILL"
    case fl = "FL"
    case hl = "HL"
    case ol = "OL"
    case pl = "PL"
    case psv = "PSV"
    case rov = "ROV"
    case sb = "SB"
    case tr = "TR"
    case wk = "WK"
    case ws = "WS"
    case ot = "OT"

    var id: String { rawValue }

    /// OT needs a short "Specify" text before a line can be saved.
    var needsSpecify: Bool { self == .ot }

    /// Optional description shown after the code in the menu. All nil until the wording
    /// is verified against the IMCA logbook; add a case here to fill one in.
    var title: String? {
        switch self {
        default: return nil
        }
    }

    /// "CODE – title" when a title is set, else just "CODE".
    var menuLabel: String {
        guard let title, !title.isEmpty else { return rawValue }
        return "\(rawValue) – \(title)"
    }
}

/// Henning's own codes. Not in the book. Stored as the raw value ("AH"); shown in the menu
/// and exported in logbook form ("OT – Anchor handling"). Listed at the bottom, right after OT.
enum MyActivityCode: String, CaseIterable, Identifiable {
    case ah = "AH"

    var id: String { rawValue }

    var meaning: String {
        switch self {
        case .ah: return "Anchor handling"
        }
    }

    /// Menu label: reads like the logbook entry it becomes.
    var menuTitle: String { exportText }

    /// How the code reads in anything exported, since the book has no AH.
    var exportText: String {
        switch self {
        case .ah: return "\(ActivityCode.ot.rawValue) – \(meaning)"
        }
    }
}

/// Code rows of the activity code menu, in display order: the 15 book codes (OT last),
/// then "OT – Anchor handling". No section headers.
enum ActivityCodeMenu {
    struct Option: Identifiable, Equatable {
        /// Picker tag and stored value: a code raw value, or a MyActivityCode raw value ("AH").
        /// (For OT the stored value adds " – <specify>".)
        let tag: String
        let label: String
        var id: String { tag }
    }

    static var options: [Option] {
        ActivityCode.allCases.map { Option(tag: $0.rawValue, label: $0.menuLabel) }
            + MyActivityCode.allCases.map { Option(tag: $0.rawValue, label: $0.menuTitle) }
    }
}
