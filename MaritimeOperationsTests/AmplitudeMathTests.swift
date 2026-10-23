import Testing
import Foundation
@testable import MaritimeOperations

struct AmplitudeMathTests {
    private func close(_ a: Double?, _ b: Double, _ tol: Double = 0.05) -> Bool {
        guard let a else { return false }
        return abs(a - b) <= tol
    }

    // CE-01
    @Test func pixelExample60N20NRising() throws {
        let a = try #require(AmplitudeMath.amplitude(latitude: 60, declination: 20))
        #expect(close(a, 43.2))
        #expect(AmplitudeMath.amplitudeText(a, event: .rising) == "E 43.2 N")
        let t = try #require(AmplitudeMath.trueBearing(latitude: 60, declination: 20, event: .rising))
        #expect(AmplitudeMath.bearing(t) == "046.8°")
        let err = try #require(AmplitudeMath.compassError(trueBearing: t, compassBearing: 49.0))
        #expect(AmplitudeMath.eastWest(err) == "2.2° W")
        let dev = try #require(AmplitudeMath.deviation(error: err, variation: 1.5))
        #expect(AmplitudeMath.eastWest(dev) == "3.7° W")
    }

    // CE-03
    @Test func polarReturnsNil() {
        #expect(AmplitudeMath.amplitude(latitude: 75, declination: 20) == nil)
        #expect(AmplitudeMath.trueBearing(latitude: 75, declination: 20, event: .rising) == nil)
        #expect(AmplitudeMath.trueBearing(latitude: 90, declination: 0, event: .setting) == nil)
        #expect(AmplitudeMath.amplitude(latitude: .nan, declination: 10) == nil)
    }

    @Test func equatorEquinoxRisesDueEast() {
        #expect(close(AmplitudeMath.trueBearing(latitude: 0, declination: 0, event: .rising), 90, 1e-9))
        #expect(close(AmplitudeMath.trueBearing(latitude: 0, declination: 0, event: .setting), 270, 1e-9))
    }

    // CE-02
    @Test func quadrants() throws {
        let setN = try #require(AmplitudeMath.trueBearing(latitude: 60, declination: 20, event: .setting))
        #expect(close(setN, 313.2))
        let riseS = try #require(AmplitudeMath.trueBearing(latitude: 60, declination: -20, event: .rising))
        #expect(close(riseS, 133.2))
        let setS = try #require(AmplitudeMath.trueBearing(latitude: 60, declination: -20, event: .setting))
        #expect(close(setS, 226.8))
        #expect(AmplitudeMath.amplitudeText(-43.16, event: .setting) == "W 43.2 S")
    }

    // CE-04
    @Test func errorSign() throws {
        let w = try #require(AmplitudeMath.compassError(trueBearing: 70, compassBearing: 72))
        #expect(AmplitudeMath.eastWest(w) == "2.0° W")
        let e = try #require(AmplitudeMath.compassError(trueBearing: 72, compassBearing: 70))
        #expect(AmplitudeMath.eastWest(e) == "2.0° E")
    }

    @Test func wraparound() throws {
        #expect(close(AmplitudeMath.compassError(trueBearing: 1, compassBearing: 359), 2, 1e-9))
        #expect(close(AmplitudeMath.compassError(trueBearing: 359, compassBearing: 1), -2, 1e-9))
        #expect(AmplitudeMath.bearing(359.97) == "000.0°")
        #expect(AmplitudeMath.compassError(trueBearing: .infinity, compassBearing: 1) == nil)
    }

    @Test func deviationEastVariation() throws {
        // error 1.0 E, variation 3.0 W → deviation 4.0 E
        #expect(close(AmplitudeMath.deviation(error: 1, variation: -3), 4, 1e-9))
    }

