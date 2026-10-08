import Foundation
import XCTest
@testable import MaritimeOperations

/// B2 two-point lift: XCTest port of `crane_heel_move()` in /workspace/crane-heel-reference/crane_heel_reference.py
/// (12 MOVE_CASES = 55 field checks + 4 MOVE_ERRORS), the named cases from the brief, the deliberate exact-cardinal
/// difference (QA MOVE.md #1/#7), and the reference-generated move fixture (crosscheck/cross_check_move.py).
/// Fixture rows where the reference and the exact-cardinal variant differ are excluded by the generator.
@MainActor
final class CraneHeelMoveMathTests: XCTestCase {
    typealias M = CraneHeelMath

    private struct In {
        var endTheta: Double, endR: Double
        var startTheta: Double? = nil, startR: Double? = nil
        var PL = 80.0, disp = 8000.0, GM = 1.5
        var yPivot = 0.0
        var lever: Double? = 12
    }

    private static func run(_ i: In) -> M.MoveOutcome {
        M.move(endAzimuthDeg: i.endTheta, endOutreach: i.endR, hookLoad: i.PL, displacement: i.disp, gm: i.GM,
               startAzimuthDeg: i.startTheta, startOutreach: i.startR, pivotOffset: i.yPivot, ballastLever: i.lever)
    }

    private static func ok(_ i: In, file: StaticString = #filePath, line: UInt = #line) -> M.MoveResult? {
        guard case .ok(let r) = run(i) else { XCTFail("expected .ok for \(i)", file: file, line: line); return nil }
        return r
    }

    private static func isNegZero(_ d: Double) -> Bool { d == 0 && d.sign == .minus }

    private enum Exp { case num(Double), str(String), none }

    // MARK: - Reference MOVE_CASES (12 cases, 55 checks)

