import Foundation

/// Activity codes from the IMCA DP Logbook, Part 7, in book order.
/// Only codes are shown: the repo has no sourced meanings for them.
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
}

/// Henning's own codes, shown under "My codes". Not in the book.
enum MyActivityCode: String, CaseIterable, Identifiable {
    case ah = "AH"

    var id: String { rawValue }

    var meaning: String {
        switch self {
        case .ah: return "Anchor handling"
        }
    }

    var menuTitle: String { "\(rawValue) – \(meaning)" }

    /// How the code reads in anything exported, since the book has no AH.
    var exportText: String {
        switch self {
        case .ah: return "\(ActivityCode.ot.rawValue) – \(meaning)"
        }
    }
}
