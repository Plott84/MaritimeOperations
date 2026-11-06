import Foundation

/// The seven Winch capacity inputs stored with a named preset.
/// Pull is optional on the form: `nil` means the field was empty.
struct NamedWinchInputs: Codable, Equatable, Sendable {
    var wireDiameterMm: Double
    var barrelDiameterMm: Double
    var drumWidthMm: Double
    var flangeDiameterMm: Double
    var freeSpaceMm: Double
    var deadWraps: Int
    var firstLayerPullTonnes: Double?

    /// Numbers the form can show again. Empty free space and dead wraps are stored as the math defaults.
    var fieldText: NamedWinchFieldText {
        NamedWinchFieldText(
            wire: NamedWinchFormat.plain(wireDiameterMm),
            barrel: NamedWinchFormat.plain(barrelDiameterMm),
            width: NamedWinchFormat.plain(drumWidthMm),
            flange: NamedWinchFormat.plain(flangeDiameterMm),
            freeSpace: NamedWinchFormat.plain(freeSpaceMm),
            deadWraps: String(deadWraps),
            firstLayerPull: firstLayerPullTonnes.map(NamedWinchFormat.plain) ?? ""
        )
    }

    /// Parse the form. Empty free space → 400. Empty dead wraps → 3. Empty pull stays unset.
    /// A required diameter or a garbage optional field returns nil so Save stays disabled.
    static func capture(
        wire: String,
        barrel: String,
        width: String,
        flange: String,
        freeSpace: String,
        deadWraps: String,
        firstLayerPull: String
    ) -> NamedWinchInputs? {
        guard let wireDiameterMm = ToolsParse.double(wire),
              let barrelDiameterMm = ToolsParse.double(barrel),
              let drumWidthMm = ToolsParse.double(width),
              let flangeDiameterMm = ToolsParse.double(flange) else {
            return nil
        }

        let free: Double
        if freeSpace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            free = WinchCapacityMath.defaultFreeSpaceMm
        } else if let parsed = ToolsParse.double(freeSpace) {
            free = parsed
        } else {
            return nil
        }

        let dead: Int
        if deadWraps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dead = WinchCapacityMath.defaultDeadWraps
        } else if let parsed = ToolsParse.double(deadWraps),
                  parsed == floor(parsed), parsed >= 0, parsed < Double(Int.max) {
            dead = Int(parsed)
        } else {
            return nil
        }

        let pull: Double?
        if firstLayerPull.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pull = nil
        } else if let parsed = ToolsParse.double(firstLayerPull) {
            pull = parsed
        } else {
            return nil
        }

        return NamedWinchInputs(
            wireDiameterMm: wireDiameterMm,
            barrelDiameterMm: barrelDiameterMm,
            drumWidthMm: drumWidthMm,
            flangeDiameterMm: flangeDiameterMm,
            freeSpaceMm: free,
            deadWraps: dead,
            firstLayerPullTonnes: pull
        )
    }

    static func capture(_ text: NamedWinchFieldText) -> NamedWinchInputs? {
        capture(
            wire: text.wire,
            barrel: text.barrel,
            width: text.width,
            flange: text.flange,
            freeSpace: text.freeSpace,
            deadWraps: text.deadWraps,
            firstLayerPull: text.firstLayerPull
        )
    }
}

/// Strings written back into the seven Winch capacity fields.
struct NamedWinchFieldText: Equatable, Sendable {
    var wire: String
    var barrel: String
    var width: String
    var flange: String
    var freeSpace: String
    var deadWraps: String
    var firstLayerPull: String
}

/// One named set of winch inputs on this device.
struct NamedWinchPreset: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var wireDiameterMm: Double
    var barrelDiameterMm: Double
    var drumWidthMm: Double
    var flangeDiameterMm: Double
    var freeSpaceMm: Double
    var deadWraps: Int
    var firstLayerPullTonnes: Double?
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, inputs: NamedWinchInputs, updatedAt: Date) {
        self.id = id
        self.name = name
        self.wireDiameterMm = inputs.wireDiameterMm
        self.barrelDiameterMm = inputs.barrelDiameterMm
        self.drumWidthMm = inputs.drumWidthMm
        self.flangeDiameterMm = inputs.flangeDiameterMm
        self.freeSpaceMm = inputs.freeSpaceMm
        self.deadWraps = inputs.deadWraps
        self.firstLayerPullTonnes = inputs.firstLayerPullTonnes
        self.updatedAt = updatedAt
    }

    var inputs: NamedWinchInputs {
        NamedWinchInputs(
            wireDiameterMm: wireDiameterMm,
            barrelDiameterMm: barrelDiameterMm,
            drumWidthMm: drumWidthMm,
            flangeDiameterMm: flangeDiameterMm,
            freeSpaceMm: freeSpaceMm,
            deadWraps: deadWraps,
            firstLayerPullTonnes: firstLayerPullTonnes
        )
    }

    /// `d 87 · D0 1 800 · W 3 400 · Df 4 300`
    var dimsSummary: String {
        let dot = "\u{00B7}"
        return "d \(NamedWinchFormat.grouped(wireDiameterMm)) \(dot) D0 \(NamedWinchFormat.grouped(barrelDiameterMm)) \(dot) W \(NamedWinchFormat.grouped(drumWidthMm)) \(dot) Df \(NamedWinchFormat.grouped(flangeDiameterMm))"
    }
}

