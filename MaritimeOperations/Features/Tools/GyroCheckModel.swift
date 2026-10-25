import Foundation
import Observation

/// Form state for the desk gyro check. Text fields are parsed here; maths lives in `GyroMath`.
/// Latitude and declination live on a shared `LatDecDraft` so the Compass tab sees the same position.
@Observable
final class GyroCheckModel {
    /// Pixel order: Transit / Azimuth / Amplitude.
    enum Mode: String, CaseIterable, Identifiable {
        case transit = "Transit"
        case azimuth = "Azimuth"
        case amplitude = "Amplitude"
        var id: String { rawValue }
    }

    typealias NS = LatDecDraft.NS

    enum Outcome {
        case incomplete
        case refused(String)
        case result(trueBearing: Double, error: GyroMath.GyroError, hc: Double?)
    }

    var position: LatDecDraft
    var mode: Mode = .transit

    var lha = ""
    var event: GyroMath.SunEvent = .rising
    var chartedTrue = ""
    var gyro = ""

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

    var latitudeEcho: String? {
        CompassErrorModel.echo(degrees: latDeg, minutes: latMin, hemisphere: latNS.rawValue, maxDegrees: 90)
    }
    var declinationEcho: String? {
        CompassErrorModel.echo(degrees: decDeg, minutes: decMin, hemisphere: decNS.rawValue, maxDegrees: 90)
    }
    var latitudeError: String? { Self.fieldError(latDeg, latMin, max: 90) }
    var declinationError: String? {
        Self.fieldError(decDeg, decMin, max: 90, outOfRange: Self.declinationCap)
    }

    /// Gyro declination is not the sun's 23°30′ cap (that gate is the Compass tab).
    static let declinationCap = "Declination 0 to 90° (90° needs 0′)"

    private static func fieldError(_ degrees: String, _ minutes: String, max: Double, outOfRange: String? = nil) -> String? {
        if case .invalid(let reason) = CompassErrorModel.parseDM(
            degrees: degrees, minutes: minutes, maxDegrees: max, outOfRange: outOfRange
        ) {
            return reason
        }
        return nil
    }

    private func num(_ s: String) -> Double? {
        ToolsParse.double(s)
    }

    /// Whole degrees + minutes, blank minutes = 0. Nil when empty or invalid.
    private func signed(_ d: String, _ m: String, south: Bool, max: Double, outOfRange: String? = nil) -> Double? {
        guard case .value(let v) = CompassErrorModel.parseDM(
            degrees: d, minutes: m, maxDegrees: max, outOfRange: outOfRange
        ) else { return nil }
        return south ? -v : v
    }

    var outcome: Outcome {
        guard let g = num(gyro), (0..<360).contains(g) else { return .incomplete }
        switch mode {
        case .azimuth:
            guard let lat = signed(latDeg, latMin, south: latNS == .s, max: 90),
                  let dec = signed(decDeg, decMin, south: decNS == .s, max: 90, outOfRange: Self.declinationCap),
                  let lha = num(lha), (0..<360).contains(lha) else { return .incomplete }
            guard let r = GyroMath.sunAzimuth(latitude: lat, declination: dec, lha: lha) else {
                return .incomplete
            }
            // Zenith / pole: cross-check nil → refuse with words, never a bearing.
            if r.crossCheckZn == nil {
                return .refused("Sun is at the zenith (or you are at a pole): azimuth is undefined. No bearing.")
            }
            guard let err = GyroMath.gyroError(trueBearing: r.zn, gyroBearing: g) else {
                return .incomplete
            }
            return .result(trueBearing: r.zn, error: err, hc: r.hc)

        case .amplitude:
            guard let lat = signed(latDeg, latMin, south: latNS == .s, max: 90),
                  let dec = signed(decDeg, decMin, south: decNS == .s, max: 90, outOfRange: Self.declinationCap) else { return .incomplete }
            switch GyroMath.sunAmplitude(latitude: lat, declination: dec, event: event) {
            case .refused(let reason):
                return .refused(reason)
            case .bearing(_, let zn):
                guard let err = GyroMath.gyroError(trueBearing: zn, gyroBearing: g) else {
                    return .incomplete
                }
                return .result(trueBearing: zn, error: err, hc: nil)
            }

        case .transit:
            guard let t = num(chartedTrue), (0..<360).contains(t) else { return .incomplete }
            guard let err = GyroMath.transitError(chartedTrue: t, gyroBearing: g) else {
                return .incomplete
            }
            return .result(trueBearing: t, error: err, hc: nil)
        }
    }

    /// Tools-row line for a valid gyro result, e.g. "Last gyro +1.2° · 14 Oct".
    func lastResultSummary(date: Date = .now) -> String? {
        guard case .result(_, let err, _) = outcome else { return nil }
        return ToolLastResultStore.gyroSummary(error: err.value, date: date)
    }
}
