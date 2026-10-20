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
    var latitude = ""
    var latNS: NS = .n
    var declination = ""
    var decNS: NS = .n
    var compass = ""
    var variation = ""
    var varEW: EW = .e

    var outcome: Outcome {
        let latV = ToolsParse.double(latitude)
        let decV = ToolsParse.double(declination)
        let cV = ToolsParse.double(compass)
        if let latV, latV < 0 || latV > 90 {
            return .invalid(field: .latitude, reason: "Latitude 0 to 90°")
        }
        if let decV, decV < 0 || decV > Self.maxDeclination {
            return .invalid(field: .declination, reason: "Declination 0 to 23.5°")
        }
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
