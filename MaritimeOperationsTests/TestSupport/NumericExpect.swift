import Foundation
import Testing

/// Number checks that accept either decimal separator.
///
/// A readout that follows the current locale may show `4.29` or `4,29`.
/// Parse the digits, then compare the `Double` within a tolerance.
/// `#expect` comments in this file are string literals or interpolations.
/// Swift Testing does not accept a `String` variable as a comment.
enum NumericExpect {
    /// Every number in `text`. `.` and `,` are decimal separators when a digit follows.
    /// A comma is not a thousands separator, so `1,000` is `1`.
    static func numbers(in text: String) -> [Double] {
        scan(text, massesOnly: false)
    }

    /// Numbers that sit in front of a mass unit (`t`, `tonne(s)`, `kg`, `kilogram(s)`).
    /// Angles and mode factors stay out. Same rule as the rigging readouts.
    static func masses(in text: String) -> [Double] {
        scan(text, massesOnly: true)
    }

    /// `got` is within `tolerance` of `want`.
    static func expectClose(_ got: Double, _ want: Double, tolerance: Double = 0.001) {
        #expect(abs(got - want) < tolerance, "\(got) vs \(want)")
    }

    /// The readout has one mass, equal to `expected` (for example `"4.29"`).
    static func expectMass(_ text: String, _ expected: String, tolerance: Double = 0.001) {
        let got = masses(in: text)
        let want = Double(expected) ?? .nan
        #expect(got.count == 1, "\(text) → \(got)")
        #expect(abs((got.first ?? .nan) - want) < tolerance, "\(text)")
    }

    /// Masses in `text`, in order, match `expected`.
    static func expectMasses(_ text: String, _ expected: [String], tolerance: Double = 0.001) {
        let got = masses(in: text)
        let wants = expected.map { Double($0) ?? .nan }
        #expect(got.count == wants.count, "\(text) → \(got)")
        for (value, want) in zip(got, wants) {
            #expect(abs(value - want) < tolerance, "\(text)")
        }
    }

    /// The one mass is not the rejected figure (`4.29` is not `4.28`).
    static func expectNotMass(_ text: String, _ rejected: String) {
        let got = masses(in: text)
        let bad = Double(rejected) ?? .nan
        #expect(got.count == 1, "\(text) → \(got)")
        #expect(abs((got.first ?? .nan) - bad) >= 0.005, "\(text)")
    }

    private static func scan(_ text: String, massesOnly: Bool) -> [Double] {
        let chars = Array(text)
        var values: [Double] = []
        var index = 0
        while index < chars.count {
            guard let (value, end) = readAmount(chars, from: index) else {
                index += 1
                continue
            }
            if !massesOnly || hasMassUnit(chars, from: end) {
                values.append(value)
            }
            index = max(end, index + 1)
        }
        return values
    }

    private static func readAmount(_ chars: [Character], from start: Int) -> (Double, Int)? {
        var index = start
        var digits = ""
        var sawDigit = false
        var sawSeparator = false
        if chars[index] == "-" {
            digits.append("-")
            index += 1
            if index >= chars.count { return nil }
        }
        while index < chars.count {
            let ch = chars[index]
            if ch.isASCII && ch.isNumber {
                digits.append(ch)
                sawDigit = true
                index += 1
                continue
            }
            if sawDigit && !sawSeparator && (ch == "." || ch == ",") {
                let next = index + 1
                if next < chars.count, chars[next].isASCII, chars[next].isNumber {
                    digits.append(".")
                    sawSeparator = true
                    index += 1
                    continue
                }
            }
            break
        }
        guard sawDigit, let value = Double(digits) else { return nil }
        return (value, index)
    }

    private static func hasMassUnit(_ chars: [Character], from start: Int) -> Bool {
        var index = start
        while index < chars.count, chars[index] == " " || chars[index] == "\u{00A0}" {
            index += 1
        }
        let rest = String(chars[index...])
        if rest.hasPrefix("tonnes") || rest.hasPrefix("tonne") { return true }
        if rest.hasPrefix("kilograms") || rest.hasPrefix("kilogram") { return true }
        if rest.hasPrefix("kg") { return true }
        guard rest.hasPrefix("t") else { return false }
        let after = rest.dropFirst()
        guard let next = after.first else { return true }
        return !next.isLetter
    }
}

struct NumericExpectTests {
    @Test func dotAndCommaParseAsTheSameNumber() {
        let dot = NumericExpect.numbers(in: "≥ 4.29 t")
        let comma = NumericExpect.numbers(in: "≥ 4,29 t")
        #expect(dot.count == 1, "\(dot)")
        #expect(comma.count == 1, "\(comma)")
        NumericExpect.expectClose(dot.first ?? .nan, comma.first ?? .nan)
        NumericExpect.expectClose(dot.first ?? .nan, 4.29)
    }

    @Test func aMassIgnoresTheFactorBesideIt() {
        NumericExpect.expectMass("factor 1.307 · 3,93 t/leg", "3.93")
        NumericExpect.expectNotMass("≥ 4,29 t", "4.28")
        NumericExpect.expectMasses("0.80 tonnes on a 1,00 tonne block", ["0.80", "1.00"])
    }
}
