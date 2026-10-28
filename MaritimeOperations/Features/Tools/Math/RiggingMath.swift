import Foundation

/// Slinging and chain-block maths for MaritimeOperations. Foundation only.
///
/// Norwegian G11 / EN: β is the angle from vertical. The band table (0–45° / 45–60°)
/// decides Within / Exceeds. Exact trig is information only.
/// 3- and 4-leg slings use the 2-leg factors. β > 60° has no figures.
/// Required WLL and tensions round up. Assembly capacity rounds down.
enum RiggingMath {
    enum MassUnit: String, CaseIterable, Identifiable, Hashable, Sendable {
        case tonnes = "t"
        case kilograms = "kg"
        var id: String { rawValue }
        var spoken: String { self == .tonnes ? "tonnes" : "kilograms" }
        var places: Int { self == .tonnes ? 2 : 0 }
    }

    enum Hitch: String, CaseIterable, Identifiable, Hashable, Sendable {
        case straight = "Straight"
        case choke = "Choke"
        case basket = "Basket"
        var id: String { rawValue }
    }

    enum Band: Equatable, Sendable {
        case to45
        case to60
        case blocked

        var title: String {
            switch self {
            case .to45: return "0–45°"
            case .to60: return "45–60°"
            case .blocked: return ""
            }
        }

        /// Spoken without a degree glyph so VoiceOver says the range.
        var spokenRange: String {
            switch self {
            case .to45: return "0 to 45"
            case .to60: return "45 to 60"
            case .blocked: return ""
            }
        }

        var isHighAngle: Bool { self == .to60 }
    }

    struct SlingValue: Equatable, Sendable {
        var beta: Decimal
        var band: Band
        var modeFactor: Decimal
        var requiredTag: Decimal
        var assembly: Decimal
        var tension: Decimal
        var trigFactor: Double
        var within: Bool
        var countsAsTwoLeg: Bool
    }

    struct PairTensions: Equatable, Sendable {
        var t1: Decimal
        var t2: Decimal
    }

    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let f08 = exact("0.8")
    private static let f10 = exact("1")
    private static let f112 = exact("1.12")
    private static let f14 = exact("1.4")
    private static let f20 = exact("2")

    private static func exact(_ text: String) -> Decimal {
        Decimal(string: text, locale: posix) ?? 0
    }

    // MARK: - Parsing

    /// Finite decimal. Empty string is nil.
    /// After trim, only an optional leading sign, digits, and one `.` or `,` decimal mark.
    /// `6,0` is 6. `45°`, `6t`, and `1e9` are rejected — Foundation would otherwise read `45°` as 45.
    static func parseDecimal(_ raw: String) -> Decimal? {
        guard let normalized = normalizedCleanNumber(raw) else { return nil }
        return Decimal(string: normalized, locale: posix)
    }

    /// `+6`, `-5`, `6.0`, and `6,0` pass. Anything else, including a trailing unit, does not.
    private static func normalizedCleanNumber(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = trimmed[...]
        var sign = ""
        if let first = body.first, first == "+" || first == "-" {
            if first == "-" { sign = "-" }
            body = body.dropFirst()
        }
        guard let firstDigit = body.first, firstDigit.isASCII && firstDigit.isNumber else { return nil }
        var sawSeparator = false
        var fractionDigits = 0
        for ch in body {
            if ch.isASCII && ch.isNumber {
                if sawSeparator { fractionDigits += 1 }
                continue
            }
            if (ch == "." || ch == ",") && !sawSeparator {
                sawSeparator = true
                continue
            }
            return nil
        }
        if sawSeparator && fractionDigits == 0 { return nil }
        return sign + body.replacingOccurrences(of: ",", with: ".")
    }

    static func converting(_ text: String, from: MassUnit, to: MassUnit) -> String {
        guard from != to else { return text }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = parseDecimal(trimmed) else { return text }
        let kilograms = from == .tonnes ? value * 1000 : value
        let out = to == .tonnes ? kilograms / 1000 : kilograms
        return plain(out, maxPlaces: 4)
    }

    // MARK: - Rounding

