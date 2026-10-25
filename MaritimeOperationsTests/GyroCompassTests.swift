import Testing
import Foundation
@testable import MaritimeOperations

struct GyroCompassTests {
    @Test func copyMatchesSpec() {
        #expect(GyroCompassCopy.title == "Gyro & Compass")
        #expect(GyroCompassCopy.footer == "Aid, not authority.")
        #expect(!GyroCompassCopy.footer.contains("Design mock"))
        #expect(!GyroCompassCopy.footer.contains("EXAMPLE"))
        #expect(GyroCompassCopy.polarBody == "Sun doesn't rise or set here")
        #expect(GyroCompassCopy.polarHelper == "|lat| + |dec| ≥ 90° (including exactly 90°). Try a lower latitude or another day. No numbers shown.")
        #expect(GyroCompassCopy.compassSubtitle == "Sun amplitude · declination ≤ 23°30′")
        #expect(GyroCheckModel.Mode.azimuth.rawValue == "Azimuth")
    }

    @Test func sharedLatDecLeavesTabFieldsAlone() {
        let position = LatDecDraft()
        let gyro = GyroCheckModel(position: position)
        let compass = CompassErrorModel(position: position)
        gyro.mode = .azimuth
        gyro.latDeg = "51"
        gyro.latMin = "28"
        gyro.decDeg = "18"
        gyro.decMin = "42"
        gyro.lha = "045.0"
        gyro.gyro = "046.8"
        gyro.chartedTrue = "010.0"
        gyro.event = .setting
        #expect(compass.latitudeEcho == "= 51°28.0′ N")
        #expect(compass.declinationEcho == "= 18°42.0′ N")
        #expect(gyro.latitudeEcho == compass.latitudeEcho)
        compass.compass = "049"
        compass.variation = "1.5"
        compass.event = .setting
        compass.varEW = .w
        gyro.lha = "010"
        #expect(compass.compass == "049")
        #expect(compass.variation == "1.5")
        #expect(compass.event == .setting)
        #expect(compass.varEW == .w)
        #expect(gyro.chartedTrue == "010.0")
        #expect(gyro.event == .setting)
        #expect(gyro.lha == "010")
        compass.decNS = .s
        #expect(gyro.decNS == .s)
        #expect(gyro.declinationEcho == "= 18°42.0′ S")
    }

