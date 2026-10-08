import Foundation

// Log tab books, starred-books storage and card totals. Moved here from LogView.swift
// (unchanged for DP and Anchor handling) and widened to ROV and Crane.

/// A book on the Log tab. Raw values are stored (starred books): never rename them.
/// New books go at the END so the Log order is DP, Anchor handling, ROV, Crane.
enum LogBook: String, CaseIterable, Identifiable, Hashable {
    case dp
    case anchorHandling
    case rov
    case crane

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dp: return "DP"
        case .anchorHandling: return "Anchor handling"
        case .rov: return "ROV"
        case .crane: return "Crane"
        }
    }

    var spokenTitle: String {
        switch self {
        case .dp: return "D P"
        case .anchorHandling: return "Anchor handling"
        case .rov: return "R O V"
        case .crane: return "Crane"
        }
    }

    var subtitle: String {
        switch self {
        case .dp: return "DP sessions · hours"
        case .anchorHandling: return "Rig moves · rows"
        case .rov: return "ROV dives · piloting hours"
        case .crane: return "Crane work · hours operated"
        }
    }

    /// Letters on the small badge on Main's "Your books" rows (default text sizes).
    var badge: String {
        switch self {
        case .dp: return "DP"
        case .anchorHandling: return "AH"
        case .rov: return "ROV"
        case .crane: return "CR"
        }
    }

    /// SF Symbol for DP. The other books draw their own icon (see LogBookIcon); SF Symbols has
    /// no anchor, ROV or crane.
    var systemImage: String? {
        switch self {
        case .dp: return "location.north"
        case .anchorHandling, .rov, .crane: return nil
        }
    }
}

/// Which books show on Main. Stored as raw values joined with ",". Default: DP.
enum StarredBooks {
    static let storageKey = "log.starredBooks"
    static let defaultRaw = LogBook.dp.rawValue

    static func decode(_ raw: String) -> [LogBook] {
        let picked = Set(raw.split(separator: ",").compactMap { LogBook(rawValue: String($0)) })
        return LogBook.allCases.filter { picked.contains($0) }
    }

    static func encode(_ books: [LogBook]) -> String {
        LogBook.allCases.filter { books.contains($0) }.map(\.rawValue).joined(separator: ",")
    }

    static func toggled(_ book: LogBook, in raw: String) -> String {
        var books = decode(raw)
        if let index = books.firstIndex(of: book) {
            books.remove(at: index)
        } else {
            books.append(book)
        }
        return encode(books)
    }

    /// Books Main shows: the starred ones, or DP when nothing is starred.
    static func shownOnMain(_ raw: String) -> [LogBook] {
        let books = decode(raw)
        return books.isEmpty ? [.dp] : books
    }
}

/// Which books feed DP hours: the DP total (DP book, Log and Main cards) and the DP export
/// (when it is built, it must take its lines from here). Only DP lines. ROV piloting hours,
/// Crane hours operated and AH rows never count toward DP and never appear in the DP export.
enum DPHoursScope {
    static let books: Set<LogBook> = [.dp]

    static func counts(_ book: LogBook) -> Bool { books.contains(book) }
}

/// Totals shown on book cards (Log and Main). The model-based initialiser lives in LogView.swift.
struct LogBookStats: Equatable {
    var dpHours: Double = 0
    var dpEntries: Int = 0
    var rigMoves: Int = 0
    /// Sum of typed piloting hours (blank entries count 0).
    var rovPilotingHours: Double = 0
    var rovEntries: Int = 0
    /// Sum of typed hours operated (blank entries count 0).
    var craneHours: Double = 0
    var craneEntries: Int = 0

    /// Typed "Old DP hours" text → hours. Junk or empty → 0.
    static func oldDPHours(_ text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(trimmed.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    static func hoursNumber(_ hours: Double) -> String {
        hours.formatted(.number.precision(.fractionLength(1)))
    }

    static func entriesText(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }

    /// Hours shown big on the card, or nil for books without hours (Anchor handling).
    func hours(for book: LogBook) -> Double? {
        switch book {
        case .dp: return dpHours
        case .anchorHandling: return nil
        case .rov: return rovPilotingHours
        case .crane: return craneHours
        }
    }

    /// Small word after the hours on the Log card ("86.0 h total").
    func hoursCaption(for book: LogBook) -> String {
        switch book {
        case .dp: return "total"
        case .anchorHandling: return ""
        case .rov: return "piloting"
        case .crane: return "operated"
        }
    }

    func count(for book: LogBook) -> Int {
        switch book {
        case .dp: return dpEntries
        case .anchorHandling: return rigMoves
        case .rov: return rovEntries
        case .crane: return craneEntries
        }
    }

    /// Count caption on the Log card ("12 entries" → caption "entries").
    func countCaption(for book: LogBook) -> String {
        let n = count(for: book)
        if book == .anchorHandling { return n == 1 ? "rig move" : "rig moves" }
        return n == 1 ? "entry" : "entries"
    }

    /// VoiceOver value of a Log card. DP and AH copy is unchanged from the AH build (UI tests read it).
    func logSpokenValue(for book: LogBook) -> String {
        switch book {
        case .dp:
            return "\(Self.hoursNumber(dpHours)) hours total, \(dpEntries) entries"
        case .anchorHandling:
            return "\(rigMoves) rig moves"
        case .rov:
            return "\(Self.hoursNumber(rovPilotingHours)) piloting hours, \(Self.entriesText(rovEntries))"
        case .crane:
            return "\(Self.hoursNumber(craneHours)) hours operated, \(Self.entriesText(craneEntries))"
        }
    }

    /// Count line on Main's "Your books" row. DP and AH copy unchanged.
    func mainCountText(for book: LogBook) -> String {
        switch book {
        case .anchorHandling: return rigMoves == 1 ? "1 rig move" : "\(rigMoves) rig moves"
        default: return Self.entriesText(count(for: book))
        }
    }

    /// VoiceOver value on Main's "Your books" row. DP and AH copy unchanged.
    func mainSpokenValue(for book: LogBook) -> String {
        let countText = mainCountText(for: book)
        switch book {
        case .dp: return "\(Self.hoursNumber(dpHours)) hours, \(countText)"
        case .anchorHandling: return countText
        case .rov: return "\(Self.hoursNumber(rovPilotingHours)) piloting hours, \(countText)"
        case .crane: return "\(Self.hoursNumber(craneHours)) hours operated, \(countText)"
        }
    }
}
