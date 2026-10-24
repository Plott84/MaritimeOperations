import Foundation

/// Crane lift weight (tonnes) and wire out (metres).
///
/// The weight is the driver's own estimate from a short preset list, or Other with one
/// decimal place. It is not a vessel lift plan, a load chart, or a certificate.
/// Empty text stays nil so export never writes a fake zero.
enum CraneLiftWeight {
    /// Locked MVP presets, tonnes. Editable later; ship this table.
    static let presets: [Double] = [2, 5, 10, 15, 20, 25, 50]

    static let weightCaption = "Optional. Nominal from the list \u{2014} your estimate, not the lift plan."
    static let wireCaption = "Optional. How far the crane wire was paid out."

    enum Parsed: Equatable {
        case empty
        case value(Double)
        case notANumber
        case tooManyDecimals
    }

    /// Other… text: blank, a number with at most one decimal, or a reason to block Save.
    /// Comma and dot both count. "12.50" is 12.5. "12.55" is too many decimals.
    static func parse(_ raw: String) -> Parsed {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        var normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        guard !normalized.isEmpty else { return .notANumber }
        let allowed = CharacterSet(charactersIn: "0123456789.")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return .notANumber }
        guard normalized.filter({ $0 == "." }).count <= 1 else { return .notANumber }
        if let dot = normalized.firstIndex(of: ".") {
            let fraction = normalized[normalized.index(after: dot)...]
            let significant = fraction.reversed().drop(while: { $0 == "0" })
            if significant.count > 1 { return .tooManyDecimals }
        }
        guard let value = Double(normalized), value.isFinite, value >= 0 else { return .notANumber }
        let tenths = (value * 10).rounded() / 10
        return .value(tenths)
    }

    static func problem(for parsed: Parsed) -> String? {
        switch parsed {
        case .empty, .value:
            return nil
        case .notANumber:
            return "Lift weight must be a number."
        case .tooManyDecimals:
            return "Lift weight uses one decimal place."
        }
    }

    static func matches(_ tonnes: Double, _ preset: Double) -> Bool {
        abs(tonnes - preset) < 0.001
    }

    static func isPreset(_ tonnes: Double) -> Bool {
        presets.contains { matches(tonnes, $0) }
    }

    /// Form state for a stored weight. A preset stays on the list; anything else opens Other…
    struct Editing: Equatable {
        var preset: Double?
        var isOther: Bool
        var otherText: String
    }

    static func editing(storedTonnes: Double?, locale: Locale = .current) -> Editing {
        guard let storedTonnes else {
            return Editing(preset: nil, isOther: false, otherText: "")
        }
        if isPreset(storedTonnes) {
            return Editing(preset: storedTonnes, isOther: false, otherText: "")
        }
        return Editing(
            preset: nil,
            isOther: true,
            otherText: amount(storedTonnes, fractionDigits: 1, locale: locale)
        )
    }

    static func presetTag(_ tonnes: Double) -> String {
        String(Int(tonnes.rounded()))
    }

    /// "10", "12.5", "12,5". No grouping separator. Empty fraction digits drop off.
    static func amount(_ value: Double, fractionDigits: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func tonnesLabel(_ tonnes: Double?, locale: Locale = .current) -> String? {
        guard let tonnes else { return nil }
        return "\(amount(tonnes, fractionDigits: 1, locale: locale)) t"
    }

    static func wireLabel(_ metres: Double?, locale: Locale = .current) -> String? {
        guard let metres else { return nil }
        return "\(amount(metres, fractionDigits: 2, locale: locale)) m out"
    }

    /// List line under hours. Nil when both are empty — never "0 t · 0 m out".
    static func rowLine(weightTonnes: Double?, wireMetres: Double?, locale: Locale = .current) -> String? {
        switch (tonnesLabel(weightTonnes, locale: locale), wireLabel(wireMetres, locale: locale)) {
        case let (weight?, wire?):
            return "\(weight) \u{00B7} \(wire)"
        case let (weight?, nil):
            return weight
        case let (nil, wire?):
            return wire
        case (nil, nil):
            return nil
        }
    }

    static func spokenTonnes(_ tonnes: Double, locale: Locale = .current) -> String {
        let unit = abs(tonnes - 1) < 0.000_001 ? "tonne" : "tonnes"
        return "\(amount(tonnes, fractionDigits: 1, locale: locale)) \(unit)"
    }

    static func spokenMetres(_ metres: Double, locale: Locale = .current) -> String {
        let unit = abs(metres - 1) < 0.000_001 ? "metre" : "metres"
        return "\(amount(metres, fractionDigits: 2, locale: locale)) \(unit)"
    }

    /// VoiceOver for the book row: "10 tonnes, 85 metres out".
    static func spokenSummary(weightTonnes: Double?, wireMetres: Double?, locale: Locale = .current) -> String? {
        switch (weightTonnes, wireMetres) {
        case let (weight?, wire?):
            return "\(spokenTonnes(weight, locale: locale)), \(spokenMetres(wire, locale: locale)) out"
        case let (weight?, nil):
            return spokenTonnes(weight, locale: locale)
        case let (nil, wire?):
            return "\(spokenMetres(wire, locale: locale)) out"
        case (nil, nil):
            return nil
        }
    }

    /// Value on the form row. Nil shows grey "Not set".
    static func formLabel(preset: Double?, isOther: Bool, otherText: String, locale: Locale = .current) -> String? {
        if isOther {
            if case .value(let tonnes) = parse(otherText) {
                return tonnesLabel(tonnes, locale: locale)
            }
            return nil
        }
        return tonnesLabel(preset, locale: locale)
    }

    /// Accessibility value for the form button: "10 tonnes", "Not set", or "Other".
    static func formSpoken(preset: Double?, isOther: Bool, otherText: String, locale: Locale = .current) -> String {
        if isOther {
            switch parse(otherText) {
            case .value(let tonnes):
                return spokenTonnes(tonnes, locale: locale)
            case .empty:
                return "Not set"
            case .notANumber, .tooManyDecimals:
                return "Other"
            }
        }
        if let preset {
            return spokenTonnes(preset, locale: locale)
        }
        return "Not set"
    }

    /// Wire-out field value for VoiceOver: "85 metres", or "Not set" when blank.
    static func spokenWireField(_ raw: String, locale: Locale = .current) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Not set" }
        guard let metres = LogNumber.decimal(trimmed) else { return trimmed }
        return spokenMetres(metres, locale: locale)
    }

    /// Other… field value for VoiceOver.
    static func spokenWeightField(_ raw: String, locale: Locale = .current) -> String {
        switch parse(raw) {
        case .empty:
            return "Not set"
        case .value(let tonnes):
            return spokenTonnes(tonnes, locale: locale)
        case .notANumber, .tooManyDecimals:
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
