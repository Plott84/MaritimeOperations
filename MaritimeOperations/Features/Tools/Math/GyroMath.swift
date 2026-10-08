import Foundation

/// Gyro-error maths for MaritimeOperations. Pure functions, no UI — Foundation only.
///
/// Conventions (used everywhere, never mixed):
/// - Latitude and declination in decimal degrees, **north positive, south negative**.
/// - LHA in degrees, normalised to 0..<360.
/// - Gyro error = true − gyro, wrapped to −180...+180. Positive = E ("gyro least, error east"), negative = W.
/// - Flag when |error| > 1.0° (exactly 1.0° does not flag).
enum GyroMath {
    static let flagThreshold = 1.0
    /// Absorbs floating-point noise so an error that is 1.0° by the inputs is not flagged as 1.0000000000000002.
    static let flagEpsilon = 1e-9

    // MARK: - Angles

    static func rad(_ d: Double) -> Double { d * .pi / 180 }
    static func deg(_ r: Double) -> Double { r * 180 / .pi }

    /// Degrees + minutes → signed decimal degrees. `negative` = S (lat/dec) or W.
    static func decimal(degrees: Double, minutes: Double, negative: Bool = false) -> Double {
        let v = abs(degrees) + abs(minutes) / 60
        return negative ? -v : v
    }

    /// 0..<360
    static func normalize360(_ x: Double) -> Double {
        var v = x.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        if v >= 360 { v -= 360 }
        return v == 0 ? 0 : v // drop −0
    }

    /// −180...+180
    static func wrap180(_ x: Double) -> Double {
        var v = normalize360(x)
        if v > 180 { v -= 360 }
        return v
    }

    private static func clampUnit(_ x: Double) -> Double { min(1, max(-1, x)) }

    // MARK: - Azimuth (atan2 method)

    struct AzimuthResult: Equatable {
        /// True azimuth by atan2, 0..<360.
        let zn: Double
        /// Computed altitude, degrees.
        let hc: Double
        /// Altitude-azimuth cross-check Zn, 0..<360. nil when the sun is at the zenith (azimuth undefined).
        let crossCheckZn: Double?
    }

    /// Zn = atan2(−cos Dec·sin LHA, cos Lat·sin Dec − sin Lat·cos Dec·cos LHA)
    /// Hc = asin(sin Lat·sin Dec + cos Lat·cos Dec·cos LHA)
    /// Cross-check: cos Z = (sin Dec − sin Lat·sin Hc)/(cos Lat·cos Hc); Zn = Z if LHA > 180 else 360 − Z.
    /// Returns `nil` if any input is non-finite or Zn/Hc are non-finite (UI dash, never "nan°T").
    static func sunAzimuth(latitude: Double, declination: Double, lha: Double) -> AzimuthResult? {
        guard latitude.isFinite, declination.isFinite, lha.isFinite else { return nil }
        let lat = rad(latitude), dec = rad(declination), t = rad(normalize360(lha))
        let y = -cos(dec) * sin(t)
        let x = cos(lat) * sin(dec) - sin(lat) * cos(dec) * cos(t)
        let zn = normalize360(deg(atan2(y, x)))

        let sinHc = clampUnit(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(t))
        let hcRad = asin(sinHc)
        let hc = deg(hcRad)
        guard zn.isFinite, hc.isFinite else { return nil }

        let denom = cos(lat) * cos(hcRad)
        var cross: Double?
        // Sun at/near the zenith (or observer at a pole): azimuth undefined, no cross-check.
        if abs(cos(hcRad)) > 1e-6 && abs(cos(lat)) > 1e-12 {
            let z = deg(acos(clampUnit((sin(dec) - sin(lat) * sinHc) / denom)))
            let c = normalize360(normalize360(lha) > 180 ? z : 360 - z)
            if c.isFinite { cross = c }
        }
        return AzimuthResult(zn: zn, hc: hc, crossCheckZn: cross)
    }

    // MARK: - Amplitude (sun's centre on the celestial horizon)

    enum SunEvent: String, CaseIterable, Identifiable {
        case rising = "Rising", setting = "Setting"
        var id: String { rawValue }
    }

