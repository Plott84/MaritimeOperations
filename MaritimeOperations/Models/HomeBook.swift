import Foundation

// Preferred books for Main. Raw values are the AppStorage contract:
// `homeBook` and optional `homeBookSecondary` — dp, ah, crane, rov.
// `ah` is not LogBook.anchorHandling. Do not rename them.
// The old multi-star key `log.starredBooks` is not read. Changing these values never
// deletes entries. Primary owns the hero and Latest Activity. Secondary is a compact card.

enum HomeBook: String, CaseIterable, Identifiable {
    case dp
    case ah
    case crane
    case rov

    static let storageKey = "homeBook"
    static let defaultRaw = HomeBook.dp.rawValue
    static let changeHint = "Double tap to change."
    static let pickerTitle = "On Main"
    static let pickerFootnote = "Primary gets the big card. Secondary sits under it. Max two."

    var id: String { rawValue }

    init(logBook: LogBook) {
        switch logBook {
        case .dp: self = .dp
        case .anchorHandling: self = .ah
        case .rov: self = .rov
        case .crane: self = .crane
        }
    }

    var logBook: LogBook {
        switch self {
        case .dp: return .dp
        case .ah: return .anchorHandling
        case .rov: return .rov
        case .crane: return .crane
        }
    }

    /// Short name on the chip, picker, and activity count.
    var chipTitle: String {
        switch self {
        case .dp: return "DP"
        case .ah: return "AH"
        case .crane: return "Crane"
        case .rov: return "ROV"
        }
    }

    /// Spoken book in "On Main, {Book}".
    var voiceName: String {
        switch self {
        case .dp: return "D P"
        case .ah: return "A H"
        case .crane: return "Crane"
        case .rov: return "R O V"
        }
    }

    /// Nav star and chip when this book is primary and nothing sits under it.
    var starAccessibilityLabel: String { HomeBooks(primary: self).voiceLabel }

    var chipLine: String { HomeBooks(primary: self).chipLine }

    var primarySymbol: String {
        switch self {
        case .dp: return "play.fill"
        case .ah: return "ferry.fill"
        case .crane, .rov: return "plus"
        }
    }

    var secondarySymbol: String {
        switch self {
        case .dp: return "ferry.fill"
        case .ah, .crane, .rov: return "book.closed"
        }
    }

    var hero: HomeHeroCopy {
        switch self {
        case .dp:
            return HomeHeroCopy(
                eyebrow: "DP TIMER",
                primary: "Start DP",
                secondary: nil,
                caption: "Start when the vessel goes on DP. Stop saves the session to Entries.",
                activityCaption: "Newest 5 records in the DP book.",
                activityChip: "5 latest · DP",
                emptyTitle: "No DP entries yet.",
                showsDPTimer: true
            )
        case .ah:
            return HomeHeroCopy(
                eyebrow: "ANCHOR HANDLING",
                primary: "New rig move",
                secondary: "Open Anchor handling log",
                caption: "New rig move opens the Anchor handling form.",
                activityCaption: "Newest 5 Anchor handling entries. DP timer is not on this Home.",
                activityChip: "5 latest · AH",
                emptyTitle: "No AH entries yet.",
                showsDPTimer: false
            )
        case .crane:
            return HomeHeroCopy(
                eyebrow: "CRANE",
                primary: "New lift",
                secondary: "Open Crane log",
                caption: "New lift opens the Crane entry form. Stop / Save lands in Entries · Crane.",
                activityCaption: "Newest 5 Crane entries. DP timer is not on this Home.",
                activityChip: "5 latest · Crane",
                emptyTitle: "No Crane entries yet.",
                showsDPTimer: false
            )
        case .rov:
            return HomeHeroCopy(
                eyebrow: "ROV",
                primary: "New ROV entry",
                secondary: "Open ROV log",
                caption: "New ROV entry opens the ROV form. Save lands in Entries · ROV.",
                activityCaption: "Newest 5 ROV entries. DP timer is not on this Home.",
                activityChip: "5 latest · ROV",
                emptyTitle: "No ROV entries yet.",
                showsDPTimer: false
            )
        }
    }

    static func resolve(_ raw: String?) -> HomeBook {
        guard let raw, let book = HomeBook(rawValue: raw) else { return .dp }
        return book
    }

    static func load(defaults: UserDefaults) -> HomeBook {
        resolve(defaults.string(forKey: storageKey))
    }

    static func save(_ book: HomeBook, defaults: UserDefaults) {
        defaults.set(book.rawValue, forKey: storageKey)
    }
}

/// Primary book plus an optional secondary. Secondary is empty or a different book.
struct HomeBooks: Equatable {
    var primary: HomeBook
    var secondary: HomeBook?