enum NamedWinchFormat {
    /// Field text. Whole numbers stay integers so "1800" round-trips. No grouping.
    static func plain(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let negative = value < 0
        let magnitude = abs(value)
        if magnitude.rounded() == magnitude, magnitude < Double(Int.max) {
            let digits = String(Int(magnitude.rounded()))
            return negative ? "-" + digits : digits
        }
        var text = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), magnitude)
        while text.last == "0" { text.removeLast() }
        if text.last == "." { text.removeLast() }
        if text.isEmpty { text = "0" }
        return negative ? "-" + text : text
    }

    /// Space-grouped thousands for the load-sheet subtitle. `1800` → `1 800`, `900` → `900`.
    /// Grouping is done by hand so the separator stays a normal space on every locale.
    static func grouped(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let negative = value < 0
        let plainText = plain(abs(value))
        let parts = plainText.split(separator: ".", omittingEmptySubsequences: false)
        guard let head = parts.first else { return plainText }
        var body = groupDigits(String(head))
        if parts.count > 1 {
            body += "." + parts.dropFirst().joined(separator: ".")
        }
        return negative ? "-" + body : body
    }

    private static func groupDigits(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var grouped = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset > 0, offset.isMultiple(of: 3) {
                grouped.append(" ")
            }
            grouped.append(character)
        }
        return String(grouped.reversed())
    }
}

/// Salt 200 drum values copied into the user library once.
/// After that copy they are ordinary saved presets. This catalog is not merged into Load.
enum NamedWinchSeed {
    static let ahName = "Salt 200 \u{00B7} AH"
    static let towStarboardName = "Salt 200 \u{00B7} T/W STBD"
    static let towPortName = "Salt 200 \u{00B7} T/W PORT"
    static let secondaryName = "Salt 200 \u{00B7} Secondary"

    /// Newest stamp first so the existing recency sort lists AH, T/W STBD, T/W PORT, Secondary.
    private static func stamp(_ stepsNewer: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_600_000_000 + stepsNewer)
    }

    /// Anchor-handling. Pull table is not on the captured sheet, so the optional stays empty.
    /// Width is 9620 mm; the 1100 mm socket compartment is excluded.
    static let ah = NamedWinchPreset(
        id: UUID(uuidString: "5A170200-0001-4000-8000-0000000000A1")!,
        name: ahName,
        inputs: NamedWinchInputs(
            wireDiameterMm: 87,
            barrelDiameterMm: 2500,
            drumWidthMm: 9620,
            flangeDiameterMm: 5050,
            freeSpaceMm: 400,
            deadWraps: WinchCapacityMath.defaultDeadWraps,
            firstLayerPullTonnes: nil
        ),
        updatedAt: stamp(3)
    )

    /// Towing winch starboard. 170 t is inferred until that drum's pull table is available.
    static let towStarboard = NamedWinchPreset(
        id: UUID(uuidString: "5A170200-0002-4000-8000-0000000000B2")!,
        name: towStarboardName,
        inputs: NamedWinchInputs(
            wireDiameterMm: 87,
            barrelDiameterMm: 1800,
            drumWidthMm: 3400,
            flangeDiameterMm: 4300,
            freeSpaceMm: 400,
            deadWraps: WinchCapacityMath.defaultDeadWraps,
            firstLayerPullTonnes: 170
        ),
        updatedAt: stamp(2)
    )

    /// Towing winch port. 170 t is the same inference as starboard.
    /// Width is 2100 mm; the 900 mm socket compartment is excluded.
    static let towPort = NamedWinchPreset(
        id: UUID(uuidString: "5A170200-0003-4000-8000-0000000000C3")!,
        name: towPortName,
        inputs: NamedWinchInputs(
            wireDiameterMm: 87,
            barrelDiameterMm: 1800,
            drumWidthMm: 2100,
            flangeDiameterMm: 4300,
            freeSpaceMm: 400,
            deadWraps: WinchCapacityMath.defaultDeadWraps,
            firstLayerPullTonnes: 170
        ),
        updatedAt: stamp(1)
    )

    /// Secondary drum, double-drive 1st layer 170 t.
    /// Width is 4800 mm; the 900 mm socket compartment is excluded.
    /// Max spool weight 200 t is not a Soft A field.
    static let secondary = NamedWinchPreset(
        id: UUID(uuidString: "5A170200-0004-4000-8000-0000000000D4")!,
        name: secondaryName,
        inputs: NamedWinchInputs(
            wireDiameterMm: 87,
            barrelDiameterMm: 1500,
            drumWidthMm: 4800,
            flangeDiameterMm: 4500,
            freeSpaceMm: 400,
            deadWraps: WinchCapacityMath.defaultDeadWraps,
            firstLayerPullTonnes: 170
        ),
        updatedAt: stamp(0)
    )

    /// Insertion order matches the preferred Load order.
    static let presets: [NamedWinchPreset] = [ah, towStarboard, towPort, secondary]

    /// Append catalog rows that are not already stored under the same case-insensitive name.
    /// Stops at `limit` (the Soft A library cap). Does not replace an existing row.
    static func inserting(into existing: [NamedWinchPreset], limit: Int = NamedWinchPresetStore.maxPresets) -> [NamedWinchPreset] {
        var items = existing
        var keys = Set(items.map { NamedWinchPresetStore.nameKey($0.name) })
        for preset in presets {
            guard items.count < limit else { break }
            let key = NamedWinchPresetStore.nameKey(preset.name)
            guard !keys.contains(key) else { continue }
            items.append(preset)
            keys.insert(key)
        }
        return items
    }
}