    // Model: states, never NaN
    @Test func modelStates() {
        let m = CompassErrorModel()
        #expect(m.outcome == .incomplete)
        m.latDeg = "60"; m.decDeg = "20"; m.compass = "49"
        guard case .result(let r) = m.outcome else { Issue.record("expected result"); return }
        #expect(r.deviation == nil)
        #expect(m.lastResultSummary == "Last: 2.2° W · true 046.8°")
        m.variation = "1.5"
        guard case .result(let r2) = m.outcome else { Issue.record("expected result"); return }
        #expect(AmplitudeMath.eastWest(r2.deviation ?? .nan) == "3.7° W")
        m.latDeg = "75"
        #expect(m.outcome == .polar)
        #expect(m.lastResultSummary == nil)
        m.latDeg = "91"
        if case .invalid(let f, _) = m.outcome { #expect(f == .latitude) } else { Issue.record("expected invalid") }
        m.latDeg = "60"; m.decDeg = "24"
        if case .invalid(let f, _) = m.outcome { #expect(f == .declination) } else { Issue.record("expected invalid") }
    }

    // Degrees + minutes input
    @Test func dmToDecimal() {
        if case .value(let v) = CompassErrorModel.parseDM(degrees: "20", minutes: "15.3", maxDegrees: 23.5) {
            #expect(abs(v - 20.255) < 1e-9)
        } else { Issue.record("expected value") }
        #expect(CompassErrorModel.parseDM(degrees: "60", minutes: "", maxDegrees: 90) == .value(60))
        #expect(CompassErrorModel.parseDM(degrees: "", minutes: "", maxDegrees: 90) == .empty)
        #expect(CompassErrorModel.dmText(20.255, "N") == "20°15.3′ N")
        // Floor to 0.1′: 20°59.96′ must stay 20°59.9′, never round up to 21°00.0′.
        #expect(CompassErrorModel.dmText(20 + 59.96 / 60, "N") == "20°59.9′ N")
        #expect(CompassErrorModel.dmText(20 + 59.94 / 60, "S") == "20°59.9′ S")
        #expect(CompassErrorModel.dmText(20 + 59.0 / 60, "N") == "20°59.0′ N")
    }

    @Test func dmBounds() {
        func invalid(_ d: String, _ m: String, _ max: Double) -> Bool {
            if case .invalid = CompassErrorModel.parseDM(degrees: d, minutes: m, maxDegrees: max) { return true }
            return false
        }
        #expect(invalid("20", "60", 90))        // minutes must be < 60
        #expect(!invalid("20", "59.9", 90))
        #expect(invalid("20", "-1", 90))
        #expect(invalid("20.5", "0", 90))       // whole degrees only
        #expect(invalid("", "10", 90))          // minutes without degrees
        #expect(!invalid("90", "0", 90))
        #expect(invalid("90", "0.1", 90))       // 90° needs 0′
        #expect(invalid("91", "", 90))
        #expect(!invalid("23", "30", 23.5))     // 23°30′ is the limit
        #expect(invalid("23", "30.1", 23.5))
        #expect(invalid("24", "", 23.5))
    }

    @Test func modelUsesDegreesMinutes() {
        let m = CompassErrorModel()
        m.latDeg = "60"; m.latMin = "0"; m.decDeg = "20"; m.decMin = "0"; m.compass = "49"
        #expect(m.latitudeEcho == "= 60°00.0′ N")
        m.decNS = .s
        #expect(m.declinationEcho == "= 20°00.0′ S")
        guard case .result(let r) = m.outcome else { Issue.record("expected result"); return }
        #expect(AmplitudeMath.bearing(r.trueBearing) == "133.2°")
        m.decMin = "60"
        if case .invalid(let f, _) = m.outcome { #expect(f == .declination) } else { Issue.record("expected invalid") }
        #expect(m.declinationEcho == nil)
    }

    @Test func polarAtOrBeyondLimit() {
        // 70°N, dec 20°N: |lat| + dec = 90 → polar
        #expect(AmplitudeMath.amplitude(latitude: 70, declination: 20) == nil)
        // 66°30′ + 23°30′ = 90 → |sin A| = 1 exactly → polar, not a bearing
        #expect(AmplitudeMath.amplitude(latitude: 66.5, declination: 23.5) == nil)
        #expect(AmplitudeMath.trueBearing(latitude: -66.5, declination: -23.5, event: .setting) == nil)
        let m = CompassErrorModel()
        m.latDeg = "66"; m.latMin = "30"; m.decDeg = "23"; m.decMin = "30"; m.compass = "10"
        #expect(m.outcome == .polar)   // a state, not a field error (23°30′ cap still valid)
        m.latDeg = "70"; m.latMin = ""; m.decDeg = "20"; m.decMin = ""
        #expect(m.outcome == .polar)
        // just inside the limit still gives a bearing
        #expect(AmplitudeMath.amplitude(latitude: 66, declination: 23.5) != nil)
    }

    @Test func bridgeBearingNotation() {
        #expect(AmplitudeMath.bearing(46.8, letter: "T") == "046.8°T")
        #expect(AmplitudeMath.bearing(49.0, letter: "C") == "049.0°C")
        #expect(AmplitudeMath.spokenBearing(49.0, kind: "compass") == "049 point 0 degrees compass")
        #expect(AmplitudeMath.spokenBearing(46.8, kind: "true") == "046 point 8 degrees true")
    }
}
