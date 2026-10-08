import Foundation
import XCTest
@testable import MaritimeOperations

/// XCTest port of /workspace/crane-heel-reference/crane_heel_reference.py
/// (27 CASES, 12 ERRORS, 9 ROUND_PINS — same 98 checks as the Python self-test), plus locked-rule pins.
@MainActor
final class CraneHeelMathTests: XCTestCase {

    // MARK: - Helpers

    private struct Input {
        var theta: Double, R: Double, PL: Double, disp: Double, GM: Double
        var yPivot = 0.0
        var lever: Double? = nil
    }

    private enum Exp {
        case num(Double)      // abs diff <= 0.01, like the reference
        case str(String)      // side / warn / pump_to raw value
        case none             // Python None
    }

    private static func run(_ i: Input) -> CraneHeelMath.Outcome {
        CraneHeelMath.heel(azimuthDeg: i.theta, outreach: i.R, hookLoad: i.PL, displacement: i.disp,
                           gm: i.GM, pivotOffset: i.yPivot, ballastLever: i.lever)
    }

    private static func ok(_ i: Input, file: StaticString = #filePath, line: UInt = #line) -> CraneHeelMath.Result? {
        guard case .ok(let r) = run(i) else { XCTFail("expected .ok for \(i)", file: file, line: line); return nil }
        return r
    }

    private static func gmFor(_ deg: Double) -> Double { 0.1 / tan(deg * (Double.pi / 180.0)) }

    private static func isNegZero(_ d: Double) -> Bool { d == 0 && d.sign == .minus }

    // MARK: - Reference CASES (27)