    enum AmplitudeResult: Equatable {
        /// `amplitude` is A in degrees (0...90), `trueBearing` is Zn 0..<360.
        case bearing(amplitude: Double, trueBearing: Double)
        /// Sun does not rise/set on the celestial horizon at this lat/dec — no number.
        case refused(reason: String)
    }

    /// sin A = sin|Dec| / cos|Lat|. Rising DecN 090−A, Rising DecS 090+A, Setting DecN 270+A, Setting DecS 270−A.
    /// Refuses if |Dec| ≥ 90 − |Lat|.
    static func sunAmplitude(latitude: Double, declination: Double, event: SunEvent) -> AmplitudeResult {
        let aLat = abs(latitude), aDec = abs(declination)
        if aDec >= 90 - aLat {
            return .refused(reason: "Sun does not rise or set at this latitude and declination (|Dec| ≥ 90° − |Lat|). No amplitude.")
        }
        let s = sin(rad(aDec)) / cos(rad(aLat))
        guard s.isFinite, abs(s) <= 1 else {
            return .refused(reason: "Sun does not rise or set at this latitude and declination. No amplitude.")
        }
        let a = deg(asin(s))
        let decNorth = declination >= 0
        let zn: Double
        switch (event, decNorth) {
        case (.rising, true): zn = 90 - a
        case (.rising, false): zn = 90 + a
        case (.setting, true): zn = 270 + a
        case (.setting, false): zn = 270 - a
        }
        return .bearing(amplitude: a, trueBearing: normalize360(zn))
    }

    // MARK: - Gyro error

    struct GyroError: Equatable {
        /// Unrounded, −180...+180. Positive = E.
        let value: Double
        var rounded: Double { (value * 10).rounded() / 10 }
        var name: String { rounded == 0 ? "" : (value > 0 ? "E" : "W") }
        var flagged: Bool { abs(value) > GyroMath.flagThreshold + GyroMath.flagEpsilon }
        /// e.g. "1.1° W", "0.0°"
        var display: String {
            let mag = String(format: "%.1f°", abs(rounded))
            return name.isEmpty ? mag : "\(mag) \(name)"
        }
    }

    /// Error = true − gyro, wrapped to −180...+180.
    /// Returns `nil` when either bearing is non-finite, or the difference / wrap is non-finite
    /// (e.g. ±greatestFiniteMagnitude) so UI can show a dash (never "nan° W").
    static func gyroError(trueBearing: Double, gyroBearing: Double) -> GyroError? {
        guard trueBearing.isFinite, gyroBearing.isFinite else { return nil }
        let delta = trueBearing - gyroBearing
        guard delta.isFinite else { return nil }
        let wrapped = wrap180(delta)
        guard wrapped.isFinite else { return nil }
        return GyroError(value: wrapped)
    }

    /// Transit: charted true bearing vs observed gyro bearing. `nil` if either input is non-finite.
    static func transitError(chartedTrue: Double, gyroBearing: Double) -> GyroError? {
        gyroError(trueBearing: chartedTrue, gyroBearing: gyroBearing)
    }

    // MARK: - Display helpers

    /// "128.4°T". Non-finite → "—" (belt-and-suspenders for UI).
    static func bearingDisplay(_ zn: Double) -> String {
        guard zn.isFinite else { return "—" }
        var r = (zn * 10).rounded() / 10
        if r >= 360 { r -= 360 }
        guard r.isFinite else { return "—" }
        return String(format: "%05.1f°T", r)
    }

    /// Signed degrees → "29°19.5'" (sign dropped; caller names N/S if needed).
    /// Non-finite or |d| > 360 → "—" (never Int crash / nan text).
    static func dmDisplay(_ d: Double) -> String {
        guard d.isFinite, abs(d) <= 360 else { return "—" }
        var tenths = (abs(d) * 600).rounded() // tenths of a minute
        guard tenths.isFinite else { return "—" }
        let deg = Int(tenths / 600)
        tenths -= Double(deg) * 600
        return String(format: "%d°%04.1f'", deg, tenths / 10)
    }
}