/// Local named presets. UserDefaults JSON is enough for this tool alone — no iCloud, no logbook schema.
/// An empty library is seeded once from `NamedWinchSeed` when `factorySeedKey` is unset.
struct NamedWinchPresetStore: Sendable {
    static let storageKey = "namedWinchPresets.v1"
    /// One-shot Bool stored beside `storageKey`. Missing or false: the seed has not been decided.
    /// Set true after the four Salt 200 drums are written into an empty library, or after a non-empty library skips the seed.
    /// A later empty library does not seed again. Wiping UserDefaults removes this key, so the next empty read can seed once more.
    static let factorySeedKey = "namedWinchPresets.factorySeeded.v1"
    /// Hard cap on stored presets. A 51st new name is refused; replacing one of the 50 still works.
    static let maxPresets = 50
    /// Trimmed name, counted in characters (extended grapheme clusters). Longer names are refused, not truncated.
    static let maxNameLength = 64

    var defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    enum NameMatch: Equatable, Sendable {
        case empty
        case tooLong
        case libraryFull
        case available(trimmed: String)
        case collision(existingDisplayName: String)
    }

    /// Case-insensitive match on the trimmed name. Does not write a preset.
    /// A name over 64 characters is `.tooLong` even when the library is full.
    /// A new name is `.libraryFull` at 50 presets. An existing name is still `.collision`, so overwrite stays available.
    /// Decides the one-shot seed before matching, so the first Save open can fill an empty library.
    func match(name: String) -> NameMatch {
        ensureFactorySeed()
        let trimmed = Self.trimmed(name)
        guard !trimmed.isEmpty else { return .empty }
        guard trimmed.count <= Self.maxNameLength else { return .tooLong }
        let items = loadRaw()
        if let existing = items.first(where: { Self.nameKey($0.name) == Self.nameKey(trimmed) }) {
            return .collision(existingDisplayName: existing.name)
        }
        guard items.count < Self.maxPresets else { return .libraryFull }
        return .available(trimmed: trimmed)
    }

    /// Insert, or replace the case-insensitive match in the user library.
    /// Display casing becomes the trimmed name just saved.
    /// Empty names, names over 64 characters, and a 51st preset do not write.
    /// Replacing one of the existing 50 still writes.
    /// Decides the one-shot seed first, so a save on a fresh library lands beside the four Salt 200 drums.
    @discardableResult
    func save(name: String, inputs: NamedWinchInputs, at date: Date = .now) -> NamedWinchPreset? {
        ensureFactorySeed()
        let trimmed = Self.trimmed(name)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= Self.maxNameLength else { return nil }
        var items = loadRaw()
        let key = Self.nameKey(trimmed)
        let preset: NamedWinchPreset
        if let index = items.firstIndex(where: { Self.nameKey($0.name) == key }) {
            preset = NamedWinchPreset(id: items[index].id, name: trimmed, inputs: inputs, updatedAt: date)
            items[index] = preset
        } else {
            guard items.count < Self.maxPresets else { return nil }
            preset = NamedWinchPreset(name: trimmed, inputs: inputs, updatedAt: date)
            items.append(preset)
        }
        persist(items)
        return preset
    }

