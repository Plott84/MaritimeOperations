import XCTest
@testable import MaritimeOperations

/// B2 screen rules (Pixel crane-heel-B2.png + QA/Pixel locks 2026-10-07), tested through the pure presentation.
@MainActor
final class CraneHeelB2PresentationTests: XCTestCase {
    typealias P = CraneHeelPresentation

    /// Builder case C ship + the B2 example lift: Start aft 180° · 12 m → End stbd 90° · 20 m.
    private let b2 = P.Inputs(azimuth: "90", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.5",
                              tankDistance: "12", startAzimuth: "180", startOutreach: "12")

    private func p(_ i: P.Inputs) -> P { P(inputs: i) }
    private func with(_ base: P.Inputs, _ changes: [P.Field: String]) -> P.Inputs {
        var b = base; for (f, v) in changes { b[f] = v }; return b
    }

    // MARK: Named cases through the screen

    func testB2ExampleStrings() throws {
        let s = p(b2)
        XCTAssertEqual(s.status, .ok)
        let lift = try XCTUnwrap(s.lift)
        XCTAssertEqual(lift.mode, .move)
        XCTAssertNil(s.result, "single-point Result is nil in move mode")
        XCTAssertEqual(s.heelValueText, "+7.6"); XCTAssertEqual(s.sideText, "Stbd")
        XCTAssertEqual(s.livePillText, "Soft heel · 5° or more")
        XCTAssertEqual(s.resultPillText, "Soft heel to stbd · 5° or more")
        XCTAssertEqual(s.tone, .soft)
        XCTAssertEqual(s.ballast?.value, "133.3"); XCTAssertEqual(s.ballast?.unit, "t")
        XCTAssertEqual(s.ballast?.direction, "stbd tank → port tank")
        XCTAssertEqual(s.ballast?.qualifier, "for this lift")
        XCTAssertEqual(s.ballast?.caption, "to move stbd tank → port tank")
        XCTAssertEqual(s.ballast?.signedTonnes, 133.3)
        XCTAssertEqual(s.ballast?.pumpTo, .port)
        XCTAssertEqual(s.note, "Ship level at start")
        XCTAssertNil(s.ballastPrompt)
        XCTAssertEqual(s.startRowText, "Aft 180° · 12 m")
        XCTAssertEqual(s.endRowText, "Stbd 90° · 20 m")
        XCTAssertEqual(s.endRowHeelText, "+7.6°")
        XCTAssertEqual(s.ringAzimuthDeg, 90); XCTAssertEqual(s.startRingAzimuthDeg, 180)
        XCTAssertFalse(s.isStartBlank)
        XCTAssertEqual(s.glyphRotationDeg, 7.6, "stern view looking forward: + = stbd down = clockwise")
        XCTAssertEqual(s.heelAccessibilityLabel, "Heel 7.6 degrees to starboard. Soft heel to stbd · 5° or more")
    }

