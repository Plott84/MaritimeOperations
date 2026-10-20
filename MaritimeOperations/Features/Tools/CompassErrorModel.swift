import Foundation
import Observation

/// Form state for Compass error by amplitude. Maths: `AmplitudeMath`.
@Observable
final class CompassErrorModel {
    enum NS: String, CaseIterable, Identifiable { case n = "N", s = "S"; var id: String { rawValue } }
    enum EW: String, CaseIterable, Identifiable { case e = "E", w = "W"; var id: String { rawValue } }
    enum Field { case latitude, declination, compass, variation }

    struct Result: Equatable {
        let amplitude: Double
        let trueBearing: Double
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

    var event: AmplitudeMath.Event = .rising
    var latDeg = ""
    var latMin = ""
    var latNS: NS = .n
    var decDeg = ""
    var decMin = ""
    var decNS: NS = .n
    var compass = ""
    var variation = ""
    var varEW: EW = .e

    /// Degrees–minutes text → unsigned decimal degrees.
    enum DM: Equatable {
        case empty
        case invalid(String)
        case value(Double)
    }

    /// Whole degrees (required) + minutes 0..<60 (blank = 0). `maxDegrees` caps the total.
    static func parseDM(degrees d: String, minutes m: String, maxDegrees: Double) -> DM {
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

    var latitudeDM: DM { Self.parseDM(degrees: latDeg, minutes: latMin, maxDegrees: 90) }
    var declinationDM: DM { Self.parseDM(degrees: decDeg, minutes: decMin, maxDegrees: Self.maxDeclination) }

    /// Quiet echo under each input, e.g. "= 20°15.3′ N"; nil unless the input is valid.
    var latitudeEcho: String? {
        if case .value(let v) = latitudeDM { return "= " + Self.dmText(v, latNS.rawValue) }
        return nil
    }
    var declinationEcho: String? {
        if case .value(let v) = declinationDM { return "= " + Self.dmText(v, decNS.rawValue) }
        return nil
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
        guard let a = AmplitudeMath.amplitude(latitude: lat, declination: dec),
              let t = AmplitudeMath.trueBearing(latitude: lat, declination: dec, event: event) else {
            return .polar
        }
        guard let err = AmplitudeMath.compassError(trueBearing: t, compassBearing: cV) else { return .incomplete }
        let dev = varSigned.flatMap { AmplitudeMath.deviation(error: err, variation: $0) }
        return .result(Result(amplitude: a, trueBearing: t, error: err, deviation: dev))
    }

    /// Tools-tab status line for a valid result, e.g. "Last: 2.2° W · true 046.8°".
    var lastResultSummary: String? {
        guard case .result(let r) = outcome else { return nil }
        return "Last: \(AmplitudeMath.eastWest(r.error)) · true \(AmplitudeMath.bearing(r.trueBearing))"
    }
}
