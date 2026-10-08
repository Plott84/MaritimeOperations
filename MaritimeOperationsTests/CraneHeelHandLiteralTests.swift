import Foundation
import XCTest
@testable import MaritimeOperations

/// QA follow-ups 2026-10-07. Every expected value here is a LITERAL worked out by hand (or, for the exact-angle fixture,
/// in 40-digit real arithmetic by crosscheck/make_exact_angle_fixture.py) — never recomputed with the app's own formula.
///
/// Ship for the hand cases: PL 80 t, Δ 8000 t, GM 1.5 m, tanks 12 m apart → Δ·GM = 12 000 t·m, so
/// tan φ = 80·Δy / 12 000 = Δy / 150 and ballast w = 80·|Δy| / 12 = 6.667·|Δy| t.
@MainActor
final class CraneHeelHandLiteralTests: XCTestCase {
    typealias M = CraneHeelMath
    typealias P = CraneHeelPresentation

    private func move(end: (Double, Double), start: (Double, Double)?, pivot: Double = 0,
                      file: StaticString = #filePath, line: UInt = #line) -> M.MoveResult? {
        guard case .ok(let r) = M.move(endAzimuthDeg: end.0, endOutreach: end.1, hookLoad: 80, displacement: 8000, gm: 1.5,
                                       startAzimuthDeg: start?.0, startOutreach: start?.1, pivotOffset: pivot,
                                       ballastLever: 12) else {
            XCTFail("rejected", file: file, line: line); return nil
        }
        return r
    }

    private func screen(end: (String, String), start: (String, String)) -> P {
        P(inputs: P.Inputs(azimuth: end.0, outreach: end.1, hookLoad: "80", displacement: "8000", gm: "1.5",
                           tankDistance: "12", startAzimuth: start.0, startOutreach: start.1))
    }

    // MARK: 1. Rounding rounds the binary Double (QA pin)

    func testRoundingRoundsTheBinaryDouble() {
        // 26.049999999999997 × 10 rounds to exactly 260.5 → half away → 261 → 26.1 (decimal rounding would say 26.0).
        XCTAssertEqual(26.049999999999997 * 10.0, 260.5, "step 1 product is exactly 260.5")
        XCTAssertEqual(M.roundHeel(26.049999999999997), 26.1)
        XCTAssertEqual(M.roundHeel(-26.049999999999997), -26.1)
        // Next Double down: 260.49999999999994 → 26.0.
        XCTAssertEqual(M.roundHeel(26.049999999999994), 26.0)
        XCTAssertEqual((26.049999999999997).nextDown, 26.049999999999994)
        // %.1f rounds the exact binary value instead — that is why the app doesn't use it.
        XCTAssertEqual(String(format: "%.1f", 26.049999999999997), "26.0")
        // 0.15 is 0.1499999999999999944… but 0.15 × 10 == 1.5 exactly → 0.2.
        XCTAssertEqual(M.roundHeel(0.15), 0.2)
    }

    func testRoundingPinReachesTheScreen() throws {
        // Ballast tonnes use the same helper. Start stbd 90°/5.2 m → End stbd 90°/9.1075 m: hand Δy = 3.9075 m,
        // w = 80 × 3.9075 / 12 = 26.05 t. In binary Δy = 3.9074999999999998 and w = 26.049999999999997 → tile "26.1".
        let s = screen(end: ("90", "9.1075"), start: ("90", "5.2"))
        let lift = try XCTUnwrap(s.lift)
        XCTAssertEqual(lift.deltaY, 3.9074999999999998)
        XCTAssertEqual(lift.ballastTonnes, 26.049999999999997)
        XCTAssertEqual(s.ballast?.value, "26.1")
        // Heel: atan(3.9075/150) = atan(0.02605) = 1.4923° → +1.5, no warning.
        XCTAssertEqual(s.heelValueText, "+1.5"); XCTAssertEqual(s.tone, .clear)
    }

    // MARK: 3. Stbd 20 m → CL, hand-worked