    /// Saved presets on this device, most recently updated first.
    /// Decides the one-shot seed first.
    func all() -> [NamedWinchPreset] {
        ensureFactorySeed()
        return Self.sortedByRecency(loadRaw())
    }

    /// Rows for the Load sheet. Seeds once when allowed, then returns `all()`.
    func loadList() -> [NamedWinchPreset] {
        ensureFactorySeed()
        return all()
    }

    /// Copy `NamedWinchSeed` into an empty library at most once.
    /// A non-empty library sets the flag and is left unchanged.
    /// Clearing the stored presets later does not seed again while the flag remains.
    func ensureFactorySeed() {
        guard !defaults.bool(forKey: Self.factorySeedKey) else { return }
        let existing = loadRaw()
        guard existing.isEmpty else {
            defaults.set(true, forKey: Self.factorySeedKey)
            return
        }
        let seeded = NamedWinchSeed.inserting(into: existing)
        guard !seeded.isEmpty else {
            defaults.set(true, forKey: Self.factorySeedKey)
            return
        }
        persist(seeded)
        if loadRaw().count == seeded.count {
            defaults.set(true, forKey: Self.factorySeedKey)
        }
    }

    private static func sortedByRecency(_ items: [NamedWinchPreset]) -> [NamedWinchPreset] {
        items.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.name < rhs.name
        }
    }

    static func nameKey(_ name: String) -> String {
        trimmed(name).lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadRaw() -> [NamedWinchPreset] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode([NamedWinchPreset].self, from: data)) ?? []
    }

    private func persist(_ items: [NamedWinchPreset]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// Loaded-chip session. Clearing the chip, or editing a field, leaves the numbers on the form.
struct NamedWinchLoadState: Equatable, Sendable {
    private(set) var loadedName: String?
    private var fieldSnapshot: String?

    mutating func show(name: String, fields: String) {
        loadedName = name
        fieldSnapshot = fields
    }

    /// ✕ removes the chip only.
    mutating func clearChip() {
        loadedName = nil
        fieldSnapshot = nil
    }

    /// A keystroke whose text differs from the loaded snapshot drops the chip.
    mutating func fieldsChanged(to fields: String) {
        guard loadedName != nil else { return }
        guard fields != fieldSnapshot else { return }
        clearChip()
    }
}

/// Locked Winch save/load copy. No “SAFE” / “OK to lift” language.
enum NamedWinchCopy {
    static let navTitle = "Winch capacity"
    static let load = "Load"
    static let save = "Save"
    static let loaded = "Loaded"
    static let saveTitle = "Save winch"
    static let loadTitle = "Load winch"
    static let namePlaceholder = "A-frame port"
    static let saveCaption = "Saves the input values on this device. Not shared."
    static let nameTooLong = "Name can be at most \(NamedWinchPresetStore.maxNameLength) characters."
    static let libraryFull = "This device already has \(NamedWinchPresetStore.maxPresets) saved winches. Save over an existing name to update it."
    static let replaceBody = "A winch with this name already exists. Replace it with the current values?"
    static let cancel = "Cancel"
    static let replace = "Replace"
    static let emptyTitle = "No saved winches yet"
    static let emptyBody = "Tap Save on the Winch capacity form to keep a named set of inputs on this device."
    static let aid = "Aid for deck estimates. Not a class or maker rating."
    static let clearLoaded = "Clear loaded winch"
    static let loadHint = "Shows saved winches on this device"
    static let saveHint = "Saves the current inputs under a name on this device"
    static let loadRowHint = "Loads these winch inputs"

    static func replaceTitle(_ existingDisplayName: String) -> String {
        "Replace \u{201C}\(existingDisplayName)\u{201D}?"
    }

    static var lockedStrings: [String] {
        [
            navTitle, load, save, loaded, saveTitle, loadTitle, namePlaceholder, saveCaption,
            nameTooLong, libraryFull,
            replaceBody, cancel, replace, emptyTitle, emptyBody, aid, replaceTitle("A-frame"),
            clearLoaded, loadHint, saveHint, loadRowHint
        ]
    }
}
