import Foundation

/// Form state for the activity code picker. Storage stays one plain String on DPEntry:
/// a book code ("PSV"), a My code ("AH"), "OT – <specify>", or any old free text.
struct ActivityCodeSelection: Equatable {
    static let otSeparator = " – "
    /// Picker tag for "keep the old stored text". Can't clash with a real code.
    static let legacyTag = "legacy:current"

    /// Picker tag: "" = none, a code raw value, or `legacyTag`.
    var code: String
    var specify: String
    /// Old stored text that is not in the list. Kept as its own option so it is never wiped.
    let legacyValue: String?

    init(code: String = "", specify: String = "", legacyValue: String? = nil) {
        self.code = code
        self.specify = specify
        self.legacyValue = legacyValue
    }

    init(stored: String?) {
        let value = (stored ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let otPrefix = ActivityCode.ot.rawValue + Self.otSeparator
        if value.isEmpty {
            self.init()
        } else if ActivityCode(rawValue: value) != nil && value != ActivityCode.ot.rawValue {
            self.init(code: value)
        } else if MyActivityCode(rawValue: value) != nil {
            self.init(code: value)
        } else if value.hasPrefix(otPrefix), !value.dropFirst(otPrefix.count).trimmingCharacters(in: .whitespaces).isEmpty {
            self.init(code: ActivityCode.ot.rawValue, specify: String(value.dropFirst(otPrefix.count)))
        } else {
            // Old free text (including a bare "OT"): show it as-is, don't force a change.
            self.init(code: Self.legacyTag, legacyValue: value)
        }
    }

    var isOT: Bool { code == ActivityCode.ot.rawValue }

    var trimmedSpecify: String { specify.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Nil when the selection can be saved.
    var validationError: String? {
        if isOT && trimmedSpecify.isEmpty {
            return "Specify the OT activity."
        }
        return nil
    }

    /// Value written to DPEntry.activityCode.
    var storedValue: String? {
        if code.isEmpty { return nil }
        if code == Self.legacyTag { return legacyValue }
        if isOT { return ActivityCode.ot.rawValue + Self.otSeparator + trimmedSpecify }
        return code
    }
}