    /// Start stbd 90°/20 m: y = +20. End on CL: y = 0. Δy = −20, MH = 80 × −20 = −1600 t·m,
    /// tan φ = −1600/12 000 = −0.13333 → φ = −7.5946° → −7.6 soft, port. w = 1600/12 = 133.33 t → 133.3 t into stbd tank.
    func testStbd20ToCLAsEnd0Deg20m() throws {
        let r = try XCTUnwrap(move(end: (0, 20), start: (90, 20)))
        XCTAssertEqual(r.deltaY, -20); XCTAssertEqual(r.heelingMoment, -1600)
        XCTAssertEqual(r.heelDeg, -7.6); XCTAssertEqual(r.side, .port); XCTAssertEqual(r.warning, .soft)
        XCTAssertEqual(try XCTUnwrap(r.ballastTonnes), 133.333333333, accuracy: 1e-6)
        XCTAssertEqual(r.pumpTo, .stbd)

        let s = screen(end: ("0", "20"), start: ("90", "20"))
        XCTAssertEqual(s.heelValueText, "-7.6"); XCTAssertEqual(s.tone, .soft)
        XCTAssertEqual(s.resultPillText, "Soft heel to port · 5° or more")
        XCTAssertEqual(s.ballast?.value, "133.3"); XCTAssertEqual(s.ballast?.direction, "port tank → stbd tank")
        XCTAssertEqual(s.ballast?.pumpTo, .stbd)
        XCTAssertEqual(s.endRowText, "Bow 0° · 20 m"); XCTAssertEqual(s.startRowText, "Stbd 90° · 20 m")
    }

    /// Same lift with End outreach 0 (hook at the pivot): y_end = 0 whatever the angle → same −7.6 soft, 133.3 t.
    func testStbd20ToCLAsEndOutreach0() throws {
        for endAngle in [0.0, 90.0, 37.0, 270.0] {
            let r = try XCTUnwrap(move(end: (endAngle, 0), start: (90, 20)))
            XCTAssertEqual(r.deltaY, -20, "end \(endAngle)"); XCTAssertEqual(r.heelingMoment, -1600)
            XCTAssertEqual(r.heelDeg, -7.6); XCTAssertEqual(r.side, .port); XCTAssertEqual(r.warning, .soft)
            XCTAssertEqual(try XCTUnwrap(r.ballastTonnes), 133.333333333, accuracy: 1e-6)
            XCTAssertEqual(r.pumpTo, .stbd)
        }
        let s = screen(end: ("90", "0"), start: ("90", "20"))
        XCTAssertEqual(s.heelValueText, "-7.6"); XCTAssertEqual(s.tone, .soft)
        XCTAssertEqual(s.ballast?.value, "133.3"); XCTAssertEqual(s.ballast?.direction, "port tank → stbd tank")
    }

    // MARK: 3. Warning thresholds in move mode, hand-worked (tan φ = Δy/150)