    @Test func workedCompassExample() throws {
        let m = CompassErrorModel()
        m.latDeg = "60"
        m.decDeg = "20"
        m.event = .rising
        m.compass = "049.0"
        m.variation = "1.5"
        guard case .result(let r) = m.outcome else { Issue.record("expected result"); return }
        #expect(AmplitudeMath.amplitudeText(r.amplitude, event: .rising) == "E 43.2 N")
        #expect(AmplitudeMath.bearing(r.trueBearing, letter: "T") == "046.8°T")
        #expect(AmplitudeMath.bearing(r.compassBearing, letter: "C") == "049.0°C")
        #expect(AmplitudeMath.eastWest(r.error) == "2.2° W")
        #expect(AmplitudeMath.eastWest(r.deviation ?? .nan) == "3.7° W")
        #expect(m.lastResultSummary == "Last compass 2.2° W · true 046.8°T")
        #expect(
            AmplitudeMath.spokenCompassResult(
                error: r.error, trueBearing: r.trueBearing, compassBearing: r.compassBearing
            ) == "Compass error 2.2 degrees West. True 046 point 8 degrees true. Compass 049 point 0 degrees compass."
        )
    }

    @Test func polarGateIncludesEquality() {
        #expect(CompassErrorModel.isPolar(latitude: 70, declination: 20))
        #expect(CompassErrorModel.isPolar(latitude: -70, declination: 20))
        #expect(CompassErrorModel.isPolar(latitude: 66.5, declination: 23.5))
        #expect(!CompassErrorModel.isPolar(latitude: 69.9, declination: 20))
        #expect(!CompassErrorModel.isPolar(latitude: 66, declination: 23.5))

        let equal = CompassErrorModel()
        equal.latDeg = "70"
        equal.decDeg = "20"
        equal.compass = "49"
        #expect(equal.outcome == .polar)
        #expect(equal.lastResultSummary == nil)

        let above = CompassErrorModel()
        above.latDeg = "75"
        above.decDeg = "20"
        above.compass = "49"
        #expect(above.outcome == .polar)

        let south = CompassErrorModel()
        south.latDeg = "70"
        south.latNS = .s
        south.decDeg = "20"
        south.decNS = .s
        south.compass = "10"
        #expect(south.outcome == .polar)
    }

    @Test func declinationCapIsCompassOnly() {
        let position = LatDecDraft()
        let gyro = GyroCheckModel(position: position)
        let compass = CompassErrorModel(position: position)
        gyro.mode = .azimuth
        gyro.latDeg = "10"
        gyro.decDeg = "23"
        gyro.decMin = "31"
        gyro.lha = "45"
        gyro.gyro = "10"
        compass.compass = "10"
        if case .invalid(let field, let reason) = compass.outcome {
            #expect(field == .declination)
            #expect(reason == "Declination 0 to 23°30′")
        } else {
            Issue.record("expected declination error")
        }
        #expect(compass.lastResultSummary == nil)
        guard case .result = gyro.outcome else { Issue.record("gyro azimuth still reduces past 23°30′"); return }
        #expect(gyro.declinationError == nil)
        #expect(gyro.declinationEcho == "= 23°31.0′ N")
    }

    @Test func latitudeOver90IsInlineError() {
        let position = LatDecDraft()
        let gyro = GyroCheckModel(position: position)
        let compass = CompassErrorModel(position: position)
        gyro.latDeg = "91"
        gyro.decDeg = "10"
        gyro.mode = .azimuth
        gyro.lha = "45"
        gyro.gyro = "10"
        compass.compass = "10"
        #expect(gyro.latitudeError == "Latitude 0 to 90° (90° needs 0′)")
        if case .invalid(let field, _) = compass.outcome {
            #expect(field == .latitude)
        } else {
            Issue.record("expected latitude error")
        }
        if case .result = gyro.outcome { Issue.record("no gyro result past 90°") }
    }

    /// Spec inputs 51°28.0′ N, 18°42.0′ N, LHA 045.0, gyro 046.8.
    /// `GyroMath.sunAzimuth` is the atan2 sight. The mock hero 047.5°T / 0.7° E is
    /// example chrome (047.5 − 046.8), not this sight.
    @Test func gyroAzimuthSample() throws {
        let gyro = GyroCheckModel()
        gyro.mode = .azimuth
        gyro.latDeg = "51"
        gyro.latMin = "28"
        gyro.decDeg = "18"
        gyro.decMin = "42"
        gyro.lha = "045.0"
        gyro.gyro = "046.8"
        guard case .result(let zn, let err, let hc) = gyro.outcome else {
            Issue.record("expected azimuth result")
            return
        }
        #expect(GyroMath.bearingDisplay(zn) == "244.2°T")
        let altitude = try #require(hc)
        #expect(GyroMath.dmDisplay(altitude) == "41°55.0'")
        #expect(err.display == "162.6° W")
        #expect(err.flagged)
        #expect(GyroMath.spokenResult(trueBearing: zn, error: err) == "True bearing 244 point 2 degrees true. Gyro error 162.6 degrees West.")
    }

    @Test func mockHeroIsTransitArithmeticNotAzimuth() throws {
        let err = try #require(GyroMath.gyroError(trueBearing: 47.5, gyroBearing: 46.8))
        #expect(err.display == "0.7° E")
        #expect(!err.flagged)
        #expect(GyroMath.spokenResult(trueBearing: 47.5, error: err) == "True bearing 047 point 5 degrees true. Gyro error 0.7 degrees East.")

        let gyro = GyroCheckModel()
        gyro.mode = .transit
        gyro.chartedTrue = "047.5"
        gyro.gyro = "046.8"
        guard case .result(let zn, let transit, let hc) = gyro.outcome else {
            Issue.record("expected transit result")
            return
        }
        #expect(hc == nil)
        #expect(GyroMath.bearingDisplay(zn) == "047.5°T")
        #expect(transit.display == "0.7° E")
        #expect(!transit.flagged)
    }

    @Test func gyroErrorFlagsOnlyAboveOneDegree() throws {
        let exact = try #require(GyroMath.gyroError(trueBearing: 1, gyroBearing: 0))
        #expect(!exact.flagged)
        #expect(exact.display == "1.0° E")
        let over = try #require(GyroMath.gyroError(trueBearing: 1.1, gyroBearing: 0))
        #expect(over.flagged)
        #expect(over.display == "1.1° E")
    }
}
