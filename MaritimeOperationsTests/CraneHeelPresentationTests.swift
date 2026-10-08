import XCTest
@testable import MaritimeOperations

/// Copy rules for CraneHeelView (Pixel + Builder lock, 2026-10-06), tested on Linux through the pure presentation.
@MainActor
final class CraneHeelPresentationTests: XCTestCase {
    typealias P = CraneHeelPresentation

    /// Builder case C, the mock's example: θ 90, R 20, PL 80, Δ 8000, GM 1.5, tanks 12 m apart.
    private let caseC = P.Inputs(azimuth: "90", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.5", tankDistance: "12")

    private func p(_ i: P.Inputs) -> P { P(inputs: i) }
    private func with(_ base: P.Inputs, _ f: P.Field, _ v: String) -> P.Inputs { var b = base; b[f] = v; return b }

    // MARK: Case C strings (mock)

    func testCaseCStrings() {
        let s = p(caseC)
        XCTAssertEqual(s.status, .ok)
        XCTAssertEqual(s.heelValueText, "+7.6")
        XCTAssertEqual(s.sideText, "Stbd")
        XCTAssertEqual(s.liveHeelText, "+7.6° Stbd")
        XCTAssertEqual(s.livePillText, "Soft heel · 5° or more")
        XCTAssertEqual(s.resultPillText, "Soft heel to stbd · 5° or more")
        XCTAssertEqual(s.tone, .soft)
        XCTAssertEqual(s.ballast?.value, "133.3")
        XCTAssertEqual(s.ballast?.unit, "t")
        XCTAssertEqual(s.ballast?.caption, "to move stbd tank → port tank")
        XCTAssertEqual(s.ballast?.text, "133.3 t to move stbd tank → port tank")
        XCTAssertEqual(s.ballast?.sketchCaption, "to port tank")
        XCTAssertEqual(s.ballast?.accessibilityLabel, "Ballast to level: move 133.3 tonnes from starboard tank to port tank")
        XCTAssertEqual(s.legend.map(\.text), ["Clear <5°", "Soft ≥5°", "Hard ≥10°"])
        XCTAssertEqual(s.legend.map(\.isActive), [false, true, false])
        XCTAssertEqual(s.ringAzimuthDeg, 90)
        XCTAssertEqual(s.glyphRotationDeg, 7.6)
        XCTAssertEqual(s.heelAccessibilityLabel, "Heel 7.6 degrees to starboard. Soft heel to stbd · 5° or more")
    }

    // MARK: 0.0 pill + ballast hidden

    func testZeroHeelPillHasNoSide() {
        for az in ["0", "180", "360", "-180"] {          // boom on centreline
            let s = p(with(caseC, .azimuth, az))
            XCTAssertEqual(s.heelValueText, "0.0", az)
            XCTAssertEqual(s.resultPillText, "Clear · under 5°", az)
            XCTAssertEqual(s.livePillText, "Clear · under 5°", az)
            XCTAssertEqual(s.liveHeelText, "0.0° Upright", az)
            XCTAssertNil(s.ballast, "ballast hidden on CL (\(az))")
            XCTAssertEqual(s.legend.map(\.isActive), [true, false, false])
        }
        // Zero load, boom abeam: upright, ballast hidden.
        let z = p(with(caseC, .hookLoad, "0"))
        XCTAssertEqual(z.resultPillText, "Clear · under 5°"); XCTAssertNil(z.ballast)
    }

    func testMinusZeroPointZeroFourShowsUprightNoBallast() {
        // Reference case V: raw −0.04° → shows 0.0, upright, no "to port", no ballast line, no "-0.0".
        let s = p(P.Inputs(azimuth: "270", outreach: "1", hookLoad: "0.0838", displacement: "8000", gm: "0.4", tankDistance: "12"))
        XCTAssertEqual(s.heelValueText, "0.0")
        XCTAssertEqual(s.sideText, "Upright")
        XCTAssertEqual(s.resultPillText, "Clear · under 5°")
        XCTAssertNil(s.ballast)
        XCTAssertEqual(s.heelAccessibilityLabel, "Heel 0.0 degrees, upright. Clear · under 5°")
    }

    func testBallastHiddenWithoutTankDistance() {
        let s = p(with(caseC, .tankDistance, ""))
        XCTAssertEqual(s.status, .ok)
        XCTAssertNil(s.ballast)
        XCTAssertEqual(s.heelValueText, "+7.6")
    }

    // MARK: Direction text

    func testDirectionTextPortLift() {
        let s = p(with(caseC, .azimuth, "270"))
        XCTAssertEqual(s.heelValueText, "-7.6")
        XCTAssertEqual(s.liveHeelText, "-7.6° Port")
        XCTAssertEqual(s.resultPillText, "Soft heel to port · 5° or more")
        XCTAssertEqual(s.ballast?.text, "133.3 t to move port tank → stbd tank")
        XCTAssertEqual(s.ballast?.sketchCaption, "to stbd tank")
        XCTAssertEqual(s.ballast?.accessibilityLabel, "Ballast to level: move 133.3 tonnes from port tank to starboard tank")
        // Wrapped −90 gives the same.
        XCTAssertEqual(p(with(caseC, .azimuth, "-90")).ballast?.text, "133.3 t to move port tank → stbd tank")
        XCTAssertEqual(p(with(caseC, .azimuth, "-90")).ringAzimuthDeg, 270)
    }

    func testHardAndClearPillsWithSide() {
        // Case J: hard to stbd; mirrored to port.
        let j = P.Inputs(azimuth: "90", outreach: "36", hookLoad: "100", displacement: "8000", gm: "1.5")
        XCTAssertEqual(p(j).resultPillText, "Hard heel to stbd · 10° or more")
        XCTAssertEqual(p(j).livePillText, "Hard heel · 10° or more")
        XCTAssertEqual(p(j).tone, .hard)
        XCTAssertEqual(p(with(j, .azimuth, "270")).resultPillText, "Hard heel to port · 10° or more")
        // Case I: 1.0° stbd, clear but not zero.
        let i = P.Inputs(azimuth: "90", outreach: "10", hookLoad: "20", displacement: "8000", gm: "1.5")
        XCTAssertEqual(p(i).resultPillText, "Clear to stbd · under 5°")
        XCTAssertEqual(p(i).livePillText, "Clear · under 5°")
        // Display cap.
        let u = P.Inputs(azimuth: "90", outreach: "36", hookLoad: "250", displacement: "10", gm: "0.01")
        XCTAssertEqual(p(u).heelValueText, "+90.0"); XCTAssertEqual(p(u).glyphRotationDeg, 45)
    }

    func testResultPillPureFunction() {
        XCTAssertEqual(P.resultPill(tone: .clear, heelDeg: 0, side: .upright), "Clear · under 5°")
        XCTAssertEqual(P.resultPill(tone: .soft, heelDeg: 5.0, side: .stbd), "Soft heel to stbd · 5° or more")
        XCTAssertEqual(P.resultPill(tone: .hard, heelDeg: -10.0, side: .port), "Hard heel to port · 10° or more")
        XCTAssertEqual(P.ballastCaption(pumpTo: .port), "to move stbd tank → port tank")
        XCTAssertEqual(P.ballastCaption(pumpTo: .stbd), "to move port tank → stbd tank")
        XCTAssertEqual(P.formatHeel(-0.0), "0.0")
        XCTAssertEqual(P.formatHeel(0.04), "0.0")
        XCTAssertEqual(P.formatHeel(10.0), "+10.0")
        XCTAssertEqual(P.formatHeel(-5.0), "-5.0")
    }

    // MARK: Empty start, no defaults

    func testEmptyStartShowsDashesAndNoDefaults() {
        let s = p(.empty)
        XCTAssertEqual(P.Inputs.empty, P.Inputs(azimuth: "", outreach: "", hookLoad: "", displacement: "", gm: "", pivotOffset: "", tankDistance: ""))
        XCTAssertEqual(s.status, .incomplete)
        XCTAssertNil(s.errorField)
        XCTAssertEqual(s.heelValueText, "—")
        XCTAssertEqual(s.liveHeelText, "—")
        XCTAssertNil(s.resultPillText); XCTAssertNil(s.livePillText); XCTAssertNil(s.ballast); XCTAssertNil(s.tone)
        XCTAssertNil(s.ringAzimuthDeg)
        XCTAssertEqual(s.legend.map(\.isActive), [false, false, false])
        // Every field missing Δ or GM → still incomplete (never falls back to a default ship value).
        XCTAssertEqual(p(with(caseC, .displacement, "")).status, .incomplete)
        XCTAssertEqual(p(with(caseC, .gm, "")).status, .incomplete)
        XCTAssertEqual(p(with(caseC, .azimuth, "")).status, .incomplete)
        // No field placeholder looks like a default number, apart from pivot (empty = 0.0 on CL).
        for f in P.Field.allCases where f != .pivotOffset {
            XCTAssertNil(Double(f.placeholder.replacingOccurrences(of: ",", with: ".")), "\(f) placeholder looks numeric")
        }
        XCTAssertEqual(P.Field.pivotOffset.placeholder, "On CL")   // B2 (2026-10-07): was "0.0"
    }

    func testFooterAndNoExampleLine() {
        XCTAssertEqual(P.footer, "Deck estimate for static heel. Not a class or loading-computer calculation.")
        XCTAssertFalse(P.footer.contains("Example"))
    }

    // MARK: Field copy

    func testFieldLabelsHelpersAndIDs() {
        XCTAssertEqual(P.Field.tankDistance.title, "Distance between tanks (m)")
        XCTAssertEqual(P.Field.tankDistance.helper, "Port tank to stbd tank, measured across.")
        XCTAssertEqual(P.Field.hookLoad.helper, "cargo + hook + rigging + spreader")
        XCTAssertEqual(P.Field.displacement.helper, "Displacement incl. lift (t)")
        XCTAssertEqual(P.Field.pivotOffset.helper, "Crane pivot off centreline, + to stbd. Empty = on CL.")
        XCTAssertEqual(P.Field.outreach.title, "Outreach R (m)")
        XCTAssertEqual(P.Field.hookLoad.title, "Hook load PL (t)")
        XCTAssertEqual(P.Field.displacement.title, "Displacement Δ (t)")
        XCTAssertEqual(P.Field.gm.title, "GM (m)")
        XCTAssertEqual(P.Field.allCases.map(\.accessibilityIdentifier),
                       ["craneField.azimuth", "craneField.outreach", "craneField.hookLoad", "craneField.displacement",
                        "craneField.gm", "craneField.pivotOffset", "craneField.tankDistance",
                        "craneField.startAzimuth", "craneField.startOutreach"])   // B2 (2026-10-07): + 2 Start fields
    }

    // MARK: Errors

    func testFieldErrors() {
        XCTAssertEqual(p(with(caseC, .gm, "abc")).status, .invalid(field: .gm, reason: "Check GM"))
        XCTAssertEqual(p(with(caseC, .gm, "0")).status, .invalid(field: .gm, reason: "Check GM"))
        XCTAssertEqual(p(with(caseC, .gm, "inf")).status, .invalid(field: .gm, reason: "Check GM"))
        XCTAssertEqual(p(with(caseC, .displacement, "nan")).status, .invalid(field: .displacement, reason: "Check displacement"))
        XCTAssertEqual(p(with(caseC, .outreach, "1e400")).status, .invalid(field: .outreach, reason: "Check outreach"))
        XCTAssertEqual(p(with(caseC, .outreach, "-1")).status, .invalid(field: .outreach, reason: "Check outreach"))
        XCTAssertEqual(p(with(caseC, .hookLoad, "-5")).status, .invalid(field: .hookLoad, reason: "Check hook load"))
        XCTAssertEqual(p(with(caseC, .tankDistance, "0")).status, .invalid(field: .tankDistance, reason: "Check distance between tanks"))
        XCTAssertEqual(p(with(caseC, .tankDistance, "-12")).status, .invalid(field: .tankDistance, reason: "Check distance between tanks"))
        XCTAssertEqual(p(with(caseC, .pivotOffset, "x")).status, .invalid(field: .pivotOffset, reason: "Check pivot offset"))
        XCTAssertEqual(p(with(caseC, .azimuth, "0x10")).status, .invalid(field: .azimuth, reason: "Check boom azimuth"))
        // A typed-but-bad field is flagged even while another required field is still empty.
        var i = with(caseC, .gm, ""); i.outreach = "abc"
        XCTAssertEqual(p(i).errorField, .outreach)
        // Error state shows dashes, no pill, no ballast.
        let e = p(with(caseC, .gm, "0"))
        XCTAssertEqual(e.heelValueText, "—"); XCTAssertNil(e.resultPillText); XCTAssertNil(e.ballast)
        // Absurd magnitudes → general reason, not tied to a field.
        let g = p(P.Inputs(azimuth: "90", outreach: "20", hookLoad: "80", displacement: "1e-200", gm: "1e-200"))
        XCTAssertEqual(g.status, .invalid(field: nil, reason: "Check inputs"))
        XCTAssertEqual(g.generalErrorReason, "Check inputs")
    }

    func testHalfTypedNumbersAreIncompleteNotRed() {
        for t in ["-", ".", ",", "-.", "+"] {
            XCTAssertEqual(p(with(caseC, .pivotOffset, t)).status, .incomplete, "pivot '\(t)'")
            XCTAssertEqual(p(with(caseC, .gm, t)).status, .incomplete, "gm '\(t)'")
        }
    }

    // MARK: Parsing

    func testParse() {
        XCTAssertEqual(P.parse("1,5"), .value(1.5))
        XCTAssertEqual(P.parse(" 1.50 "), .value(1.5))
        XCTAssertEqual(P.parse("8 000"), .value(8000))
        XCTAssertEqual(P.parse("8\u{00A0}000"), .value(8000))
        XCTAssertEqual(P.parse("-2.5"), .value(-2.5))
        XCTAssertEqual(P.parse("1e3"), .value(1000))
        XCTAssertEqual(P.parse(""), .empty)
        XCTAssertEqual(P.parse("-"), .partial)
        for bad in ["abc", "inf", "-inf", "nan", "infinity", "0x10", "1.2.3", "1e400", "12t"] {
            XCTAssertEqual(P.parse(bad), .invalid, bad)
        }
        // Comma decimal and pivot to port feed the math.
        let s = p(P.Inputs(azimuth: "270", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1,5", pivotOffset: "5"))
        XCTAssertEqual(s.heelValueText, "-5.7")   // reference case M
        let sp = p(P.Inputs(azimuth: "0", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.5", pivotOffset: "5"))
        XCTAssertEqual(sp.heelValueText, "+1.9")  // reference case L
    }

    // MARK: Ring

    func testRingDragMapping() {
        XCTAssertEqual(P.azimuthFromDrag(dx: 0, dy: -10), 0)    // up = bow
        XCTAssertEqual(P.azimuthFromDrag(dx: 10, dy: 0), 90)    // right = stbd
        XCTAssertEqual(P.azimuthFromDrag(dx: 0, dy: 10), 180)   // down = aft
        XCTAssertEqual(P.azimuthFromDrag(dx: -10, dy: 0), 270)  // left = port
        XCTAssertEqual(P.azimuthFromDrag(dx: 10, dy: -10), 45)
        XCTAssertEqual(P.azimuthFromDrag(dx: -0.01, dy: -10), 0) // 359.94 snaps to 360 → wraps to 0
        XCTAssertNil(P.azimuthFromDrag(dx: 0, dy: 0))
        XCTAssertNil(P.azimuthFromDrag(dx: .nan, dy: 1))
    }

    func testRingAdjustableActionAndValue() {
        XCTAssertEqual(P.stepAzimuth(90, increment: true), 95)
        XCTAssertEqual(P.stepAzimuth(355, increment: true), 0)
        XCTAssertEqual(P.stepAzimuth(0, increment: false), 355)
        XCTAssertEqual(P.stepAzimuth(nil, increment: true), 5)
        XCTAssertEqual(P.stepAzimuth(-90, increment: true), 275)
        XCTAssertEqual(P.azimuthFieldText(95), "95")
        XCTAssertEqual(P.azimuthFieldText(359.6), "0")
        XCTAssertEqual(P.ringAccessibilityValue(nil), "Not set")
        XCTAssertEqual(P.ringAccessibilityValue(0), "0 degrees, over the bow, on centreline")
        XCTAssertEqual(P.ringAccessibilityValue(90), "90 degrees, starboard beam")
        XCTAssertEqual(P.ringAccessibilityValue(180), "180 degrees, over the stern, on centreline")
        XCTAssertEqual(P.ringAccessibilityValue(-90), "270 degrees, port beam")
        XCTAssertEqual(P.ringAccessibilityValue(45), "45 degrees, starboard side")
        XCTAssertEqual(P.ringAccessibilityValue(200.5), "200.5 degrees, port side")
    }

    func testSliderSync() {
        XCTAssertEqual(P.sliderValue(forAzimuthText: ""), 0)
        XCTAssertEqual(P.sliderValue(forAzimuthText: "360"), 360)
        XCTAssertEqual(P.sliderValue(forAzimuthText: "-90"), 270)
        XCTAssertEqual(P.sliderValue(forAzimuthText: "450"), 90)
        XCTAssertEqual(P.sliderValue(forAzimuthText: "abc"), 0)
        XCTAssertEqual(P.sliderFieldText(359.6), "360")
        XCTAssertEqual(P.sliderFieldText(89.5), "90")
        XCTAssertEqual(p(with(caseC, .azimuth, P.sliderFieldText(360))).heelValueText, "0.0")
    }

    /// Presentation never disagrees with the math: shown heel text == formatted Result.heelDeg, ballast visibility identical.
    func testPresentationMatchesMathOnSweep() {
        var n = 0
        for az in stride(from: -360.0, through: 720.0, by: 7.5) {
            for gm in ["0.3", "1.2", "1.5", "4"] {
                for tank in ["", "12"] {
                    let i = P.Inputs(azimuth: String(az), outreach: "20", hookLoad: "80", displacement: "8000", gm: gm, pivotOffset: "-1.5", tankDistance: tank)
                    let s = p(i)
                    guard case .ok(let r) = CraneHeelMath.heel(azimuthDeg: az, outreach: 20, hookLoad: 80, displacement: 8000,
                                                               gm: Double(gm)!, pivotOffset: -1.5, ballastLever: tank.isEmpty ? nil : 12) else {
                        XCTFail("math rejected"); continue
                    }
                    XCTAssertEqual(s.result, r)
                    XCTAssertEqual(s.heelValueText, P.formatHeel(r.heelDeg))
                    XCTAssertEqual(s.ballast == nil, r.ballastTonnes == nil)
                    XCTAssertFalse(s.heelValueText.hasPrefix("-0.0") || s.heelValueText == "+0.0")
                    if r.heelDeg == 0 { XCTAssertEqual(s.resultPillText, "Clear · under 5°"); XCTAssertNil(s.ballast) }
                    n += 1
                }
            }
        }
        XCTAssertEqual(n, 145 * 4 * 2)
    }
}