    /// Δy 13.1: atan(0.087333) = 0.087333 − 0.087333³/3 = 0.087111 rad = 4.9912° → 5.0 SOFT. w = 87.3 t.
    /// Δy 12.9: atan(0.086)    = 0.086 − 0.000212        = 0.085788 rad = 4.9153° → 4.9 none. w = 86.0 t.
    /// Δy 26.5: atan(0.176667) = 0.174862 rad = 10.0189° → 10.0 HARD. w = 176.7 t.
    /// Δy 26.2: atan(0.174667) = 0.172923 rad =  9.9077° →  9.9 soft. w = 174.7 t.
    func testMoveThresholdsHandWorked() throws {
        let rows: [(start: (Double, Double), end: (Double, Double), heel: Double, warn: M.Warning, tonnes: String, label: String)] = [
            ((180, 12), (90, 13.1), 5.0, .soft, "87.3", "aft 12 → stbd 13.1 (Δy 13.1)"),
            ((90, 6.9), (90, 20), 5.0, .soft, "87.3", "stbd 6.9 → stbd 20 (Δy 13.1)"),
            ((180, 12), (90, 12.9), 4.9, .none, "86.0", "aft 12 → stbd 12.9 (Δy 12.9)"),
            ((180, 12), (90, 26.5), 10.0, .hard, "176.7", "aft 12 → stbd 26.5 (Δy 26.5)"),
            ((270, 13.1), (90, 13.4), 10.0, .hard, "176.7", "port 13.1 → stbd 13.4 (Δy 26.5)"),
            ((180, 12), (90, 26.2), 9.9, .soft, "174.7", "aft 12 → stbd 26.2 (Δy 26.2)"),
            // Mirrors to port.
            ((90, 13.1), (180, 12), -5.0, .soft, "87.3", "stbd 13.1 → aft (Δy −13.1)"),
            ((90, 12.9), (0, 30), -4.9, .none, "86.0", "stbd 12.9 → bow (Δy −12.9)"),
            ((90, 26.5), (0, 5), -10.0, .hard, "176.7", "stbd 26.5 → bow (Δy −26.5)"),
            ((90, 26.2), (180, 3), -9.9, .soft, "174.7", "stbd 26.2 → aft (Δy −26.2)"),
        ]
        for c in rows {
            let r = try XCTUnwrap(move(end: c.end, start: c.start))
            XCTAssertEqual(r.heelDeg, c.heel, c.label)
            XCTAssertEqual(r.warning, c.warn, c.label)
            XCTAssertEqual(r.side, c.heel > 0 ? .stbd : .port, c.label)
            XCTAssertEqual(r.pumpTo, c.heel > 0 ? .port : .stbd, c.label)
            let s = screen(end: (String(c.end.0), String(c.end.1)), start: (String(c.start.0), String(c.start.1)))
            XCTAssertEqual(s.heelValueText, (c.heel > 0 ? "+" : "") + String(format: "%.1f", c.heel), c.label)
            XCTAssertEqual(s.tone, c.warn == .none ? .clear : c.warn == .soft ? .soft : .hard, c.label)
            XCTAssertEqual(s.ballast?.value, c.tonnes, c.label)
            XCTAssertEqual(s.ballast?.direction, c.heel > 0 ? "stbd tank → port tank" : "port tank → stbd tank", c.label)
            XCTAssertEqual(s.note, "Ship level at start", c.label)
        }
        // Exact cardinals: aft 12 contributes exactly 0, so Δy is exactly the End lever.
        XCTAssertEqual(try XCTUnwrap(move(end: (90, 13.1), start: (180, 12))).deltaY, 13.1)
    }

    /// Start aft 180°/12 m (y = 0) → End stbd 90°/26.4 m: Δy = 26.4, tan φ = 26.4/150 = 0.176,
    /// atan(0.176) = 0.176 − 0.001817 + 0.000034 − 0.000001 = 0.174215 rad = 9.9818° → shows 10.0 → HARD.
    /// The raw heel is under 10, so this proves the warning uses the ROUNDED heel. w = 80 × 26.4 / 12 = 176.0 t,
    /// positive = stbd tank → port tank (pump to port). Mirror to port 270°: −10.0 hard, 176.0 t port tank → stbd tank.
    func testRawUnderTenShowsTenAndWarnsHard() throws {
        for (endAngle, heel, pump, direction, signed) in [(90.0, 10.0, M.Board.port, "stbd tank → port tank", 176.0),
                                                          (270.0, -10.0, M.Board.stbd, "port tank → stbd tank", -176.0)] {
            let r = try XCTUnwrap(move(end: (endAngle, 26.4), start: (180, 12)))
            XCTAssertEqual(r.deltaY, heel > 0 ? 26.4 : -26.4); XCTAssertEqual(r.heelingMoment, heel > 0 ? 2112 : -2112)
            XCTAssertEqual(r.heelDeg, heel); XCTAssertEqual(r.warning, .hard)
            XCTAssertEqual(r.side, heel > 0 ? .stbd : .port); XCTAssertEqual(r.pumpTo, pump)
            XCTAssertEqual(r.ballastTonnes, 176.0); XCTAssertEqual(r.signedBallastTonnes, signed)
            // The raw (unrounded) heel really is below 10°: 2112/12000 = 0.176 → 9.9818°.
            XCTAssertEqual(atan(0.176) * 180 / Double.pi, 9.9818, accuracy: 0.0001)

            let s = screen(end: (String(endAngle), "26.4"), start: ("180", "12"))
            XCTAssertEqual(s.heelValueText, heel > 0 ? "+10.0" : "-10.0"); XCTAssertEqual(s.tone, .hard)
            XCTAssertEqual(s.resultPillText, heel > 0 ? "Hard heel to stbd · 10° or more" : "Hard heel to port · 10° or more")
            XCTAssertEqual(s.ballast?.value, "176.0"); XCTAssertEqual(s.ballast?.direction, direction)
            XCTAssertEqual(s.ballast?.pumpTo, pump)
        }
    }