    static func round(_ value: Decimal, places: Int, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, places, mode)
        return result
    }

    /// Away from zero. Required WLL and tensions.
    static func roundUp(_ value: Decimal, places: Int) -> Decimal {
        round(value, places: places, mode: .up)
    }

    /// Toward zero. Assembly capacity and other allowed loads.
    static func roundDown(_ value: Decimal, places: Int) -> Decimal {
        round(value, places: places, mode: .down)
    }

    /// Half away from zero. Angle labels and the trig factor only.
    static func roundHalfUp(_ value: Decimal, places: Int) -> Decimal {
        let factor = pow10(places)
        let scaled = value * factor
        let bump = exact(value < 0 ? "-0.5" : "0.5")
        let floored = round(scaled + bump, places: 0, mode: .down)
        return floored / factor
    }

    static func formatFixed(_ value: Decimal, places: Int) -> String {
        let negative = value < 0
        let magnitude = negative ? -value : value
        let scaled = roundHalfUp(magnitude * pow10(places), places: 0)
        var digits = integerDigits(scaled)
        if places == 0 { return (negative ? "-" : "") + digits }
        if digits.count <= places {
            digits = String(repeating: "0", count: places - digits.count + 1) + digits
        }
        let split = digits.index(digits.endIndex, offsetBy: -places)
        return (negative ? "-" : "") + digits[..<split] + "." + digits[split...]
    }

    static func formatMode(_ factor: Decimal) -> String {
        var text = formatFixed(factor, places: 2)
        if text.hasSuffix("0") { text.removeLast() }
        return text
    }

    static func plain(_ value: Decimal, maxPlaces: Int) -> String {
        let rounded = roundHalfUp(value, places: maxPlaces)
        let formatter = NumberFormatter()
        formatter.locale = posix
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = "."
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxPlaces
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSDecimalNumber(decimal: rounded)) ?? "0"
    }

    private static func integerDigits(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = posix
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .halfUp
        var text = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
        if text.hasPrefix("-") { text.removeFirst() }
        if let dot = text.firstIndex(of: ".") { text = String(text[..<dot]) }
        return text.isEmpty ? "0" : text
    }

    static func massText(_ value: Decimal, unit: MassUnit) -> String {
        "\(formatFixed(value, places: unit.places)) \(unit.rawValue)"
    }

    // MARK: - Angle

    static func band(beta: Decimal) -> Band {
        if beta > 60 { return .blocked }
        if beta > 45 { return .to60 }
        return .to45
    }

    /// One decimal, unless that rounding would claim a different band.
    static func angleText(_ beta: Decimal) -> String {
        let one = roundHalfUp(beta, places: 1)
        if band(beta: one) != band(beta: beta) {
            let two = roundHalfUp(beta, places: 2)
            if band(beta: two) != band(beta: beta) {
                return formatFixed(roundHalfUp(beta, places: 3), places: 3)
            }
            return formatFixed(two, places: 2)
        }
        return formatFixed(one, places: 1)
    }

    /// "40.0" → "40" for the Tools-row summary. "40.1" stays.
    static func summaryDegrees(_ angleText: String) -> String {
        guard angleText.hasSuffix(".0") else { return angleText }
        return String(angleText.dropLast(2))
    }

    static func cosine(degrees: Decimal) -> Double {
        if degrees == 0 { return 1 }
        if degrees == 60 { return 0.5 }
        if degrees == 30 { return 0.8660254037844386 }
        if degrees == 45 { return 0.7071067811865476 }
        let degrees = NSDecimalNumber(decimal: degrees).doubleValue
        return cos(degrees * .pi / 180)
    }

    static func trigFactor(degrees: Decimal) -> Double {
        let c = cosine(degrees: degrees)
        guard c > 0 else { return .infinity }
        return 1 / c
    }

    static func formatTrigFactor(_ factor: Double) -> String {
        guard factor.isFinite else { return "" }
        let decimal = decimal(from: factor)
        return formatFixed(roundHalfUp(decimal, places: 3), places: 3)
    }

    enum Geometry: Equatable, Sendable {
        case lengthNotPositive
        case heightNotPositive
        case heightExceedsLength
        case angle(beta: Decimal, blocked: Bool)
    }

    /// cos β = H / L. Requires 0 < H ≤ L. H = L is 0°. H = L / 2 is 60°.
    static func geometry(length: Decimal, height: Decimal) -> Geometry {
        if length <= 0 { return .lengthNotPositive }
        if height <= 0 { return .heightNotPositive }
        if height > length { return .heightExceedsLength }
        if height == length { return .angle(beta: 0, blocked: false) }
        if height * 2 == length { return .angle(beta: 60, blocked: false) }
        if height * 2 < length {
            return .angle(beta: betaDegrees(height: height, length: length), blocked: true)
        }
        let beta = betaDegrees(height: height, length: length)
        return .angle(beta: beta, blocked: band(beta: beta) == .blocked)
    }

    // MARK: - Slings

    static func sharingLegs(_ legs: Int) -> Int { legs <= 1 ? 1 : 2 }

    static func countsAsTwoLeg(_ legs: Int) -> Bool { legs >= 3 }

    static func modeFactor(legs: Int, hitch: Hitch, beta: Decimal) -> Decimal {
        let multi = legs >= 2
        let high = beta > 45
        switch hitch {
        case .straight:
            guard multi else { return f10 }
            return high ? f10 : f14
        case .choke:
            guard multi else { return f08 }
            return high ? f08 : f112
        case .basket:
            if beta == 0 { return f20 }
            return high ? f10 : f14
        }
    }

    static func sling(
        load: Decimal,
        legs: Int,
        hitch: Hitch,
        beta: Decimal,
        tag: Decimal,
        unit: MassUnit
    ) -> SlingValue? {
        guard load > 0, tag > 0, beta >= 0, beta <= 60 else { return nil }
        let places = unit.places
        let factor = modeFactor(legs: legs, hitch: hitch, beta: beta)
        let required = roundUp(load / factor, places: places)
        let assembly = roundDown(tag * factor, places: places)
        let rawTension = legTension(load: load, legs: legs, beta: beta)
        let tension = roundUp(rawTension, places: places)
        return SlingValue(
            beta: beta,
            band: band(beta: beta),
            modeFactor: factor,
            requiredTag: required,
            assembly: assembly,
            tension: tension,
            trigFactor: trigFactor(degrees: beta),
            within: assembly >= load,
            countsAsTwoLeg: countsAsTwoLeg(legs)
        )
    }

    static func legTension(load: Decimal, legs: Int, beta: Decimal) -> Decimal {
        let n = Decimal(sharingLegs(legs))
        if beta == 0 { return load / n }
        if beta == 60 { return load * 2 / n }
        let exact = NSDecimalNumber(decimal: load).doubleValue / (Double(sharingLegs(legs)) * cosine(degrees: beta))
        return decimal(from: exact)
    }

    // MARK: - Chain block

    /// T₁ = W · sin β₂ / sin(β₁+β₂), T₂ = W · sin β₁ / sin(β₁+β₂), then round up.
    /// Nil when the denominator is ~0 (blocks are not apart) or a tension is not finite.
    static func pairTensions(load: Decimal, beta1: Decimal, beta2: Decimal, unit: MassUnit) -> PairTensions? {
        let b1 = NSDecimalNumber(decimal: beta1).doubleValue
        let b2 = NSDecimalNumber(decimal: beta2).doubleValue
        let sum = (b1 + b2) * .pi / 180
        let denom = sin(sum)
        if abs(denom) < 1e-8 { return nil }
        let w = NSDecimalNumber(decimal: load).doubleValue
        let t1 = w * sin(b2 * .pi / 180) / denom
        let t2 = w * sin(b1 * .pi / 180) / denom
        guard t1.isFinite, t2.isFinite else { return nil }
        let places = unit.places
        return PairTensions(
            t1: roundUp(decimal(from: t1), places: places),
            t2: roundUp(decimal(from: t2), places: places)
        )
    }

    /// Whole percent, rounded up, from the tension already shown.
    static func percentOfWLL(tension: Decimal, wll: Decimal) -> Decimal? {
        guard wll > 0 else { return nil }
        return roundUp(tension / wll * 100, places: 0)
    }

    // MARK: - Private

    private static func betaDegrees(height: Decimal, length: Decimal) -> Decimal {
        let ratio = NSDecimalNumber(decimal: height / length).doubleValue
        let clamped = min(1, max(-1, ratio))
        var beta = acos(clamped) * 180 / .pi
        if abs(beta) < 0.000001 { beta = 0 }
        if abs(beta - 45) < 0.000001 { beta = 45 }
        if abs(beta - 60) < 0.000001 { beta = 60 }
        return decimal(from: beta)
    }

    static func decimal(from value: Double) -> Decimal {
        guard value.isFinite else { return 0 }
        let text = String(format: "%.12f", locale: posix, value)
        return Decimal(string: text, locale: posix) ?? Decimal(value)
    }

    private static func pow10(_ places: Int) -> Decimal {
        var value = Decimal(1)
        if places >= 0 {
            for _ in 0..<places { value *= 10 }
        } else {
            for _ in 0..<(-places) { value /= 10 }
        }
        return value
    }
}