    private static let cases: [(String, In, [String: Exp])] = [
        ("M1 B2 example aft12 -> stbd20", In(endTheta: 90, endR: 20, startTheta: 180, startR: 12),
         ["dy": .num(20), "phi": .num(7.6), "side": .str("stbd"), "warn": .str("soft"), "ballast_t": .num(133.33), "pump_to": .str("port")]),
        ("M2 stbd20 -> CL (worst start)", In(endTheta: 180, endR: 20, startTheta: 90, startR: 20),
         ["dy": .num(-20), "phi": .num(-7.6), "side": .str("port"), "warn": .str("soft"), "ballast_t": .num(133.33), "pump_to": .str("stbd")]),
        ("M3 stbd20 -> port20", In(endTheta: 270, endR: 20, startTheta: 90, startR: 20),
         ["dy": .num(-40), "MH": .num(-3200), "phi": .num(-14.9), "warn": .str("hard"), "ballast_t": .num(266.67), "pump_to": .str("stbd")]),
        ("M4 port20 -> stbd20", In(endTheta: 90, endR: 20, startTheta: 270, startR: 20),
         ["dy": .num(40), "phi": .num(14.9), "warn": .str("hard"), "ballast_t": .num(266.67), "pump_to": .str("port")]),
        ("M5 no move, tile hidden", In(endTheta: 90, endR: 20, startTheta: 90, startR: 20),
         ["dy": .num(0), "phi": .num(0.0), "side": .str("upright"), "warn": .str("none"), "ballast_t": .none, "pump_to": .none]),
        ("M6 30 -> 150 same y, no -0.0", In(endTheta: 150, endR: 20, startTheta: 30, startR: 20),
         ["dy": .num(0), "MH": .num(0), "phi": .num(0.0), "side": .str("upright"), "ballast_t": .none]),
        ("M7 pivot cancels (= M1)", In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, yPivot: 5),
         ["dy": .num(20), "phi": .num(7.6), "ballast_t": .num(133.33), "pump_to": .str("port")]),
        ("M8 start blank -> single point C", In(endTheta: 90, endR: 20),
         ["phi": .num(7.6), "ballast_t": .num(133.33), "pump_to": .str("port"), "mode": .str("single")]),
        ("M9 start blank + pivot 5 (L)", In(endTheta: 0, endR: 20, yPivot: 5, lever: nil),
         ["phi": .num(1.9), "mode": .str("single")]),
        ("M10 end wrap -270 == 90", In(endTheta: -270, endR: 20, startTheta: 180, startR: 12),
         ["phi": .num(7.6), "ballast_t": .num(133.33)]),
        ("M11 stbd10 -> stbd20 (partial)", In(endTheta: 90, endR: 20, startTheta: 90, startR: 10),
         ["dy": .num(10), "MH": .num(800), "phi": .num(3.8), "warn": .str("none"), "ballast_t": .num(66.67), "pump_to": .str("port")]),
        ("M12 no lever, no ballast", In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, lever: nil),
         ["phi": .num(7.6), "ballast_t": .none, "pump_to": .none]),
    ]

    func testReferenceMoveCases() {
        XCTAssertEqual(Self.cases.count, 12)
        var checks = 0
        for (name, input, exp) in Self.cases {
            guard let r = Self.ok(input) else { continue }
            for (key, want) in exp {
                checks += 1
                let got: Any?
                switch key {
                case "dy": got = r.deltaY
                case "MH": got = r.heelingMoment
                case "phi": got = r.heelDeg
                case "side": got = r.side.rawValue
                case "warn": got = r.warning.rawValue
                case "ballast_t": got = r.ballastTonnes
                case "pump_to": got = r.pumpTo?.rawValue
                case "mode": got = r.mode.rawValue
                default: XCTFail("unknown key \(key)"); continue
                }
                switch want {
                case .num(let v):
                    guard let g = got as? Double else { XCTFail("\(name) \(key): got nil, want \(v)"); continue }
                    XCTAssertLessThanOrEqual(abs(g - v), 0.01, "\(name) \(key): \(g) != \(v)")
                case .str(let s): XCTAssertEqual(got as? String, s, "\(name) \(key)")
                case .none: XCTAssertNil(got, "\(name) \(key) should be nil")
                }
            }
            XCTAssertFalse(Self.isNegZero(r.heelDeg), "\(name) phi is -0.0")
            XCTAssertFalse(Self.isNegZero(r.heelingMoment), "\(name) MH is -0.0")
            XCTAssertFalse(Self.isNegZero(r.deltaY), "\(name) dy is -0.0")
        }
        XCTAssertEqual(checks, 55, "same field-check count as the Python MOVE_CASES")
    }

    // MARK: - Reference MOVE_ERRORS (4) + the rejects from the brief

    func testReferenceMoveErrorsAndRejects() {
        let nan = Double.nan, inf = Double.infinity
        let bad: [(In, String)] = [
            (In(endTheta: 90, endR: 20, startTheta: 90, startR: nil), M.MoveReason.startIncomplete),
            (In(endTheta: 90, endR: 20, startTheta: nan, startR: 20), M.MoveReason.startAzimuth),
            (In(endTheta: 90, endR: 20, startTheta: 90, startR: -1), M.MoveReason.startOutreach),
            (In(endTheta: 90, endR: 20, startTheta: 90, startR: inf), M.MoveReason.startOutreach),
            // extra: other half-filled Start, NaN / infinite / negative End outreach, -inf Start outreach
            (In(endTheta: 90, endR: 20, startTheta: nil, startR: 12), M.MoveReason.startIncomplete),
            (In(endTheta: 90, endR: nan, startTheta: 180, startR: 12), M.Reason.outreach),
            (In(endTheta: 90, endR: inf, startTheta: 180, startR: 12), M.Reason.outreach),
            (In(endTheta: 90, endR: -1, startTheta: 180, startR: 12), M.Reason.outreach),
            (In(endTheta: 90, endR: 20, startTheta: 180, startR: -inf), M.MoveReason.startOutreach),
            (In(endTheta: nan, endR: 20, startTheta: 180, startR: 12), M.Reason.azimuth),
            (In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, PL: nan), M.Reason.hookLoad),
            (In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, yPivot: nan), M.Reason.pivotOffset),
            (In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, GM: 0), M.Reason.gm),
            (In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, lever: 0), M.Reason.ballastLever),
            (In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, disp: 1e-200, GM: 1e-200), M.Reason.outOfRange),
        ]
        for (i, (input, reason)) in bad.enumerated() {
            XCTAssertEqual(Self.run(input), .invalid(reason: reason), "reject #\(i + 1): \(input)")
        }
    }

    // MARK: - Named cases from the brief (80 t, Δ 8000, GM 1.5, d 12)

    func testNamedCases() throws {
        // Aft 12 m → stbd 20 m: +7.6 soft, 133.3 t into the port tank.
        let m1 = try XCTUnwrap(Self.ok(In(endTheta: 90, endR: 20, startTheta: 180, startR: 12)))
        XCTAssertEqual(m1.heelDeg, 7.6); XCTAssertEqual(m1.warning, .soft); XCTAssertEqual(m1.side, .stbd)
        XCTAssertEqual(m1.mode, .move); XCTAssertEqual(m1.deltaY, 20); XCTAssertEqual(m1.heelingMoment, 1600)
        XCTAssertEqual(m1.ballastTonnes ?? 0, 1600.0 / 12.0, accuracy: 1e-12); XCTAssertEqual(m1.pumpTo, .port)
        XCTAssertEqual(m1.signedBallastTonnes ?? 0, 133.333, accuracy: 1e-3)
        XCTAssertEqual(m1.startAzimuthDeg, 180); XCTAssertEqual(m1.endAzimuthDeg, 90); XCTAssertNil(m1.single)
        // Stbd 20 → CL: −7.6 soft, into the stbd tank (signed w < 0 = port tank → stbd tank).
        let m2 = try XCTUnwrap(Self.ok(In(endTheta: 180, endR: 20, startTheta: 90, startR: 20)))
        XCTAssertEqual(m2.heelDeg, -7.6); XCTAssertEqual(m2.warning, .soft); XCTAssertEqual(m2.pumpTo, .stbd)
        XCTAssertEqual(m2.signedBallastTonnes ?? 0, -133.333, accuracy: 1e-3)
        // Stbd 20 → port 20: −14.9 hard, 266.7 into stbd; port → stbd mirrors.
        let m3 = try XCTUnwrap(Self.ok(In(endTheta: 270, endR: 20, startTheta: 90, startR: 20)))
        XCTAssertEqual(m3.heelDeg, -14.9); XCTAssertEqual(m3.warning, .hard); XCTAssertEqual(m3.pumpTo, .stbd)
        XCTAssertEqual(m3.ballastTonnes ?? 0, 3200.0 / 12.0, accuracy: 1e-12)
        let m4 = try XCTUnwrap(Self.ok(In(endTheta: 90, endR: 20, startTheta: 270, startR: 20)))
        XCTAssertEqual(m4.heelDeg, 14.9); XCTAssertEqual(m4.warning, .hard); XCTAssertEqual(m4.pumpTo, .port)
        XCTAssertEqual(m4.ballastTonnes, m3.ballastTonnes)
        // Stbd 10 → stbd 20: +3.8, no warning, 66.7 t.
        let m11 = try XCTUnwrap(Self.ok(In(endTheta: 90, endR: 20, startTheta: 90, startR: 10)))
        XCTAssertEqual(m11.heelDeg, 3.8); XCTAssertEqual(m11.warning, .none)
        XCTAssertEqual(m11.ballastTonnes ?? 0, 800.0 / 12.0, accuracy: 1e-12)
        // No move, or 30° → 150° at the same outreach: 0.0 (never −0.0), tile hidden.
        for (s, e) in [(90.0, 90.0), (30.0, 150.0), (150.0, 30.0), (270.0, 270.0), (0.0, 180.0), (180.0, 360.0), (-90.0, 270.0)] {
            let r = try XCTUnwrap(Self.ok(In(endTheta: e, endR: 20, startTheta: s, startR: 20)))
            XCTAssertEqual(r.heelDeg, 0); XCTAssertEqual(r.heelDeg.sign, .plus, "\(s)→\(e) is -0.0")
            XCTAssertEqual(r.side, .upright); XCTAssertNil(r.ballastTonnes); XCTAssertNil(r.pumpTo)
            XCTAssertFalse(Self.isNegZero(r.heelingMoment)); XCTAssertFalse(Self.isNegZero(r.deltaY))
        }
        // Pivot 5 m on the B2 example: same answer (pivot cancels), bit-identical.
        let p5 = try XCTUnwrap(Self.ok(In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, yPivot: 5)))
        XCTAssertEqual(p5, m1)
        // Start blank, pivot 5 m, boom at the bow → single point, 1.9° (reference case L).
        let l = try XCTUnwrap(Self.ok(In(endTheta: 0, endR: 20, yPivot: 5, lever: nil)))
        XCTAssertEqual(l.mode, .single); XCTAssertEqual(l.heelDeg, 1.9); XCTAssertEqual(l.deltaY, 5)
        // End angle −270 counts as 90.
        let w = try XCTUnwrap(Self.ok(In(endTheta: -270, endR: 20, startTheta: 180, startR: 12)))
        XCTAssertEqual(w.endAzimuthDeg, 90); XCTAssertEqual(w.heelDeg, 7.6); XCTAssertEqual(w.ballastTonnes, m1.ballastTonnes)
    }

    // MARK: - Start blank = exactly the single-point heel()

    func testStartBlankIsBitIdenticalToSinglePoint() {
        var n = 0
        for az in stride(from: -360.0, through: 720.0, by: 15.0) {
            for yp in [0.0, 5.0, -2.5] {
                for lever in [nil, 12.0] as [Double?] {
                    let single = M.heel(azimuthDeg: az, outreach: 20, hookLoad: 80, displacement: 8000, gm: 1.5, pivotOffset: yp, ballastLever: lever)
                    let move = M.move(endAzimuthDeg: az, endOutreach: 20, hookLoad: 80, displacement: 8000, gm: 1.5, pivotOffset: yp, ballastLever: lever)
                    guard case .ok(let s) = single, case .ok(let m) = move else { XCTFail("rejected"); continue }
                    XCTAssertEqual(m.single, s)
                    XCTAssertEqual(m.mode, .single)
                    XCTAssertEqual(m.heelDeg.bitPattern, s.heelDeg.bitPattern)
                    XCTAssertEqual(m.heelingMoment.bitPattern, s.heelingMoment.bitPattern)
                    XCTAssertEqual(m.deltaY.bitPattern, s.y.bitPattern)
                    XCTAssertEqual(m.ballastTonnes, s.ballastTonnes); XCTAssertEqual(m.pumpTo, s.pumpTo)
                    n += 1
                }
            }
        }
        XCTAssertEqual(n, 73 * 3 * 2)
        // Invalid single-point input keeps the single-point reason.
        XCTAssertEqual(M.move(endAzimuthDeg: 90, endOutreach: 20, hookLoad: 80, displacement: 8000, gm: 0), .invalid(reason: M.Reason.gm))
    }

    // MARK: - Deliberate difference: exact sin/cos at 0/90/180/270 in move mode (QA MOVE.md #1/#7)

    func testExactSinCosAtCardinals() {
        XCTAssertEqual(M.exactSinCos(wrappedDeg: 0).sin, 0); XCTAssertEqual(M.exactSinCos(wrappedDeg: 0).cos, 1)
        XCTAssertEqual(M.exactSinCos(wrappedDeg: 90).sin, 1); XCTAssertEqual(M.exactSinCos(wrappedDeg: 90).cos, 0)
        XCTAssertEqual(M.exactSinCos(wrappedDeg: 180).sin, 0); XCTAssertEqual(M.exactSinCos(wrappedDeg: 180).cos, -1)
        XCTAssertEqual(M.exactSinCos(wrappedDeg: 270).sin, -1); XCTAssertEqual(M.exactSinCos(wrappedDeg: 270).cos, 0)
        XCTAssertEqual(M.exactSinCos(wrappedDeg: 180).sin.sign, .plus)
        // Non-cardinal: same libm value as the reference path.
        XCTAssertEqual(M.exactSinCos(wrappedDeg: 30).sin, sin(30.0 * (Double.pi / 180.0)))
        XCTAssertEqual(M.exactSinCos(wrappedDeg: 179.999999).sin, sin(179.999999 * (Double.pi / 180.0)))
        // libm really is inexact at 180 (that's the point of the fix).
        XCTAssertNotEqual(sin(180.0 * (Double.pi / 180.0)), 0)
    }

    /// QA MOVE.md mismatch 1: raw heel exactly 0.05° → shows 0.1 (reference shows 0.0 because 12·sin180 = 1.47e-15).
    func testQAZeroPointZeroFiveTieShowsPointOne() throws {
        for (start, pivot) in [(180.0, 7.3), (180.0, 0.0), (-180.0, 0.0), (540.0, 7.3)] {
            let r = try XCTUnwrap(Self.ok(In(endTheta: 0.3750027725481633, endR: 20, startTheta: start, startR: 12, yPivot: pivot)))
            XCTAssertEqual(r.heelDeg, 0.1, "start \(start) pivot \(pivot)")
            XCTAssertEqual(r.side, .stbd); XCTAssertEqual(r.warning, .none)
            XCTAssertEqual(r.pumpTo, .port); XCTAssertNotNil(r.ballastTonnes)
            XCTAssertEqual(r.deltaY, 20 * sin(0.3750027725481633 * (Double.pi / 180.0)))   // Start contributes exactly 0
        }
        // GM engineered onto the 4.95° tie (literal Double; = 80·20/(8000·tan 4.95°)). Expected is a LITERAL:
        // 40-digit real arithmetic gives raw 4.950000000000000379° → 5.0 soft (float path: exactly 4.95 → 5.0).
        let s = try XCTUnwrap(Self.ok(In(endTheta: 90, endR: 20, startTheta: 180, startR: 12, GM: 2.3092185359298516)))
        XCTAssertEqual(s.deltaY, 20)
        XCTAssertEqual(s.heelDeg, 5.0); XCTAssertEqual(s.warning, .soft); XCTAssertEqual(s.side, .stbd)
    }

    /// Single-point heel() also uses exact sin/cos at the cardinals (applied 2026-10-07 after the 27 locked cases and the
    /// locked fixture passed unchanged). Pivot exactly on a 0.05° tie with the boom aft: the reference adds
    /// 20·sin(180°) = 2.4e-15 m and shows 0.1; the exact geometry is just under 0.05 and shows 0.0.
    func testSinglePointExactCardinalTie() throws {
        guard case .ok(let r) = M.heel(azimuthDeg: 180, outreach: 20, hookLoad: 80, displacement: 8000, gm: 1.5,
                                       pivotOffset: 0.13089972712818826, ballastLever: 12) else { return XCTFail("rejected") }
        XCTAssertEqual(r.y, 0.13089972712818826, "boom aft adds exactly 0 to y")
        XCTAssertEqual(r.x, -20)
        XCTAssertEqual(r.heelDeg, 0.0); XCTAssertEqual(r.heelDeg.sign, .plus); XCTAssertNil(r.ballastTonnes)
        // Same answer via move() with Start blank.
        guard case .ok(let m) = M.move(endAzimuthDeg: -180, endOutreach: 20, hookLoad: 80, displacement: 8000, gm: 1.5,
                                       pivotOffset: 0.13089972712818826, ballastLever: 12) else { return XCTFail("rejected") }
        XCTAssertEqual(m.single, r)
        // At 90° the lever is exactly R + pivot.
        guard case .ok(let b) = M.heel(azimuthDeg: 90, outreach: 20, hookLoad: 80, displacement: 8000, gm: 1.5) else { return XCTFail() }
        XCTAssertEqual(b.y, 20); XCTAssertEqual(b.x, 0)
    }

    func testSignedBallastAndSnap() throws {
        // Tiny Δy below the 1e-9 m snap → 0.0 (reference behaviour kept; QA MOVE.md mismatch 2 is out of scope).
        let t = try XCTUnwrap(Self.ok(In(endTheta: 30, endR: 20, startTheta: 30, startR: 20 + 1e-12)))
        XCTAssertEqual(t.deltaY, 0); XCTAssertEqual(t.heelDeg, 0); XCTAssertNil(t.signedBallastTonnes)
        // Display cap in move mode.
        let c = try XCTUnwrap(Self.ok(In(endTheta: 270, endR: 36, startTheta: 90, startR: 36, PL: 250, disp: 10, GM: 0.01)))
        XCTAssertEqual(c.heelDeg, -90); XCTAssertEqual(c.warning, .hard); XCTAssertLessThan(c.signedBallastTonnes ?? 0, 0)
    }

    // MARK: - Python-generated move fixture (crosscheck/cross_check_move.py, values from crane_heel_move())

    private struct Fixture: Decodable {
        struct Out: Decodable { let mode, dy, MH, phi, side, warn, ballast, pump: String }
        struct Case: Decodable { let `in`: [String?]; let lever: String?; let out: Out? }
        let reference_sha256: String
        let cases: [Case]
    }

    private static func dbl(_ hex: String) -> Double { Double(bitPattern: UInt64(hex, radix: 16)!) }

    func testPythonMoveFixture() throws {
        let url = try XCTUnwrap(Bundle(for: CraneHeelMoveMathTests.self).url(forResource: "crane_heel_move_fixture", withExtension: "json"))
        let fx = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(fx.cases.count, 600)
        func close(_ a: Double, _ b: Double) -> Bool { a == b || abs(a - b) <= 1e-12 * max(abs(a), abs(b)) + 1e-13 }
        var moves = 0, singles = 0, rejects = 0
        for (i, c) in fx.cases.enumerated() {
            let v = c.in.map { $0.map(Self.dbl) }
            let got = M.move(endAzimuthDeg: v[0]!, endOutreach: v[1]!, hookLoad: v[2]!, displacement: v[3]!, gm: v[4]!,
                             startAzimuthDeg: v[5], startOutreach: v[6], pivotOffset: v[7]!, ballastLever: c.lever.map(Self.dbl))
            guard let o = c.out else {
                rejects += 1
                if case .ok = got { XCTFail("move fixture #\(i): reference rejects, Swift accepted") }
                continue
            }
            guard case .ok(let r) = got else { XCTFail("move fixture #\(i): reference accepts, Swift rejected"); continue }
            if r.mode == .move { moves += 1 } else { singles += 1 }
            XCTAssertEqual(r.mode.rawValue, o.mode, "#\(i) mode")
            XCTAssertEqual(r.heelDeg.bitPattern, Self.dbl(o.phi).bitPattern, "#\(i) phi")
            XCTAssertEqual(r.side.rawValue, o.side, "#\(i) side")
            XCTAssertEqual(r.warning.rawValue, o.warn, "#\(i) warn")
            XCTAssertEqual(r.pumpTo?.rawValue ?? "-", o.pump, "#\(i) pump")
            XCTAssertEqual(r.ballastTonnes == nil, o.ballast == "-", "#\(i) ballast visibility")
            XCTAssertTrue(close(r.deltaY, Self.dbl(o.dy)), "#\(i) dy")
            XCTAssertTrue(close(r.heelingMoment, Self.dbl(o.MH)), "#\(i) MH")
            if let b = r.ballastTonnes, o.ballast != "-" { XCTAssertTrue(close(b, Self.dbl(o.ballast)), "#\(i) ballast") }
        }
        XCTAssertGreaterThan(moves, 300); XCTAssertGreaterThan(singles, 20); XCTAssertGreaterThan(rejects, 50)
    }
}