    static let secondaryStorageKey = "homeBookSecondary"
    static let entriesFootnote = "Star up to two books for Main (HB-13). Export lives on the Export tab."

    init(primary: HomeBook = .dp, secondary: HomeBook? = nil) {
        self.primary = primary
        if let secondary, secondary != primary {
            self.secondary = secondary
        } else {
            self.secondary = nil
        }
    }

    var storedSecondaryRaw: String { secondary?.rawValue ?? "" }

    var voiceLabel: String {
        if let secondary {
            return "On Main, \(primary.voiceName), \(secondary.voiceName)"
        }
        return "On Main, \(primary.voiceName)"
    }

    var chipLine: String {
        if let secondary {
            return "On Main · ★ \(primary.chipTitle) · ★ \(secondary.chipTitle) · Change ›"
        }
        return "On Main · ★ \(primary.chipTitle) · Change ›"
    }

    func role(of book: HomeBook) -> HomeOnMainRole {
        if book == primary { return .primary }
        if book == secondary { return .secondary }
        return .off
    }

    func starValue(for book: HomeBook) -> String {
        role(of: book).accessibilityValue
    }

    func starHint(for book: HomeBook) -> String {
        switch role(of: book) {
        case .primary:
            if secondary == nil, primary != .dp {
                return "Primary book on Main. Clears it and Main falls back to D P."
            }
            return "Primary book on Main."
        case .secondary:
            return "Secondary book on Main. Removes it from Main."
        case .off:
            if secondary == nil {
                return "Adds this book under the primary on Main."
            }
            return "Replaces the secondary book on Main."
        }
    }

    /// Entries star.
    /// The current primary is the first star. Another book becomes secondary.
    /// A further book replaces secondary. Primary changes in the On Main sheet.
    /// Starring the secondary clears it. Starring the only book falls back to DP.
    /// Starring the primary while a secondary is set keeps the pair.
    func starring(_ book: HomeBook) -> HomeBooks {
        if book == primary {
            if secondary == nil {
                return HomeBooks(primary: .dp)
            }
            return self
        }
        if book == secondary {
            return HomeBooks(primary: primary)
        }
        return HomeBooks(primary: primary, secondary: book)
    }

    func selectingPrimary(_ book: HomeBook) -> HomeBooks {
        if book == primary { return self }
        if book == secondary {
            return HomeBooks(primary: book, secondary: primary)
        }
        return HomeBooks(primary: book, secondary: secondary)
    }

    func selectingSecondary(_ book: HomeBook?) -> HomeBooks {
        guard let book else { return HomeBooks(primary: primary) }
        if book == primary { return self }
        return HomeBooks(primary: primary, secondary: book)
    }

    func makingSecondaryPrimary() -> HomeBooks {
        guard let secondary else { return self }
        return HomeBooks(primary: secondary, secondary: primary)
    }

    static func resolve(primaryRaw: String?, secondaryRaw: String?) -> HomeBooks {
        let secondary = secondaryRaw.flatMap { raw -> HomeBook? in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return HomeBook(rawValue: trimmed)
        }
        return HomeBooks(primary: HomeBook.resolve(primaryRaw), secondary: secondary)
    }

    /// Reads both keys. Does not write, so an install with only `homeBook` keeps a nil secondary.
    static func load(defaults: UserDefaults) -> HomeBooks {
        resolve(
            primaryRaw: defaults.string(forKey: HomeBook.storageKey),
            secondaryRaw: defaults.string(forKey: secondaryStorageKey)
        )
    }

    func save(to defaults: UserDefaults) {
        defaults.set(primary.rawValue, forKey: HomeBook.storageKey)
        if let secondary {
            defaults.set(secondary.rawValue, forKey: Self.secondaryStorageKey)
        } else {
            defaults.removeObject(forKey: Self.secondaryStorageKey)
        }
    }
}

enum HomeOnMainRole: Equatable {
    case primary
    case secondary
    case off

    var isOnMain: Bool { self != .off }

    var accessibilityValue: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .off: return "Off"
        }
    }
}

/// Compact secondary card: one status line and the book's start action. Not a second hero.
enum HomeSecondaryLine {
    static func status(
        book: HomeBook,
        dpClock: String = "00:00",
        dpRunning: Bool = false,
        craneLift: CraneHomeLastLift? = nil,
        anchor: HomeEntrySummary? = nil,
        rov: HomeEntrySummary? = nil
    ) -> String {
        switch book {
        case .dp:
            return "\(dpClock) · \(dpRunning ? "Running" : "Ready")"
        case .crane:
            guard let craneLift else { return "No entries yet" }
            if let value = craneLift.value {
                return "Last lift · \(value)"
            }
            return "Last lift · \(craneLift.sub)"
        case .ah:
            guard let anchor else { return "No entries yet" }
            return oneLine(title: anchor.title, sub: anchor.sub)
        case .rov:
            guard let rov else { return "No entries yet" }
            return oneLine(title: rov.title, sub: rov.sub)
        }
    }

