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

/// Built-in winches. Not written to UserDefaults.
/// `NamedWinchPresetStore.loadList()` shows these beside saved presets.
/// Saving the same name (case-insensitive) stores a user preset that replaces the factory row.
/// Clearing the user library does not remove these rows.
enum NamedWinchFactory {
    /// Stable Load-row identity. `UUID.uuidString` is uppercase.
    static let salt200AHTSID = UUID(uuidString: "5A170200-A475-4C00-8000-000000000057")!

    /// Older than any saved preset, so user rows sort above this one.
    static let salt200AHTSUpdatedAt = Date(timeIntervalSince1970: 0)

    /// Tor Viking secondary / work drum, double-drive 1st layer.
    /// Sheet drum length is 4800 mm + 900 mm socket compartment; width is the 4800 mm winding length.
    /// Flange is the 4500 mm drum outer diameter. Free space is the sheet's 400 mm radial free space.
    /// Dead wraps are not on the sheet; this uses the Soft A default.
    /// Max weight of wire or rope spooled on the drum is 200 t. That figure is not a Soft A field.
    static let salt200AHTS = NamedWinchPreset(
        id: salt200AHTSID,
        name: "Salt 200 AHTS",
        inputs: NamedWinchInputs(
            wireDiameterMm: 87,
            barrelDiameterMm: 1500,
            drumWidthMm: 4800,
            flangeDiameterMm: 4500,
            freeSpaceMm: 400,
            deadWraps: WinchCapacityMath.defaultDeadWraps,
            firstLayerPullTonnes: 170
        ),
        updatedAt: salt200AHTSUpdatedAt
    )

    static let presets: [NamedWinchPreset] = [salt200AHTS]
}

/// Local named presets. UserDefaults JSON is enough for this tool alone — no iCloud, no logbook schema.
/// Factory presets stay in `NamedWinchFactory` and are merged only by `loadList()`.
struct NamedWinchPresetStore: Sendable {
    static let storageKey = "namedWinchPresets.v1"
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

    /// Case-insensitive match on the trimmed name. Does not write.
    /// A name over 64 characters is `.tooLong` even when the library is full.
    /// A new name is `.libraryFull` at 50 presets. An existing stored name is still `.collision`, so overwrite stays available.
    /// A factory name that is not stored yet is `.collision` while there is room, so Save asks before writing over that row.
    /// At 50 stored presets that factory name is `.libraryFull`: it would be a new stored preset, not an overwrite of one of the 50.
    func match(name: String) -> NameMatch {
        let trimmed = Self.trimmed(name)
        guard !trimmed.isEmpty else { return .empty }
        guard trimmed.count <= Self.maxNameLength else { return .tooLong }
        let items = loadRaw()
        if let existing = items.first(where: { Self.nameKey($0.name) == Self.nameKey(trimmed) }) {
            return .collision(existingDisplayName: existing.name)
        }
        if let factory = Self.factoryPreset(named: trimmed) {
            guard items.count < Self.maxPresets else { return .libraryFull }
            return .collision(existingDisplayName: factory.name)
        }
        guard items.count < Self.maxPresets else { return .libraryFull }
        return .available(trimmed: trimmed)
    }

    /// Insert, or replace the case-insensitive match in the user library.
    /// Display casing becomes the trimmed name just saved.
    /// Empty names, names over 64 characters, and a 51st preset do not write.
    /// Replacing one of the existing 50 still writes.
    /// Saving a factory name writes a user preset. `loadList()` then shows that preset instead of the factory row.
    @discardableResult
    func save(name: String, inputs: NamedWinchInputs, at date: Date = .now) -> NamedWinchPreset? {
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
    /// Factory rows are not included, so an empty library stays empty and a full library stays at 50.
    /// The Load sheet uses `loadList()`.
    func all() -> [NamedWinchPreset] {
        Self.sortedByRecency(loadRaw())
    }

    /// Rows for the Load sheet. Saved presets, plus factory presets whose name the user has not saved over.
    /// A stored preset with the same name (case-insensitive) replaces the factory row.
    /// Clearing UserDefaults leaves the factory rows.
    func loadList() -> [NamedWinchPreset] {
        let saved = loadRaw()
        let savedKeys = Set(saved.map { Self.nameKey($0.name) })
        let factory = NamedWinchFactory.presets.filter { preset in
            !savedKeys.contains(Self.nameKey(preset.name))
        }
        return Self.sortedByRecency(saved + factory)
    }

    private static func factoryPreset(named trimmed: String) -> NamedWinchPreset? {
        let key = nameKey(trimmed)
        return NamedWinchFactory.presets.first { nameKey($0.name) == key }
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
