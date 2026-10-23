import Foundation

/// Compass error from the sun's amplitude at theoretical rise / set
/// (sun's centre on the celestial horizon). Pure maths, no UI. Never returns NaN.
enum AmplitudeMath {
    enum Event: String, CaseIterable, Identifiable, Sendable {
        case rising = "Sunrise"
        case setting = "Sunset"
        var id: String { rawValue }
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }

    /// Signed amplitude in degrees (+ = north of E/W, − = south).
    /// sin A = sin dec / cos lat. `nil` when |sin A| ≥ 1 (sun doesn't rise or set),
    /// at the pole, or for non-finite input.
    static func amplitude(latitude: Double, declination: Double) -> Double? {
        guard latitude.isFinite, declination.isFinite, abs(latitude) < 90, abs(declination) <= 90 else { return nil }
        let c = cos(rad(latitude))
        guard c > 1e-12 else { return nil }
        let s = sin(rad(declination)) / c
        // |sin A| ≥ 1 (incl. exactly 1, e.g. 66°30′ N + 23°30′ N) → sun doesn't rise or set: polar.
        guard s.isFinite, abs(s) < 1 - 1e-12 else { return nil }
        let a = deg(asin(s))
        return a.isFinite ? a : nil
    }

    /// True bearing of the sun: rising 90 − A, setting 270 + A (A signed, + = N). 0..<360.
    static func trueBearing(latitude: Double, declination: Double, event: Event) -> Double? {
        guard let a = amplitude(latitude: latitude, declination: declination) else { return nil }
        let raw = event == .rising ? 90 - a : 270 + a
        return normalize360(raw)
    }

    /// Error = true − compass, wrapped to −180...+180. + = East.
    static func compassError(trueBearing: Double, compassBearing: Double) -> Double? {
        guard trueBearing.isFinite, compassBearing.isFinite else { return nil }
        let w = wrap180(trueBearing - compassBearing)
        return w.isFinite ? w : nil
    }

    /// Deviation = error − variation (both E +), wrapped to −180...+180.
    static func deviation(error: Double, variation: Double) -> Double? {
        guard error.isFinite, variation.isFinite else { return nil }
        return wrap180(error - variation)
    }

    static func normalize360(_ x: Double) -> Double {
        var v = x.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        if v >= 360 { v -= 360 }
        return v
    }

    static func wrap180(_ x: Double) -> Double {
        var v = normalize360(x)
        if v > 180 { v -= 360 }
        return v
    }

    // MARK: Display

    /// "2.2° W", "1.0° E", "0.0°"
    static func eastWest(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        let mag = String(format: "%.1f°", abs(r))
        if r == 0 { return mag }
        return "\(mag) \(r > 0 ? "E" : "W")"
    }

    /// Rounded bearing 0..<360 to 0.1°.
    static func bearingValue(_ v: Double) -> Double {
        var r = (v * 10).rounded() / 10
        if r >= 360 { r -= 360 }
        if r < 0 { r += 360 }
        return r
    }

    /// "046.8°" (no letter). Used in the Tools-tab status line.
    static func bearing(_ v: Double) -> String {
        String(format: "%05.1f°", bearingValue(v))
    }

    /// Bridge notation: "046.8°T" / "049.0°C".
    static func bearing(_ v: Double, letter: String) -> String {
        String(format: "%05.1f°%@", bearingValue(v), letter)
    }

    /// VoiceOver: "049 point 0 degrees compass" / "046 point 8 degrees true".
    static func spokenBearing(_ v: Double, kind: String) -> String {
        let r = bearingValue(v)
        let whole = Int(r)
        let tenths = Int(((r - Double(whole)) * 10).rounded())
        return String(format: "%03d point %d degrees %@", whole, tenths, kind)
    }

    /// "E 43.2 N" (rising, north dec) / "W 12.0 S" (setting, south dec)
    static func amplitudeText(_ a: Double, event: Event) -> String {
        let side = event == .rising ? "E" : "W"
        let r = (abs(a) * 10).rounded() / 10
        let ns = r == 0 ? "" : (a > 0 ? " N" : " S")
        return "\(side) \(String(format: "%.1f", r))\(ns)"
    }
}
