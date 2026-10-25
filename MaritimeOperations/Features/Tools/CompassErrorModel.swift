import Foundation
import Observation

/// Form state for Compass error by amplitude. Maths: `AmplitudeMath`.
/// Latitude and declination live on a shared `LatDecDraft` with the Gyro tab.
@Observable
final class CompassErrorModel {
    typealias NS = LatDecDraft.NS
    enum EW: String, CaseIterable, Identifiable { case e = "E", w = "W"; var id: String { rawValue } }
    enum Field: Equatable { case latitude, declination, compass, variation }

    struct Result: Equatable {
        let amplitude: Double
        let trueBearing: Double
        let compassBearing: Double
        let error: Double
        let deviation: Double?
    }

    enum Outcome: Equatable {
        case incomplete
        case invalid(field: Field, reason: String)
        case polar
        case result(Result)
    }

    static let maxDeclination = 23.5

    var position: LatDecDraft
    var event: AmplitudeMath.Event = .rising
    var compass = ""
    var variation = ""
    var varEW: EW = .e

    init(position: LatDecDraft = LatDecDraft()) {
        self.position = position
    }

    var latDeg: String {
        get { position.latDeg }
        set { position.latDeg = newValue }
    }
    var latMin: String {
        get { position.latMin }
        set { position.latMin = newValue }
    }
    var latNS: NS {
        get { position.latNS }
        set { position.latNS = newValue }
    }
    var decDeg: String {
        get { position.decDeg }
        set { position.decDeg = newValue }
    }
    var decMin: String {
        get { position.decMin }
        set { position.decMin = newValue }
    }
    var decNS: NS {
        get { position.decNS }
        set { position.decNS = newValue }
    }

    /// Degrees–minutes text → unsigned decimal degrees.
    enum DM: Equatable {
        case empty
        case invalid(String)
        case value(Double)
    }

    /// Whole degrees (required) + minutes 0..<60 (blank = 0). `maxDegrees` caps the total.
    /// `outOfRange` replaces the default latitude / declination sentence when the total is over the cap.
    static func parseDM(degrees d: String, minutes m: String, maxDegrees: Double, outOfRange: String? = nil) -> DM {
        let dTrim = d.trimmingCharacters(in: .whitespacesAndNewlines)
        let mTrim = m.trimmingCharacters(in: .whitespacesAndNewlines)
        if dTrim.isEmpty { return mTrim.isEmpty ? .empty : .invalid("Enter whole degrees") }
        guard let dv = ToolsParse.double(dTrim), dv >= 0, dv == dv.rounded() else {
            return .invalid("Whole degrees, 0 to \(Int(maxDegrees.rounded(.down)))")
        }
        var mv = 0.0
        if !mTrim.isEmpty {
            guard let parsed = ToolsParse.double(mTrim), parsed >= 0, parsed < 60 else {
                return .invalid("Minutes 0 to 59.9")
            }
            mv = parsed
        }
        let total = GyroMath.decimal(degrees: dv, minutes: mv)
        guard total <= maxDegrees + 1e-9 else {
            if let outOfRange { return .invalid(outOfRange) }
            return .invalid(maxDegrees == 90 ? "Latitude 0 to 90° (90° needs 0′)" : "Declination 0 to 23°30′")
        }
        return .value(total)
    }

    /// "20°15.3′ N". Minutes are floored to 0.1′ so 20°59.96′ shows as 20°59.9′, never 21°00.0′.
    static func dmText(_ v: Double, _ hemi: String) -> String {
        let totalTenths = abs(v) * 600  // tenths of a minute
        // Floor (with a tiny epsilon so exact tenths stay exact), never round up into the next degree.
        var tenths = (totalTenths + 1e-9).rounded(.down)
        if tenths < 0 { tenths = 0 }
        let deg = Int(tenths / 600)
        tenths -= Double(deg) * 600
        return String(format: "%d°%04.1f′ ", deg, tenths / 10) + hemi
    }

    /// Quiet echo under a valid deg+min field, e.g. "= 20°15.3′ N".
    static func echo(degrees: String, minutes: String, hemisphere: String, maxDegrees: Double) -> String? {
        if case .value(let v) = parseDM(degrees: degrees, minutes: minutes, maxDegrees: maxDegrees) {
            return "= " + dmText(v, hemisphere)
        }
        return nil
    }

    /// Screen polar gate: |lat| + |dec| ≥ 90°, including equality.
    static func isPolar(latitude: Double, declination: Double) -> Bool {
        guard latitude.isFinite, declination.isFinite else { return false }
        return abs(latitude) + abs(declination) >= 90 - 1e-9
    }

    var latitudeDM: DM { Self.parseDM(degrees: latDeg, minutes: latMin, maxDegrees: 90) }
    var declinationDM: DM { Self.parseDM(degrees: decDeg, minutes: decMin, maxDegrees: Self.maxDeclination) }

    /// Quiet echo under each input, e.g. "= 20°15.3′ N"; nil unless the input is valid.
    var latitudeEcho: String? {
        Self.echo(degrees: latDeg, minutes: latMin, hemisphere: latNS.rawValue, maxDegrees: 90)
    }
    var declinationEcho: String? {
        Self.echo(degrees: decDeg, minutes: decMin, hemisphere: decNS.rawValue, maxDegrees: Self.maxDeclination)
    }

    var outcome: Outcome {
        var latV: Double?
        var decV: Double?
        switch latitudeDM {
        case .invalid(let r): return .invalid(field: .latitude, reason: r)
        case .value(let v): latV = v
        case .empty: break
        }
        switch declinationDM {
        case .invalid(let r): return .invalid(field: .declination, reason: r)
        case .value(let v): decV = v
        case .empty: break
        }
        let cV = ToolsParse.double(compass)
        if let cV, cV < 0 || cV >= 360 {
            return .invalid(field: .compass, reason: "Compass bearing 0 to 359.9°")
        }
        var varSigned: Double? = nil
        switch ToolsParse.optionalDouble(variation) {
        case nil:
            return .invalid(field: .variation, reason: "Check variation")
        case .some(let v?):
            guard v >= 0, v <= 180 else { return .invalid(field: .variation, reason: "Variation 0 to 180°") }
            varSigned = varEW == .e ? v : -v
        case .some(nil):
            break
        }
        guard let latV, let decV, let cV else { return .incomplete }
        let lat = latNS == .s ? -latV : latV
        let dec = decNS == .s ? -decV : decV
        if Self.isPolar(latitude: lat, declination: dec) { return .polar }
        guard let a = AmplitudeMath.amplitude(latitude: lat, declination: dec),
              let t = AmplitudeMath.trueBearing(latitude: lat, declination: dec, event: event) else {
            return .polar
        }
        guard let err = AmplitudeMath.compassError(trueBearing: t, compassBearing: cV) else { return .incomplete }
        let dev = varSigned.flatMap { AmplitudeMath.deviation(error: err, variation: $0) }
        return .result(Result(amplitude: a, trueBearing: t, compassBearing: cV, error: err, deviation: dev))
    }

    /// Tools-row line for a valid compass result, e.g. "Last compass 2.2° W · true 046.8°T".
    var lastResultSummary: String? {
        guard case .result(let r) = outcome else { return nil }
        return "Last compass \(AmplitudeMath.eastWest(r.error)) · true \(AmplitudeMath.bearing(r.trueBearing, letter: "T"))"
    }
}