    func testNamedMoves() {
        // Stbd 20 → CL: −7.6 soft, 133.3 t into the stbd tank (tile flips).
        let a = p(with(b2, [.startAzimuth: "90", .startOutreach: "20", .azimuth: "180", .outreach: "20"]))
        XCTAssertEqual(a.heelValueText, "-7.6"); XCTAssertEqual(a.tone, .soft)
        XCTAssertEqual(a.ballast?.value, "133.3"); XCTAssertEqual(a.ballast?.direction, "port tank → stbd tank")
        XCTAssertEqual(a.ballast?.signedTonnes, -133.3); XCTAssertEqual(a.glyphRotationDeg, -7.6)
        XCTAssertEqual(a.endRowText, "Aft 180° · 20 m"); XCTAssertEqual(a.startRowText, "Stbd 90° · 20 m")
        // Stbd 20 → port 20: −14.9 hard, 266.7 t into stbd; port → stbd mirrors.
        let b = p(with(b2, [.startAzimuth: "90", .startOutreach: "20", .azimuth: "270", .outreach: "20"]))
        XCTAssertEqual(b.heelValueText, "-14.9"); XCTAssertEqual(b.tone, .hard)
        XCTAssertEqual(b.resultPillText, "Hard heel to port · 10° or more")
        XCTAssertEqual(b.ballast?.text, "266.7 t to move port tank → stbd tank")
        let c = p(with(b2, [.startAzimuth: "270", .startOutreach: "20", .azimuth: "90", .outreach: "20"]))
        XCTAssertEqual(c.heelValueText, "+14.9"); XCTAssertEqual(c.ballast?.text, "266.7 t to move stbd tank → port tank")
        // Stbd 10 → stbd 20: +3.8, no warning, 66.7 t.
        let d = p(with(b2, [.startAzimuth: "90", .startOutreach: "10"]))
        XCTAssertEqual(d.heelValueText, "+3.8"); XCTAssertEqual(d.tone, .clear)
        XCTAssertEqual(d.resultPillText, "Clear to stbd · under 5°"); XCTAssertEqual(d.ballast?.value, "66.7")
        // No move / 30 → 150: 0.0, tile hidden, no prompt, no "-0.0".
        for (s, e) in [("90", "90"), ("30", "150")] {
            let z = p(with(b2, [.startAzimuth: s, .startOutreach: "20", .azimuth: e, .outreach: "20"]))
            XCTAssertEqual(z.heelValueText, "0.0"); XCTAssertEqual(z.sideText, "Upright")
            XCTAssertEqual(z.resultPillText, "Clear · under 5°"); XCTAssertNil(z.ballast); XCTAssertNil(z.ballastPrompt)
            XCTAssertEqual(z.endRowHeelText, "0.0°"); XCTAssertEqual(z.gaugeNeedleDialDeg, 0)
            XCTAssertEqual(z.gaugeNeedleDialDeg?.sign, .plus)
        }
        // Pivot 5 m: identical screen.
        XCTAssertEqual(p(with(b2, [.pivotOffset: "5"])).lift, p(b2).lift)
        XCTAssertEqual(p(with(b2, [.pivotOffset: "5"])).heelValueText, "+7.6")
        // Start blank, pivot 5 m, boom at the bow → 1.9 (single point).
        let l = p(P.Inputs(azimuth: "0", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.5", pivotOffset: "5"))
        XCTAssertEqual(l.heelValueText, "+1.9"); XCTAssertEqual(l.lift?.mode, .single); XCTAssertNotNil(l.result)
        // End −270 counts as 90.
        let w = p(with(b2, [.azimuth: "-270"]))
        XCTAssertEqual(w.heelValueText, "+7.6"); XCTAssertEqual(w.ringAzimuthDeg, 90); XCTAssertEqual(w.endRowText, "Stbd 90° · 20 m")
    }

    func testQATieShowsPointOneWithTile() {
        // QA MOVE.md #1: exact geometry gives raw 0.05° → +0.1, tile "0.9 t".
        let s = p(with(b2, [.azimuth: "0.3750027725481633", .pivotOffset: "7.3"]))
        XCTAssertEqual(s.heelValueText, "+0.1")
        XCTAssertEqual(s.ballast?.text, "0.9 t to move stbd tank → port tank")
    }

    // MARK: Start validation

    func testStartRejects() {
        // Only one Start field filled → invalid on the empty one, no result.
        let a = p(with(b2, [.startOutreach: ""]))
        XCTAssertEqual(a.status, .invalid(field: .startOutreach, reason: CraneHeelMath.MoveReason.startIncomplete))
        XCTAssertNil(a.lift); XCTAssertEqual(a.heelValueText, "—"); XCTAssertNil(a.note); XCTAssertNil(a.ballast)
        let b = p(with(b2, [.startAzimuth: ""]))
        XCTAssertEqual(b.status, .invalid(field: .startAzimuth, reason: CraneHeelMath.MoveReason.startIncomplete))
        // Bad numbers in Start.
        XCTAssertEqual(p(with(b2, [.startOutreach: "-1"])).status, .invalid(field: .startOutreach, reason: "Check start outreach"))
        XCTAssertEqual(p(with(b2, [.startOutreach: "inf"])).status, .invalid(field: .startOutreach, reason: "Check start outreach"))
        XCTAssertEqual(p(with(b2, [.startOutreach: "1e400"])).status, .invalid(field: .startOutreach, reason: "Check start outreach"))
        XCTAssertEqual(p(with(b2, [.startAzimuth: "nan"])).status, .invalid(field: .startAzimuth, reason: "Check start azimuth"))
        XCTAssertEqual(p(with(b2, [.startAzimuth: "abc"])).status, .invalid(field: .startAzimuth, reason: "Check start azimuth"))
        // Negative End outreach still flagged on the End field.
        XCTAssertEqual(p(with(b2, [.outreach: "-3"])).status, .invalid(field: .outreach, reason: "Check outreach"))
        // Half-typed Start ("-", ".") is incomplete, not red.
        XCTAssertEqual(p(with(b2, [.startOutreach: "-"])).status, .incomplete)
        XCTAssertEqual(p(with(b2, [.startAzimuth: "."])).status, .incomplete)
        // Whitespace-only Start counts as blank → single point.
        XCTAssertEqual(p(with(b2, [.startAzimuth: "  ", .startOutreach: " "])).lift?.mode, .single)
        // Start fields: titles, ids, optional, non-numeric placeholders.
        XCTAssertEqual(P.Field.startAzimuth.accessibilityIdentifier, "craneField.startAzimuth")
        XCTAssertEqual(P.Field.startOutreach.accessibilityIdentifier, "craneField.startOutreach")
        XCTAssertFalse(P.Field.startAzimuth.isRequired); XCTAssertFalse(P.Field.startOutreach.isRequired)
        XCTAssertEqual(P.Field.startAzimuth.placeholder, "Optional")
        XCTAssertEqual(P.Field.startAzimuth.unit, "°"); XCTAssertEqual(P.Field.startOutreach.unit, "m")
    }

    // MARK: Notes

    func testNotes() {
        let single = P.Inputs(azimuth: "90", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.5", tankDistance: "12")
        XCTAssertEqual(p(b2).note, "Ship level at start")
        XCTAssertEqual(p(with(b2, [.pivotOffset: "5"])).note, "Ship level at start")
        XCTAssertEqual(p(with(b2, [.pivotOffset: "0"])).note, "Ship level at start")
        XCTAssertEqual(p(single).note, "Crane on CL assumed")
        XCTAssertEqual(p(with(single, [.pivotOffset: "0"])).note, nil, "typed 0 pivot gets no note")
        XCTAssertEqual(p(with(single, [.pivotOffset: "0.0"])).note, nil)
        XCTAssertEqual(p(with(single, [.pivotOffset: "5"])).note, nil)
        XCTAssertEqual(p(with(single, [.pivotOffset: " "])).note, "Crane on CL assumed", "whitespace = blank")
        // No result → no note.
        XCTAssertNil(p(.empty).note)
        XCTAssertNil(p(with(b2, [.gm: ""])).note)
        // Never both, never a stray note: sweep.
        for s in ["", "180", "90"] {
            for pv in ["", "0", "3", "-2"] {
                let st = p(with(b2, [.startAzimuth: s, .startOutreach: s.isEmpty ? "" : "12", .pivotOffset: pv]))
                switch st.note {
                case "Ship level at start"?: XCTAssertFalse(s.isEmpty)
                case "Crane on CL assumed"?: XCTAssertTrue(s.isEmpty && pv.isEmpty)
                case nil: XCTAssertTrue(s.isEmpty && !pv.isEmpty)
                default: XCTFail("unexpected note \(String(describing: st.note))")
                }
            }
        }
        XCTAssertEqual(P.Field.pivotOffset.placeholder, "On CL")
    }

    // MARK: Ballast rules

    func testBallastRoundsHalfAwayFromZero() {
        // w = MH/d = 3/12 = 0.25 exactly: half-away gives 0.3 (String(format: "%.1f") would give 0.2).
        let s = p(P.Inputs(azimuth: "90", outreach: "1", hookLoad: "3", displacement: "100", gm: "1", tankDistance: "12"))
        XCTAssertEqual(s.ballast?.value, "0.3")
        XCTAssertEqual(String(format: "%.1f", 0.25), "0.2", "documents why %.1f was not used")
        // Port side mirror → -0.3 signed, value "0.3".
        let m = p(P.Inputs(azimuth: "270", outreach: "1", hookLoad: "3", displacement: "100", gm: "1", tankDistance: "12"))
        XCTAssertEqual(m.ballast?.value, "0.3"); XCTAssertEqual(m.ballast?.signedTonnes, -0.3)
        // 1.05 → 1.1, 2.5 → 2.5 (format is stable).
        let s2 = p(P.Inputs(azimuth: "90", outreach: "1", hookLoad: "12.6", displacement: "100", gm: "1", tankDistance: "12"))
        XCTAssertEqual(s2.ballast?.value, "1.1")
    }

    func testBallastHiddenWhenItRoundsToZero() {
        // QA MOVE.md gap 1: heel +0.1 but w = 0.5/12 = 0.042 t → shows 0.0 t → tile hidden.
        let s = p(P.Inputs(azimuth: "90", outreach: "1", hookLoad: "0.5", displacement: "500", gm: "1", tankDistance: "12",
                           startAzimuth: "0", startOutreach: "5"))
        XCTAssertEqual(s.heelValueText, "+0.1")
        XCTAssertNotNil(s.lift?.ballastTonnes, "math still returns the unrounded value (reference)")
        XCTAssertNil(s.ballast)
        XCTAssertNil(s.ballastPrompt, "tank distance is filled, so no prompt either")
        // Single point too: w = 0.04 t with a big heel.
        let t = p(P.Inputs(azimuth: "90", outreach: "1", hookLoad: "0.48", displacement: "1", gm: "1", tankDistance: "12"))
        XCTAssertNotEqual(t.heelValueText, "0.0"); XCTAssertNil(t.ballast)
        // 0.055 t shows 0.1 → tile shown. (0.6/12 is 0.049999999999999996 in binary → 0.0, hidden.)
        XCTAssertNil(p(P.Inputs(azimuth: "90", outreach: "1", hookLoad: "0.6", displacement: "1", gm: "1", tankDistance: "12")).ballast)
        let u = p(P.Inputs(azimuth: "90", outreach: "1", hookLoad: "0.66", displacement: "1", gm: "1", tankDistance: "12"))
        XCTAssertEqual(u.ballast?.value, "0.1")
    }

    func testTankDistanceBlankShowsPrompt() {
        let s = p(with(b2, [.tankDistance: ""]))
        XCTAssertEqual(s.status, .ok); XCTAssertEqual(s.heelValueText, "+7.6")
        XCTAssertNil(s.ballast)
        XCTAssertEqual(s.ballastPrompt, "Add distance between tanks to see ballast")
        // Single point as well.
        let single = P.Inputs(azimuth: "90", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.5")
        XCTAssertEqual(p(single).ballastPrompt, P.ballastPromptText)
        // Heel 0.0 → nothing to ballast → no prompt.
        XCTAssertNil(p(with(b2, [.tankDistance: "", .startAzimuth: "90", .startOutreach: "20"])).ballastPrompt)
        // Tank distance filled, or no result → no prompt.
        XCTAssertNil(p(b2).ballastPrompt)
        XCTAssertNil(p(.empty).ballastPrompt)
        // Single-point tile says "to level".
        XCTAssertEqual(p(with(single, [.tankDistance: "12"])).ballast?.qualifier, "to level")
    }

    // MARK: Lift rows

    func testLiftRows() {
        XCTAssertEqual(P.positionText(azimuthText: "180", outreachText: "12"), "Aft 180° · 12 m")
        XCTAssertEqual(P.positionText(azimuthText: "0", outreachText: "7.5"), "Bow 0° · 7.5 m")
        XCTAssertEqual(P.positionText(azimuthText: "360", outreachText: "20"), "Bow 0° · 20 m")
        XCTAssertEqual(P.positionText(azimuthText: "-90", outreachText: "20"), "Port 270° · 20 m")
        XCTAssertEqual(P.positionText(azimuthText: "45.5", outreachText: "12,25"), "Stbd 45.5° · 12.25 m")
        XCTAssertEqual(P.positionText(azimuthText: "200", outreachText: ""), "Port 200° · —")
        XCTAssertEqual(P.positionText(azimuthText: "", outreachText: "12"), "— · 12 m")
        XCTAssertEqual(P.positionText(azimuthText: "359.96", outreachText: "1"), "Bow 0° · 1 m")
        XCTAssertNil(P.positionText(azimuthText: "", outreachText: ""))
        XCTAssertNil(P.positionText(azimuthText: "abc", outreachText: "-"))
        // Start blank → no Start row text, End row has the heel.
        let s = p(with(b2, [.startAzimuth: "", .startOutreach: ""]))
        XCTAssertNil(s.startRowText); XCTAssertTrue(s.isStartBlank); XCTAssertEqual(s.endRowHeelText, "+7.6°")
        XCTAssertNil(p(.empty).endRowHeelText)
        XCTAssertEqual(P.LiftPosition.start.segmentTitle, "Start · on deck")
        XCTAssertEqual(P.LiftPosition.end.segmentTitle, "End · over side")
        XCTAssertEqual(P.LiftPosition.start.azimuthField, .startAzimuth)
        XCTAssertEqual(P.LiftPosition.end.outreachField, .outreach)
        XCTAssertEqual(P.LiftPosition.start.rowAccessibilityIdentifier, "craneLift.start")
        XCTAssertEqual(P.LiftPosition.end.segmentAccessibilityIdentifier, "craneLift.segment.end")
    }

    func testSketchPositions() {
        XCTAssertEqual(P.sketchPosition(azimuthText: "180", outreachText: "12"), P.SketchPosition(azimuthDeg: 180, outreach: 12, y: 0))
        XCTAssertEqual(P.sketchPosition(azimuthText: "-90", outreachText: "20")?.y, -20)
        XCTAssertEqual(P.sketchPosition(azimuthText: "450", outreachText: "20")?.y, 20)
        XCTAssertNil(P.sketchPosition(azimuthText: "90", outreachText: ""))
        XCTAssertNil(P.sketchPosition(azimuthText: "90", outreachText: "-1"))
    }

    // MARK: Quick angles + drag

    func testQuickAngles() {
        XCTAssertEqual(P.QuickAngle.allCases.map(\.degrees), [0, 90, 180, 270])
        XCTAssertEqual(P.QuickAngle.allCases.map(\.title), ["Bow", "Stbd", "Aft", "Port"])
        XCTAssertEqual(P.QuickAngle.allCases.map(\.accessibilityIdentifier),
                       ["craneQuick.bow", "craneQuick.stbd", "craneQuick.aft", "craneQuick.port"])
        XCTAssertEqual(P.QuickAngle.gridOrder, [.port, .bow, .stbd, .aft])
        XCTAssertEqual(P.QuickAngle.stbd.subtitle, "90°"); XCTAssertEqual(P.QuickAngle.port.fieldText, "270")
        XCTAssertTrue(P.QuickAngle.stbd.isSelected(azimuthText: "-270"))
        XCTAssertTrue(P.QuickAngle.bow.isSelected(azimuthText: "360"))
        XCTAssertFalse(P.QuickAngle.bow.isSelected(azimuthText: ""))
        XCTAssertFalse(P.QuickAngle.stbd.isSelected(azimuthText: "90.5"))
        // A quick button writes the field; the screen follows.
        XCTAssertEqual(p(with(b2, [.azimuth: P.QuickAngle.port.fieldText])).heelValueText, "-7.6")
    }

    func testDragWrapsPast360() {
        XCTAssertEqual(P.dragAzimuthText(dx: 0, dy: -10), "0")
        XCTAssertEqual(P.dragAzimuthText(dx: 10, dy: 0), "90")
        XCTAssertEqual(P.dragAzimuthText(dx: -0.01, dy: -10), "0", "359.94 snaps to 360 → wraps to 0, never \"360\"")
        XCTAssertEqual(P.dragAzimuthText(dx: 0.2, dy: -10), "1")
        XCTAssertEqual(P.dragAzimuthText(dx: -0.2, dy: -10), "359")
        XCTAssertNil(P.dragAzimuthText(dx: 0, dy: 0))
        XCTAssertEqual(P.rotatedAzimuth(350, byDeg: 20), 10)
        XCTAssertEqual(P.rotatedAzimuth(10, byDeg: -20), 350)
        XCTAssertEqual(P.rotatedAzimuth(359, byDeg: 1), 0)
        XCTAssertEqual(P.rotatedAzimuth(0, byDeg: -720), 0)
        XCTAssertEqual(P.rotatedAzimuth(0, byDeg: -720).sign, .plus)
    }

    // MARK: Gauge (stretched dial, fixed sections)

    func testGaugeMappingExactAtTicks() {
        let pairs: [(Double, Double)] = [(0, 0), (5, 20), (10, 40), (20, 60), (-5, -20), (-10, -40), (-20, -60),
                                         (2.5, 10), (7.5, 30), (15, 50), (-7.6, -30.4), (90, 60), (-90, -60), (25, 60)]
        for (h, d) in pairs {
            XCTAssertEqual(P.gaugeDialDeg(forHeel: h), d, accuracy: 1e-12, "heel \(h)")
        }
        // 5° and 10° land EXACTLY (bit-for-bit) on their ticks and on the zone edges.
        XCTAssertEqual(P.gaugeDialDeg(forHeel: 5), 20); XCTAssertEqual(P.gaugeDialDeg(forHeel: 10), 40)
        XCTAssertEqual(P.gaugeDialDeg(forHeel: -5), -20); XCTAssertEqual(P.gaugeDialDeg(forHeel: -10), -40)
        let t5 = P.gaugeTicks.first { $0.heelDeg == 5 }!, t10 = P.gaugeTicks.first { $0.heelDeg == 10 }!
        XCTAssertEqual(t5.dialDeg, 20); XCTAssertTrue(t5.isMajor); XCTAssertEqual(t5.label, "5")
        XCTAssertEqual(t10.dialDeg, 40); XCTAssertTrue(t10.isMajor); XCTAssertEqual(t10.label, "10")
        let zones = P.gaugeZones(activeHeel: nil)
        XCTAssertEqual(zones.map(\.id), ["port.hard", "port.soft", "clear", "stbd.soft", "stbd.hard"])
        XCTAssertEqual(zones.first { $0.id == "stbd.soft" }?.fromDial, t5.dialDeg)
        XCTAssertEqual(zones.first { $0.id == "stbd.soft" }?.toDial, t10.dialDeg)
        XCTAssertEqual(zones.first { $0.id == "port.soft" }?.toDial, -20)
        for (a, b) in zip(zones, zones.dropFirst()) { XCTAssertEqual(a.toDial, b.fromDial, "zones are contiguous") }
        XCTAssertEqual(zones.first?.fromDial, -60); XCTAssertEqual(zones.last?.toDial, 60)
        XCTAssertFalse(zones.contains { $0.isActive })
        // Equal dial span per section ("fixed sections").
        XCTAssertEqual(P.gaugeBreakDials, [0, 20, 40, 60]); XCTAssertEqual(P.gaugeBreakHeels, [0, 5, 10, 20])
        // Ticks: every 5° of heel, labels 0 / 5 / 10 only.
        XCTAssertEqual(P.gaugeTicks.map(\.heelDeg), [-20, -15, -10, -5, 0, 5, 10, 15, 20])
        XCTAssertEqual(P.gaugeTicks.compactMap(\.label), ["10", "5", "0", "5", "10"])
        // Edge inputs.
        XCTAssertEqual(P.gaugeDialDeg(forHeel: .nan), 0)
        XCTAssertEqual(P.gaugeDialDeg(forHeel: .infinity), 60); XCTAssertEqual(P.gaugeDialDeg(forHeel: -.infinity), -60)
        XCTAssertEqual(P.gaugeDialDeg(forHeel: -0.0).sign, .plus)
    }

    func testGaugeMonotonicOddContinuous() {
        var prev = -Double.infinity
        var h = -30.0
        while h <= 30.0 {
            let d = P.gaugeDialDeg(forHeel: h)
            XCTAssertGreaterThanOrEqual(d, prev, "monotonic at \(h)")
            XCTAssertEqual(d, -P.gaugeDialDeg(forHeel: -h), accuracy: 1e-12, "odd at \(h)")
            if prev.isFinite { XCTAssertLessThanOrEqual(d - prev, 0.04 + 1e-9, "continuous at \(h)") }   // max slope 4°/° × 0.01
            prev = d
            h += 0.01
        }
    }

    /// Needle, active zone and pill always use the same rounded heel — incl. the 4.95 / 9.95 display ties.
    func testGaugeNeedleZonePillAgree() {
        var n = 0
        for az in stride(from: 0.0, to: 360.0, by: 3.0) {
            for gm in ["0.3", "0.8", "1.5", "4"] {
                for start in ["", "180"] {
                    let s = p(P.Inputs(azimuth: String(az), outreach: "20", hookLoad: "80", displacement: "8000", gm: gm,
                                       tankDistance: "12", startAzimuth: start, startOutreach: start.isEmpty ? "" : "12"))
                    guard let lift = s.lift, let tone = s.tone else { XCTFail("no result"); continue }
                    XCTAssertEqual(s.gaugeNeedleDialDeg, P.gaugeDialDeg(forHeel: lift.heelDeg))
                    let active = s.gaugeZones.filter(\.isActive)
                    XCTAssertEqual(active.count, 1)
                    XCTAssertEqual(active.first?.tone, tone, "zone tone == pill tone at \(lift.heelDeg)")
                    if let z = active.first, let needle = s.gaugeNeedleDialDeg, !s.gaugeIsPegged {
                        XCTAssertTrue(needle >= min(z.fromDial, z.toDial) && needle <= max(z.fromDial, z.toDial),
                                      "needle \(needle) inside \(z.id) for heel \(lift.heelDeg)")
                    }
                    XCTAssertEqual(s.heelValueText, P.formatHeel(lift.heelDeg))
                    n += 1
                }
            }
        }
        XCTAssertEqual(n, 120 * 4 * 2)
        // Raw 4.95 / 9.95 → shown 5.0 / 10.0 → soft / hard zone, needle exactly on the 5 / 10 tick.
        func gmFor(_ deg: Double) -> String { String(0.1 / tan(deg * (Double.pi / 180.0))) }
        let s5 = p(P.Inputs(azimuth: "90", outreach: "10", hookLoad: "10", displacement: "1000", gm: gmFor(4.96)))
        XCTAssertEqual(s5.heelValueText, "+5.0"); XCTAssertEqual(s5.gaugeNeedleDialDeg, 20)
        XCTAssertEqual(s5.gaugeZones.first(where: \.isActive)?.id, "stbd.soft"); XCTAssertEqual(s5.tone, .soft)
        let s10 = p(P.Inputs(azimuth: "270", outreach: "10", hookLoad: "10", displacement: "1000", gm: "0.5700366328693822"))
        XCTAssertEqual(s10.heelValueText, "-10.0"); XCTAssertEqual(s10.gaugeNeedleDialDeg, -40)
        XCTAssertEqual(s10.gaugeZones.first(where: \.isActive)?.id, "port.hard"); XCTAssertEqual(s10.tone, .hard)
        let s49 = p(P.Inputs(azimuth: "90", outreach: "10", hookLoad: "10", displacement: "1000", gm: gmFor(4.94)))
        XCTAssertEqual(s49.heelValueText, "+4.9"); XCTAssertEqual(s49.gaugeZones.first(where: \.isActive)?.id, "clear")
        XCTAssertEqual(s49.gaugeNeedleDialDeg ?? 0, 19.6, accuracy: 1e-12)
        // Pegged beyond 20°.
        let big = p(P.Inputs(azimuth: "90", outreach: "36", hookLoad: "250", displacement: "12000", gm: "2"))
        XCTAssertEqual(big.heelValueText, "+20.6"); XCTAssertTrue(big.gaugeIsPegged); XCTAssertEqual(big.gaugeNeedleDialDeg, 60)
        XCTAssertEqual(big.gaugeAccessibilityValue, "+20.6 degrees, hard zone, starboard, beyond the dial")
        XCTAssertEqual(p(b2).gaugeAccessibilityValue, "+7.6 degrees, soft zone, starboard")
        XCTAssertNil(p(.empty).gaugeNeedleDialDeg); XCTAssertFalse(p(.empty).gaugeZones.contains { $0.isActive })
    }

    // MARK: Single-point screen unchanged by B2

    func testSinglePointScreenUnchanged() {
        let c = P.Inputs(azimuth: "90", outreach: "20", hookLoad: "80", displacement: "8000", gm: "1.5", tankDistance: "12")
        let s = p(c)
        XCTAssertEqual(s.lift?.mode, .single)
        XCTAssertEqual(s.lift?.single, s.result)
        guard case .ok(let r) = CraneHeelMath.heel(azimuthDeg: 90, outreach: 20, hookLoad: 80, displacement: 8000, gm: 1.5, ballastLever: 12) else {
            return XCTFail("rejected")
        }
        XCTAssertEqual(s.result, r)
        XCTAssertEqual(s.ballast?.text, "133.3 t to move stbd tank → port tank")
        XCTAssertEqual(s.ballast?.direction, "stbd tank → port tank")
    }
}