    /// Start action. A running DP session shows Stop DP so this card can stop the same timer.
    static func cta(book: HomeBook, dpRunning: Bool = false) -> String {
        if book == .dp, dpRunning { return "Stop DP" }
        return book.hero.primary
    }

    static func accessibilityLabel(book: HomeBook, cta: String) -> String {
        "\(book.voiceName) on Main, \(cta)"
    }

    private static func oneLine(title: String, sub: String) -> String {
        let sub = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        if sub.isEmpty { return title }
        return "\(title) · \(sub)"
    }
}

struct HomeHeroCopy: Equatable {
    var eyebrow: String
    var primary: String
    /// Nil when the hero has no secondary CTA. DP idle is Start DP only.
    var secondary: String?
    var caption: String
    var activityCaption: String
    var activityChip: String
    var emptyTitle: String
    /// False on Crane, AH, and ROV. Those homes must not render the DP timer.
    var showsDPTimer: Bool
}

enum HomeBookFormat {
    static func dayMonth(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    static func hours(_ hours: Double, locale: Locale) -> String {
        "\(CraneLiftWeight.amount(hours, fractionDigits: 1, locale: locale)) h"
    }

    static func trimmed(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

/// Crane hero "LAST LIFT". Weight and wire are omitted when that side is empty.
struct CraneHomeLastLift: Equatable {
    var value: String?
    var sub: String

    static func latest(
        in entries: [CraneEntry],
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> CraneHomeLastLift? {
        guard let entry = HomeActivity.newestCrane(entries) else { return nil }
        return make(
            weightTonnes: entry.liftWeightTonnes,
            wireMetres: entry.wireOutMetres,
            vessel: entry.vessel,
            craneName: entry.craneName,
            date: entry.date,
            hours: entry.hoursOperated,
            locale: locale,
            timeZone: timeZone
        )
    }

    static func make(
        weightTonnes: Double?,
        wireMetres: Double?,
        vessel: String?,
        craneName: String?,
        date: Date,
        hours: Double?,
        locale: Locale,
        timeZone: TimeZone
    ) -> CraneHomeLastLift {
        let weight = CraneLiftWeight.tonnesLabel(weightTonnes, locale: locale)
        let wire = wireMetres.map {
            "\(CraneLiftWeight.amount($0, fractionDigits: 2, locale: locale)) m wire"
        }
        let value: String?
        switch (weight, wire) {
        case let (weight?, wire?): value = "\(weight) · \(wire)"
        case let (weight?, nil): value = weight
        case let (nil, wire?): value = wire
        case (nil, nil): value = nil
        }
        var parts: [String] = []
        if let vessel = HomeBookFormat.trimmed(vessel) { parts.append(vessel) }
        if let craneName = HomeBookFormat.trimmed(craneName) { parts.append(craneName) }
        parts.append(HomeBookFormat.dayMonth(date, locale: locale, timeZone: timeZone))
        if let hours { parts.append(HomeBookFormat.hours(hours, locale: locale)) }
        return CraneHomeLastLift(value: value, sub: parts.joined(separator: " · "))
    }
}

/// AH / ROV hero last-entry line. Shown only when that book has a row.
struct HomeEntrySummary: Equatable {
    var title: String
    var sub: String

    static func anchorHandling(
        _ move: RigMove,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> HomeEntrySummary {
        var parts: [String] = []
        if let rig = HomeBookFormat.trimmed(move.rigName) { parts.append(rig) }
        if let vessel = HomeBookFormat.trimmed(move.vessel) { parts.append(vessel) }
        parts.append(HomeBookFormat.dayMonth(move.date, locale: locale, timeZone: timeZone))
        if let hours = move.workedHours {
            parts.append(HomeBookFormat.hours(hours, locale: locale))
        }
        return HomeEntrySummary(title: move.ahJobType.label, sub: parts.joined(separator: " · "))
    }

    static func rov(
        _ entry: ROVEntry,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> HomeEntrySummary {
        var parts: [String] = []
        if let vessel = HomeBookFormat.trimmed(entry.vessel) { parts.append(vessel) }
        if let system = HomeBookFormat.trimmed(entry.rovSystem) { parts.append(system) }
        parts.append(HomeBookFormat.dayMonth(entry.date, locale: locale, timeZone: timeZone))
        if let hours = entry.pilotingHours {
            parts.append(HomeBookFormat.hours(hours, locale: locale))
        }
        return HomeEntrySummary(title: entry.rowTitle, sub: parts.joined(separator: " · "))
    }
}

struct HomeActivityItem: Equatable, Identifiable {
    var id: String
    var book: LogBook
    var title: String
    var subtitle: String
    var trailing: String

    var badgeText: String { book.badge }
}

enum HomeActivity {
    static let limit = 5

    static func latest(
        book: HomeBook,
        dpEntries: [DPEntry],
        rigMoves: [RigMove],
        rovEntries: [ROVEntry],
        craneEntries: [CraneEntry],
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> [HomeActivityItem] {
        switch book {
        case .dp:
            return dpEntries
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
                .map { dpItem($0) }
        case .ah:
            return rigMoves
                .sorted(by: newerMove)
                .prefix(limit)
                .map { moveItem($0, locale: locale, timeZone: timeZone) }
        case .rov:
            return rovEntries
                .sorted(by: newerROV)
                .prefix(limit)
                .map { rovItem($0, locale: locale, timeZone: timeZone) }
        case .crane:
            return craneEntries
                .sorted(by: newerCrane)
                .prefix(limit)
                .map { craneItem($0, locale: locale, timeZone: timeZone) }
        }
    }

    static func newestCrane(_ entries: [CraneEntry]) -> CraneEntry? {
        entries.max { older($0.date, $0.createdAt, than: $1.date, $1.createdAt) }
    }

    static func newestMove(_ moves: [RigMove]) -> RigMove? {
        moves.max { older($0.date, $0.createdAt, than: $1.date, $1.createdAt) }
    }

    static func newestROV(_ entries: [ROVEntry]) -> ROVEntry? {
        entries.max { older($0.date, $0.createdAt, than: $1.date, $1.createdAt) }
    }

    /// True when the first stamp is earlier. `max` then returns the newest row.
    private static func older(_ date: Date, _ createdAt: Date, than otherDate: Date, _ otherCreated: Date) -> Bool {
        if date != otherDate { return date < otherDate }
        return createdAt < otherCreated
    }

    private static func newerCrane(_ lhs: CraneEntry, _ rhs: CraneEntry) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        return lhs.createdAt > rhs.createdAt
    }

    private static func newerMove(_ lhs: RigMove, _ rhs: RigMove) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        return lhs.createdAt > rhs.createdAt
    }

    private static func newerROV(_ lhs: ROVEntry, _ rhs: ROVEntry) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        return lhs.createdAt > rhs.createdAt
    }

    private static func dpItem(_ entry: DPEntry) -> HomeActivityItem {
        var parts = [entry.vesselType, entry.dpClassLabel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let ship = entry.vessel.trimmingCharacters(in: .whitespacesAndNewlines)
        parts.append(ship.isEmpty ? "Needs details" : ship)
        if entry.locationFromPhone {
            parts.append("Phone position")
        }
        return HomeActivityItem(
            id: entry.id.uuidString,
            book: .dp,
            title: "DP session",
            subtitle: parts.joined(separator: " · "),
            trailing: AppFormatters.hoursString(entry.durationHours)
        )
    }

    private static func craneItem(_ entry: CraneEntry, locale: Locale, timeZone: TimeZone) -> HomeActivityItem {
        let trailing = entry.hoursOperated.map { HomeBookFormat.hours($0, locale: locale) }
            ?? HomeBookFormat.dayMonth(entry.date, locale: locale, timeZone: timeZone)
        return HomeActivityItem(
            id: entry.id.uuidString,
            book: .crane,
            title: entry.rowTitle,
            subtitle: entry.vesselCraneLine,
            trailing: trailing
        )
    }

    private static func moveItem(_ move: RigMove, locale: Locale, timeZone: TimeZone) -> HomeActivityItem {
        let trailing = move.workedHours.map { HomeBookFormat.hours($0, locale: locale) }
            ?? HomeBookFormat.dayMonth(move.date, locale: locale, timeZone: timeZone)
        return HomeActivityItem(
            id: move.id.uuidString,
            book: .anchorHandling,
            title: move.ahJobType.label,
            subtitle: move.rigVesselLine,
            trailing: trailing
        )
    }

    private static func rovItem(_ entry: ROVEntry, locale: Locale, timeZone: TimeZone) -> HomeActivityItem {
        let trailing = entry.pilotingHours.map { HomeBookFormat.hours($0, locale: locale) }
            ?? HomeBookFormat.dayMonth(entry.date, locale: locale, timeZone: timeZone)
        return HomeActivityItem(
            id: entry.id.uuidString,
            book: .rov,
            title: entry.rowTitle,
            subtitle: entry.vesselSystemLine,
            trailing: trailing
        )
    }
}