    /// Ballast rounds its binary value with the heel's rule (accepted by Pixel + QA 2026-10-07; = Builder's round1).
    /// 25 t at stbd 90°/2.3 m, d 10: by hand w = 25 × 2.3 / 10 = 5.75 t, but 2.3 is 2.29999999999999982 in binary,
    /// so w = 5.749999999999999 → tile "5.7" (not 5.8). Heel atan(57.5/12000) = 0.2745° → +0.3, unaffected.
    func testTypedBallastOnPointX5CanRoundDown() throws {
        guard case .ok(let r) = M.heel(azimuthDeg: 90, outreach: 2.3, hookLoad: 25, displacement: 8000, gm: 1.5,
                                       ballastLever: 10) else { return XCTFail("rejected") }
        XCTAssertEqual(r.ballastTonnes, 5.749999999999999); XCTAssertEqual(r.heelDeg, 0.3); XCTAssertEqual(r.warning, .none)
        let s = P(inputs: P.Inputs(azimuth: "90", outreach: "2.3", hookLoad: "25", displacement: "8000", gm: "1.5",
                                   tankDistance: "10"))
        XCTAssertEqual(s.ballast?.value, "5.7")
        XCTAssertEqual(s.heelValueText, "+0.3"); XCTAssertEqual(s.tone, .clear)
    }

    // MARK: 2. Exact-angle fixture (expected = real arithmetic on the exact geometry, not the app's code path)

    private struct ExactFixture: Decodable {
        struct Expected: Decodable { let phi, warn, side: String; let tile, pump: String? }
        struct RefShows: Decodable { let phi, warn, side: String; let tile: String? }
        struct Case: Decodable {
            let name, why: String
            let input: [String: String]
            let expected: Expected
            let reference_shows: RefShows
            let true_raw_heel_deg: String
        }
        let cases: [Case]
    }

    func testExactAngleFixtureChangesTheDisplayedAnswer() throws {
        let url = try XCTUnwrap(Bundle(for: CraneHeelHandLiteralTests.self).url(forResource: "crane_heel_exact_angle_fixture", withExtension: "json"))
        let fx = try JSONDecoder().decode(ExactFixture.self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(fx.cases.count, 10)
        XCTAssertTrue(fx.cases.contains { $0.name.hasPrefix("QA MOVE.md #1") })
        XCTAssertTrue(fx.cases.contains { $0.expected.warn != $0.reference_shows.warn }, "at least one warning-level flip")
        for c in fx.cases {
            let i = c.input
            func d(_ k: String) -> Double? { i[k].map { Double($0)! } }
            // Each row really is one where the exact angle changes what the screen shows.
            XCTAssertTrue(c.expected.phi != c.reference_shows.phi || c.expected.tile != c.reference_shows.tile, c.name)
            guard case .ok(let r) = M.move(endAzimuthDeg: d("end_theta")!, endOutreach: d("end_R")!, hookLoad: d("PL")!,
                                           displacement: d("disp")!, gm: d("GM")!, startAzimuthDeg: d("start_theta"),
                                           startOutreach: d("start_R"), pivotOffset: d("y_pivot") ?? 0,
                                           ballastLever: d("lever")) else { XCTFail("rejected: \(c.name)"); continue }
            XCTAssertEqual(r.heelDeg, Double(c.expected.phi)!, "\(c.name) (true raw \(c.true_raw_heel_deg))")
            XCTAssertEqual(r.warning.rawValue, c.expected.warn, c.name)
            XCTAssertEqual(r.side.rawValue, c.expected.side, c.name)
            XCTAssertEqual(r.pumpTo?.rawValue, c.expected.pump, c.name)
            // Same answer on the screen (text inputs are the exact Double reprs).
            let s = P(inputs: P.Inputs(azimuth: i["end_theta"]!, outreach: i["end_R"]!, hookLoad: i["PL"]!,
                                       displacement: i["disp"]!, gm: i["GM"]!, pivotOffset: i["y_pivot"] ?? "",
                                       tankDistance: i["lever"] ?? "", startAzimuth: i["start_theta"] ?? "",
                                       startOutreach: i["start_R"] ?? ""))
            let phi = Double(c.expected.phi)!
            XCTAssertEqual(s.heelValueText, (phi > 0 ? "+" : "") + c.expected.phi, c.name)
            XCTAssertEqual(s.ballast?.value, c.expected.tile, c.name)
        }
    }
}
