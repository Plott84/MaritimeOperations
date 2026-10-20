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
        m.latitude = "60"; m.declination = "20"; m.compass = "49"
        guard case .result(let r) = m.outcome else { Issue.record("expected result"); return }
        #expect(r.deviation == nil)
        #expect(m.lastResultSummary == "Last: 2.2° W · true 046.8°")
        m.variation = "1.5"
        guard case .result(let r2) = m.outcome else { Issue.record("expected result"); return }
        #expect(AmplitudeMath.eastWest(r2.deviation ?? .nan) == "3.7° W")
        m.latitude = "75"
        #expect(m.outcome == .polar)
        #expect(m.lastResultSummary == nil)
        m.latitude = "91"
        if case .invalid(let f, _) = m.outcome { #expect(f == .latitude) } else { Issue.record("expected invalid") }
        m.latitude = "60"; m.declination = "24"
        if case .invalid(let f, _) = m.outcome { #expect(f == .declination) } else { Issue.record("expected invalid") }
    }
}