    private static let cases: [(String, Input, [String: Exp])] = [
        ("A beam stbd", Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(20), "MH": .num(1600), "phi": .num(7.6), "warn": .str("soft"), "side": .str("stbd")]),
        ("B bow-quarter 45", Input(theta: 45, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(14.142), "MH": .num(1131.37), "phi": .num(5.4), "warn": .str("soft")]),
        ("C ballast lever 12", Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: 12), ["ballast_t": .num(133.33), "pump_to": .str("port")]),
        ("C2 GM 1.2", Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.2), ["phi": .num(9.5), "warn": .str("soft")]),
        ("D bow 0", Input(theta: 0, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(0), "phi": .num(0), "side": .str("upright"), "warn": .str("none"), "x": .num(20)]),
        ("E aft 180", Input(theta: 180, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(0), "phi": .num(0), "x": .num(-20)]),
        ("F port 270", Input(theta: 270, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(-20), "MH": .num(-1600), "phi": .num(-7.6), "side": .str("port")]),
        ("G 360 == 0", Input(theta: 360, R: 20, PL: 80, disp: 8000, GM: 1.5), ["phi": .num(0)]),
        ("H port ballast", Input(theta: 270, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: 12), ["ballast_t": .num(133.33), "pump_to": .str("stbd")]),
        ("I small lift", Input(theta: 90, R: 10, PL: 20, disp: 8000, GM: 1.5), ["MH": .num(200), "phi": .num(1.0), "warn": .str("none")]),
        ("J hard warn", Input(theta: 90, R: 36, PL: 100, disp: 8000, GM: 1.5), ["MH": .num(3600), "phi": .num(16.7), "warn": .str("hard")]),
        ("K1 4.94 shows 4.9, no warn", Input(theta: 90, R: 10, PL: 10, disp: 1000, GM: gmFor(4.94)), ["phi": .num(4.9), "warn": .str("none")]),
        ("K2 4.96 shows 5.0, soft", Input(theta: 90, R: 10, PL: 10, disp: 1000, GM: gmFor(4.96)), ["phi": .num(5.0), "warn": .str("soft")]),
        ("K3 9.94 shows 9.9, soft", Input(theta: 90, R: 10, PL: 10, disp: 1000, GM: gmFor(9.94)), ["phi": .num(9.9), "warn": .str("soft")]),
        ("K4 9.96 shows 10.0, hard", Input(theta: 90, R: 10, PL: 10, disp: 1000, GM: gmFor(9.96)), ["phi": .num(10.0), "warn": .str("hard")]),
        ("R wrap -90 == 270", Input(theta: -90, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(-20), "phi": .num(-7.6), "side": .str("port")]),
        ("S wrap 361 == 1", Input(theta: 361, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(0.349), "phi": .num(0.1)]),
        ("T zero load to port, no -0.0", Input(theta: 270, R: 20, PL: 0, disp: 8000, GM: 1.5), ["phi": .num(0.0), "side": .str("upright"), "warn": .str("none")]),
        ("U huge moment caps <= 90", Input(theta: 90, R: 36, PL: 250, disp: 10, GM: 0.01), ["phi": .num(90.0), "warn": .str("hard")]),
        ("L pivot offset stbd at 0", Input(theta: 0, R: 20, PL: 80, disp: 8000, GM: 1.5, yPivot: 5), ["y": .num(5), "MH": .num(400), "phi": .num(1.9)]),
        ("M pivot offset, boom to port", Input(theta: 270, R: 20, PL: 80, disp: 8000, GM: 1.5, yPivot: 5), ["y": .num(-15), "MH": .num(-1200), "phi": .num(-5.7)]),
        ("N 30 deg", Input(theta: 30, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(10), "MH": .num(800), "phi": .num(3.8)]),
        ("O 150 deg", Input(theta: 150, R: 20, PL: 80, disp: 8000, GM: 1.5), ["y": .num(10), "phi": .num(3.8), "x": .num(-17.321)]),
        ("P 250t at 36m (assumed disp/GM)", Input(theta: 90, R: 36, PL: 250, disp: 12000, GM: 2.0), ["MH": .num(9000), "phi": .num(20.6), "warn": .str("hard")]),
        ("Q zero load", Input(theta: 90, R: 20, PL: 0, disp: 8000, GM: 1.5, lever: 12), ["phi": .num(0), "ballast_t": .none, "pump_to": .none]),
        ("V -0.04 shows 0.0, no ballast line", Input(theta: 270, R: 1, PL: 0.0838, disp: 8000, GM: 0.4, lever: 12), ["phi": .num(0.0), "side": .str("upright"), "ballast_t": .none, "pump_to": .none]),
        ("W boom on CL with lever, no ballast line", Input(theta: 180, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: 12), ["phi": .num(0.0), "ballast_t": .none, "pump_to": .none]),
    ]

    func testReferenceCases() {
        XCTAssertEqual(Self.cases.count, 27)
        var checks = 0
        for (name, input, exp) in Self.cases {
            guard let r = Self.ok(input) else { continue }
            for (key, want) in exp {
                checks += 1
                let got: Any?
                switch key {
                case "y": got = r.y
                case "x": got = r.x
                case "MH": got = r.heelingMoment
                case "phi": got = r.heelDeg
                case "side": got = r.side.rawValue
                case "warn": got = r.warning.rawValue
                case "ballast_t": got = r.ballastTonnes
                case "pump_to": got = r.pumpTo?.rawValue
                default: XCTFail("unknown key \(key)"); continue
                }
                switch want {
                case .num(let v):
                    guard let g = got as? Double else { XCTFail("\(name) \(key): got nil, want \(v)"); continue }
                    XCTAssertLessThanOrEqual(abs(g - v), 0.01, "\(name) \(key): \(g) != \(v)")
                case .str(let s):
                    XCTAssertEqual(got as? String, s, "\(name) \(key)")
                case .none:
                    XCTAssertNil(got, "\(name) \(key) should be nil")
                }
            }
            // Displayed heel is always an exact 1-decimal value and never -0.0.
            XCTAssertFalse(Self.isNegZero(r.heelDeg), "\(name) phi is -0.0")
            XCTAssertFalse(Self.isNegZero(r.heelingMoment), "\(name) MH is -0.0")
        }
        XCTAssertEqual(checks, 77, "same field-check count as the Python self-test (98 − 12 − 9)")
    }

    /// Exact displayed heels (Python prints these with phi=%8.3f).
    func testReferenceCasesExactHeel() {
        let want: [String: Double] = [
            "A beam stbd": 7.6, "B bow-quarter 45": 5.4, "C ballast lever 12": 7.6, "C2 GM 1.2": 9.5, "D bow 0": 0,
            "E aft 180": 0, "F port 270": -7.6, "G 360 == 0": 0, "H port ballast": -7.6, "I small lift": 1.0,
            "J hard warn": 16.7, "K1 4.94 shows 4.9, no warn": 4.9, "K2 4.96 shows 5.0, soft": 5.0,
            "K3 9.94 shows 9.9, soft": 9.9, "K4 9.96 shows 10.0, hard": 10.0, "R wrap -90 == 270": -7.6,
            "S wrap 361 == 1": 0.1, "T zero load to port, no -0.0": 0, "U huge moment caps <= 90": 90,
            "L pivot offset stbd at 0": 1.9, "M pivot offset, boom to port": -5.7, "N 30 deg": 3.8, "O 150 deg": 3.8,
            "P 250t at 36m (assumed disp/GM)": 20.6, "Q zero load": 0, "V -0.04 shows 0.0, no ballast line": 0,
            "W boom on CL with lever, no ballast line": 0,
        ]
        XCTAssertEqual(want.count, 27)
        for (name, input, _) in Self.cases {
            guard let r = Self.ok(input), let w = want[name] else { XCTFail(name); continue }
            XCTAssertEqual(r.heelDeg, w, name)
            XCTAssertEqual(r.heelDeg.sign, w.sign, "\(name) sign")
        }
    }

    // MARK: - Reference ERRORS (12)

    func testReferenceBadInputs() {
        let nan = Double.nan, inf = Double.infinity
        let bad: [(Input, String)] = [
            (Input(theta: nan, R: 20, PL: 80, disp: 8000, GM: 1.5), CraneHeelMath.Reason.azimuth),
            (Input(theta: 90, R: 20, PL: nan, disp: 8000, GM: 1.5), CraneHeelMath.Reason.hookLoad),
            (Input(theta: 90, R: inf, PL: 80, disp: 8000, GM: 1.5), CraneHeelMath.Reason.outreach),
            (Input(theta: 90, R: 20, PL: 80, disp: nan, GM: 1.5), CraneHeelMath.Reason.displacement),
            (Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: inf), CraneHeelMath.Reason.gm),
            (Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: inf), CraneHeelMath.Reason.ballastLever),
            (Input(theta: 90, R: 20, PL: 80, disp: 0, GM: 1.5), CraneHeelMath.Reason.displacement),
            (Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 0), CraneHeelMath.Reason.gm),
            (Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: -0.5), CraneHeelMath.Reason.gm),
            (Input(theta: 90, R: -1, PL: 80, disp: 8000, GM: 1.5), CraneHeelMath.Reason.outreach),
            (Input(theta: 90, R: 20, PL: -1, disp: 8000, GM: 1.5), CraneHeelMath.Reason.hookLoad),
            (Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: 0), CraneHeelMath.Reason.ballastLever),
        ]
        XCTAssertEqual(bad.count, 12)
        for (i, (input, reason)) in bad.enumerated() {
            XCTAssertEqual(Self.run(input), .invalid(reason: reason), "bad input #\(i + 1): \(input)")
        }
    }

    // MARK: - Reference ROUND_PINS (9)

    func testRoundingPins() {
        let pins: [(Double, Double)] = [(9.95, 10.0), (4.95, 5.0), (9.94999, 9.9), (4.94999, 4.9), (-4.95, -5.0),
                                        (0.04, 0.0), (-0.04, 0.0), (0.05, 0.1), (89.96, 90.0)]
        XCTAssertEqual(pins.count, 9)
        for (x, want) in pins {
            let got = CraneHeelMath.roundHeel(x)
            XCTAssertEqual(got, want, "roundHeel(\(x))")
            XCTAssertEqual(got.sign, want.sign, "roundHeel(\(x)) sign (no -0.0)")
        }
    }

    // MARK: - Locked rules (extra pins beyond the reference self-test)

    /// Raw heel of exactly the double 9.95 must show 10.0 / hard (QA RECHECK risk #3), 4.95 → 5.0 / soft.
    func testRawBoundaryHeelsDriveWarningsOnRoundedValue() {
        // QA RECHECK: GM = 0.5700366328693822, MH 100, Δ 1000 → Python atan path gives 9.950000000000001 → 10.0 hard.
        let r1 = Self.ok(Input(theta: 90, R: 10, PL: 10, disp: 1000, GM: 0.5700366328693822))
        XCTAssertEqual(r1?.heelDeg, 10.0); XCTAssertEqual(r1?.warning, .hard)
        // Port mirror.
        let r2 = Self.ok(Input(theta: 270, R: 10, PL: 10, disp: 1000, GM: 0.5700366328693822))
        XCTAssertEqual(r2?.heelDeg, -10.0); XCTAssertEqual(r2?.warning, .hard); XCTAssertEqual(r2?.side, .port)
        // 4.94 shows 4.9 none, 4.951 shows 5.0 soft.
        XCTAssertEqual(Self.ok(Input(theta: 90, R: 10, PL: 10, disp: 1000, GM: Self.gmFor(4.94)))?.warning, CraneHeelMath.Warning.none)
        let r3 = Self.ok(Input(theta: 90, R: 10, PL: 10, disp: 1000, GM: Self.gmFor(4.951)))
        XCTAssertEqual(r3?.heelDeg, 5.0); XCTAssertEqual(r3?.warning, .soft)
        XCTAssertEqual(CraneHeelMath.roundHeel(9.95), 10.0)
        XCTAssertEqual(CraneHeelMath.roundHeel(-9.95), -10.0)
        XCTAssertEqual(CraneHeelMath.roundHeel(89.94), 89.9)
    }

    func testAzimuthWrap() {
        let pairs: [(Double, Double)] = [(-90, 270), (361, 1), (450, 90), (-270, 90), (-725, 355), (36_000_090, 90),
                                         (360, 0), (720, 0), (-360, 0), (-180, 180), (0, 0), (-0.0, 0)]
        for (a, b) in pairs {
            let w = CraneHeelMath.wrapAzimuth(a)
            XCTAssertEqual(w, b, "wrap(\(a))")
            XCTAssertFalse(Self.isNegZero(w), "wrap(\(a)) is -0.0")
            let ra = Self.ok(Input(theta: a, R: 20, PL: 80, disp: 8000, GM: 1.5))
            let rb = Self.ok(Input(theta: b, R: 20, PL: 80, disp: 8000, GM: 1.5))
            XCTAssertEqual(ra?.heelDeg, rb?.heelDeg, "heel(\(a)) == heel(\(b))")
        }
        // Python semantics for a tiny negative: -1e-20 % 360 == 360.0
        XCTAssertEqual(CraneHeelMath.wrapAzimuth(-1e-20), 360.0)
    }

    func testCentrelineAndUprightHideBallastAndNeverNegativeZero() {
        for th in [0.0, 180, 360, 540, 720, -180, -360, -0.0] {
            guard let r = Self.ok(Input(theta: th, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: 12)) else { continue }
            XCTAssertEqual(r.heelDeg, 0); XCTAssertEqual(r.heelDeg.sign, .plus, "θ=\(th)")
            XCTAssertEqual(r.side, .upright); XCTAssertEqual(r.warning, CraneHeelMath.Warning.none)
            XCTAssertNil(r.ballastTonnes); XCTAssertNil(r.pumpTo)
            XCTAssertFalse(Self.isNegZero(r.y)); XCTAssertFalse(Self.isNegZero(r.heelingMoment))
        }
        // Raw −0.04° shows +0.0, upright, ballast hidden even though MH ≠ 0.
        let v = Self.ok(Input(theta: 270, R: 1, PL: 0.0838, disp: 8000, GM: 0.4, lever: 12))
        XCTAssertEqual(v?.heelDeg.sign, .plus); XCTAssertLessThan(v?.heelingMoment ?? 0, 0)
        XCTAssertNil(v?.ballastTonnes); XCTAssertNil(v?.pumpTo)
        // Pivot −0.0 at θ 0.
        let p = Self.ok(Input(theta: 0, R: 20, PL: 80, disp: 8000, GM: 1.5, yPivot: -0.0))
        XCTAssertEqual(p?.y.sign, .plus); XCTAssertEqual(p?.heelDeg.sign, .plus)
    }

    func testBallastDirectionAndDisplacementIncludesLift() {
        let c = Self.ok(Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: 12))
        XCTAssertEqual(c?.ballastTonnes ?? 0, 1600.0 / 12.0, accuracy: 1e-12); XCTAssertEqual(c?.pumpTo, .port)
        let w = Self.ok(Input(theta: -90, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: 12))
        XCTAssertEqual(w?.pumpTo, .stbd)
        // Δ includes the lift: 7.6 (not 7.5 from Δ+PL), and PL 500 / Δ 1000 → 26.6.
        XCTAssertEqual(c?.heelDeg, 7.6)
        XCTAssertEqual(Self.ok(Input(theta: 90, R: 1, PL: 500, disp: 1000, GM: 1))?.heelDeg, 26.6)
        // Display cap, both sides.
        XCTAssertEqual(Self.ok(Input(theta: 270, R: 36, PL: 250, disp: 10, GM: 0.01))?.heelDeg, -90.0)
    }

    func testExtraBadInputs() {
        let inf = Double.infinity
        XCTAssertEqual(Self.run(Input(theta: -inf, R: 20, PL: 80, disp: 8000, GM: 1.5)), .invalid(reason: CraneHeelMath.Reason.azimuth))
        XCTAssertEqual(Self.run(Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.5, yPivot: .nan)), .invalid(reason: CraneHeelMath.Reason.pivotOffset))
        XCTAssertEqual(Self.run(Input(theta: 90, R: 20, PL: 80, disp: -0.0, GM: 1.5)), .invalid(reason: CraneHeelMath.Reason.displacement))
        XCTAssertEqual(Self.run(Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: -0.0)), .invalid(reason: CraneHeelMath.Reason.ballastLever))
        XCTAssertEqual(Self.run(Input(theta: 90, R: 20, PL: 80, disp: 8000, GM: 1.5, lever: -3)), .invalid(reason: CraneHeelMath.Reason.ballastLever))
        // Finite gate wins over range gate (reference checks finiteness of every field first).
        XCTAssertEqual(Self.run(Input(theta: 90, R: -1, PL: 80, disp: 8000, GM: .nan)), .invalid(reason: CraneHeelMath.Reason.gm))
        // Python ZeroDivisionError (Δ·GM underflow) and NaN-floor ValueError (inf·0) → invalid, never a crash or NaN.
        XCTAssertEqual(Self.run(Input(theta: 90, R: 20, PL: 80, disp: 1e-200, GM: 1e-200)), .invalid(reason: CraneHeelMath.Reason.outOfRange))
        XCTAssertEqual(Self.run(Input(theta: 90, R: 1.7e308, PL: 0, disp: 8000, GM: 1.5, yPivot: 1.7e308)), .invalid(reason: CraneHeelMath.Reason.outOfRange))
        XCTAssertEqual(Self.run(Input(theta: 90, R: 1.7e308, PL: 1e10, disp: 1e300, GM: 1e300, yPivot: 1.7e308)), .invalid(reason: CraneHeelMath.Reason.outOfRange))
        // R = 0 and PL = 0 are valid (upright).
        XCTAssertEqual(Self.ok(Input(theta: 90, R: 0, PL: 80, disp: 8000, GM: 1.5))?.side, .upright)
    }

    // MARK: - Python-generated fixture (crosscheck/cross_check.py)

    private struct Fixture: Decodable {
        struct Out: Decodable { let azimuth, y, x, MH, phi, side, warn, ballast, pump: String }
        struct Case: Decodable { let `in`: [String]; let lever: String?; let out: Out? }
        let reference_sha256: String
        let cases: [Case]
    }

    private static func dbl(_ hex: String) -> Double { Double(bitPattern: UInt64(hex, radix: 16)!) }

    /// Displayed heel / side / warning / ballast visibility / pump side must match exactly;
    /// raw floats to 1e-12 relative (bit-exact on Linux; Darwin libm may differ by an ulp).
    func testPythonFixture() throws {
        let url = try XCTUnwrap(Bundle(for: CraneHeelMathTests.self).url(forResource: "crane_heel_fixture", withExtension: "json"))
        let fx = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(fx.cases.count, 500)
        func close(_ a: Double, _ b: Double) -> Bool { a == b || abs(a - b) <= 1e-12 * max(abs(a), abs(b)) }
        for (i, c) in fx.cases.enumerated() {
            let v = c.in.map(Self.dbl)
            let got = Self.run(Input(theta: v[0], R: v[1], PL: v[2], disp: v[3], GM: v[4], yPivot: v[5], lever: c.lever.map(Self.dbl)))
            guard let o = c.out else {
                if case .ok = got { XCTFail("fixture #\(i): reference rejects, Swift accepted") }
                continue
            }
            guard case .ok(let r) = got else { XCTFail("fixture #\(i): reference accepts, Swift rejected"); continue }
            XCTAssertEqual(r.heelDeg.bitPattern, Self.dbl(o.phi).bitPattern, "fixture #\(i) phi")
            XCTAssertEqual(r.side.rawValue, o.side, "fixture #\(i) side")
            XCTAssertEqual(r.warning.rawValue, o.warn, "fixture #\(i) warn")
            XCTAssertEqual(r.pumpTo?.rawValue ?? "-", o.pump, "fixture #\(i) pump")
            XCTAssertEqual(r.ballastTonnes == nil, o.ballast == "-", "fixture #\(i) ballast visibility")
            XCTAssertEqual(r.azimuthDeg, Self.dbl(o.azimuth), "fixture #\(i) azimuth")
            XCTAssertTrue(close(r.y, Self.dbl(o.y)), "fixture #\(i) y")
            XCTAssertTrue(close(r.x, Self.dbl(o.x)), "fixture #\(i) x")
            XCTAssertTrue(close(r.heelingMoment, Self.dbl(o.MH)), "fixture #\(i) MH")
            if let b = r.ballastTonnes, o.ballast != "-" { XCTAssertTrue(close(b, Self.dbl(o.ballast)), "fixture #\(i) ballast") }
        }
    }
}
