import Foundation
import Observation

/// Form state for the desk gyro check. Text fields are parsed here; maths lives in `GyroMath`.
@Observable
final class GyroCheckModel {
    /// Pixel order: Transit / Sun azimuth / Amplitude.
    enum Mode: String, CaseIterable, Identifiable {
        case transit = "Transit"
        case azimuth = "Sun azimuth"
        case amplitude = "Amplitude"
        var id: String { rawValue }
    }

    enum NS: String, CaseIterable, Identifiable {
        case n = "N"
        case s = "S"
        var id: String { rawValue }
    }

    enum Outcome {
        case incomplete
        case refused(String)
        case result(trueBearing: Double, error: GyroMath.GyroError, hc: Double?)
    }

    var mode: Mode = .transit

    var latDeg = ""
    var latMin = ""
    var latNS: NS = .n
    var decDeg = ""
    var decMin = ""
    var decNS: NS = .n
    var lhaDeg = ""
    var lhaMin = ""
    var event: GyroMath.SunEvent = .rising
    var chartedTrue = ""
    var gyro = ""

    private func num(_ s: String) -> Double? {
        ToolsParse.double(s)
    }

    /// Degrees field required; minutes optional (blank = 0).
    private func dm(_ d: String, _ m: String, south: Bool = false) -> Double? {
        guard let dv = num(d), dv >= 0 else { return nil }
        let mv: Double
        if m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mv = 0
        } else {
            guard let parsed = num(m) else { return nil }
            mv = parsed
        }
        guard mv >= 0, mv < 60 else { return nil }
        return GyroMath.decimal(degrees: dv, minutes: mv, negative: south)
    }

    var outcome: Outcome {
        guard let g = num(gyro), (0..<360).contains(g) else { return .incomplete }
        switch mode {
        case .azimuth:
            guard let lat = dm(latDeg, latMin, south: latNS == .s), abs(lat) <= 90,
                  let dec = dm(decDeg, decMin, south: decNS == .s), abs(dec) <= 90,
                  let lha = dm(lhaDeg, lhaMin), lha < 360 else { return .incomplete }
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
            guard let lat = dm(latDeg, latMin, south: latNS == .s), abs(lat) <= 90,
                  let dec = dm(decDeg, decMin, south: decNS == .s), abs(dec) <= 90 else { return .incomplete }
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
}
