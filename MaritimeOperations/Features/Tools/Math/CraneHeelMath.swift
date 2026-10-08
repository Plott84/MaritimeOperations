import Foundation

/// Crane heel (static list from a shipboard crane lift) for MaritimeOperations.
/// Pure functions, Foundation only — no UIKit/SwiftUI.
/// **Deck estimate only** — not a class / IS Code / loading-computer calculation.
///
/// Port of `/workspace/crane-heel-reference/crane_heel_reference.py` (Builder, 157/157 checks).
/// Same IEEE operations in the same order, so on Linux/glibc the output is bit-identical to Python, except the
/// documented exact sin/cos at 0/90/180/270° (see "Two-point lift" below; crosscheck/exact_variant.py).
///
/// # Convention (locked)
/// Boom azimuth θ: 0° = bow, 90° = stbd, 180° = aft, 270° = port. θ wraps modulo 360
/// (−90 → 270, 361 → 1), using Python's `%` semantics (result in 0..<360, never −0.0).
///
/// # Formula (small angle)
///   y  = yPivot + R · sin θ            athwartship lever, m (+ stbd). |y| < 1e-9 → 0
///   x  = R · cos θ                     fore/aft component, m (+ fwd) — trim, not heel. |x| < 1e-9 → 0
///   MH = PL · y                        heeling moment, t·m (+ stbd)
///   tan φ = MH / (Δ · GM)              Δ already **includes** the lift (PL is not added)
///   φ shown = sign · ((|φ|·10).rounded(.toNearestOrAwayFromZero) / 10), capped ±90, never −0.0
///
/// # Warnings (on the ROUNDED heel)
///   soft: |φ| ≥ 5.0   hard: |φ| ≥ 10.0   (4.94 → 4.9 none, 4.95 → 5.0 soft, 9.95 → 10.0 hard)
///
/// # Ballast to level (optional, needs `ballastLever` > 0)
///   w = |MH| / ballastLever (t), pumped to the side opposite the load (MH > 0 → port).
///   Hidden (nil) when the shown heel is 0.0 (incl. raw −0.04°) — so also for boom on CL (0°/180°).
///
/// # Inputs
/// All inputs must be finite. R ≥ 0, PL ≥ 0, Δ > 0, GM > 0, ballastLever > 0 when given.
/// There are **no default Δ / GM values** for any ship — the user must enter them.
/// Invalid input → `.invalid(reason:)` with a field-specific string for Pixel (Python raises ValueError
/// for exactly the same set; Python's ZeroDivisionError / NaN-floor corner cases are also `.invalid`).
///
/// # Two-point lift — `move(...)` (Pixel B2)
/// Port of `crane_heel_move()` in the same reference (157/157). Ship assumed **level at Start** with the load on deck:
///   Δy = R_end·sin θ_end − R_start·sin θ_start   (unrounded; the pivot cancels). |Δy| < 1e-9 → 0
///   MH = PL·Δy,  φ = atan(MH / (Δ·GM)), then the same rounding / cap / warning / ballast rules as `heel`.
/// Start blank (both nil) → exactly `heel(...)` (single point, pivot matters). Only one Start value → invalid.
/// **Deliberate difference from the reference (QA MOVE.md #1/#7, locked 2026-10-07):** sin/cos are exact at
/// wrapped 0/90/180/270° in BOTH `move` and single-point `heel` (the reference's sin(180°) = 1.22e-16 m/m can tip a
/// raw x.x5° tie the wrong way). Applied to `heel` only after the 27 locked cases and the locked single-point fixture
/// passed unchanged. Everywhere else the same libm path as Python, bit-identical on Linux/glibc.
public enum CraneHeelMath {
    /// Soft warning threshold on the rounded heel, degrees (inclusive).
    public static let softWarnDeg = 5.0
    /// Hard warning threshold on the rounded heel, degrees (inclusive).
    public static let hardWarnDeg = 10.0
    /// Display cap for |heel|, degrees.
    public static let displayCapDeg = 90.0
    /// |y| or |x| below this is snapped to exactly 0 (sin 180° noise).
    static let snapEpsilon = 1e-9

    /// Which way the ship lists, from the **rounded** heel.
    public enum HeelSide: String, Equatable, Sendable {
        case stbd, port, upright
    }

    public enum Warning: String, Equatable, Sendable {
        case none, soft, hard
    }

    /// Side to pump ballast towards (opposite the load).
    public enum Board: String, Equatable, Sendable {
        case port, stbd
    }

    public struct Result: Equatable, Sendable {
        /// Azimuth after wrapping, 0..<360 degrees (for the ring / slider).
        public let azimuthDeg: Double
        /// Athwartship lever of the hook, m (+ stbd).
        public let y: Double
        /// Fore/aft component of the outreach, m (+ fwd). Goes into trim, not heel.
        public let x: Double
        /// Heeling moment MH = PL·y, t·m (+ stbd). Never −0.0.
        public let heelingMoment: Double
        /// Displayed heel, degrees, 1 decimal, + = stbd, |φ| ≤ 90, never −0.0. **Hero number.**
        public let heelDeg: Double
        public let side: HeelSide
        public let warning: Warning
        /// Ballast to level, tonnes. nil when no lever given or shown heel is 0.0.
        public let ballastTonnes: Double?
        /// Pump-to side. nil whenever `ballastTonnes` is nil.
        public let pumpTo: Board?
    }

    public enum Outcome: Equatable, Sendable {
        case invalid(reason: String)
        case ok(Result)
    }

    /// Field-specific reasons (exact strings for Pixel).
    public enum Reason {
        public static let azimuth = "Check boom azimuth"
        public static let outreach = "Check outreach"
        public static let hookLoad = "Check hook load"
        public static let displacement = "Check displacement"
        public static let gm = "Check GM"
        public static let pivotOffset = "Check pivot offset"
        public static let ballastLever = "Check ballast lever"
        /// Δ·GM underflows to 0, or the moment/lever overflow to NaN (unrealistic magnitudes).
        public static let outOfRange = "Check inputs"
    }

    /// Python `theta % 360.0`: fmod, shift negatives by +360, and +0.0 for zero.
    /// −90 → 270, 361 → 1, −360 → 0. Non-finite input returns NaN (callers gate first).
    /// `nonisolated`: pure, so it can be passed or called from any isolation (the app builds with
    /// default MainActor isolation; `Optional.map(CraneHeelMath.wrapAzimuth)` used to warn). No behaviour change.
    nonisolated public static func wrapAzimuth(_ deg: Double) -> Double {
        var m = deg.truncatingRemainder(dividingBy: 360.0)  // == C fmod, exact
        if m != 0 {
            if m < 0 { m += 360.0 }
        } else {
            m = 0.0  // drop −0.0
        }
        return m
    }

    /// Display rounding to 0.1°, half AWAY from zero, sign restored, never −0.0. Used for the heel AND the ballast tonnes
    /// (same as the reference's `round1`).
    ///
    /// **Exactly what it rounds:** the binary `Double`, not the decimal text you would type. Step by step:
    ///   1. `p = |φ| * 10.0` in Double arithmetic — this product is itself rounded to the nearest Double;
    ///   2. `p.rounded(.toNearestOrAwayFromZero)` — a `.5` goes up (away from zero), anything below goes down;
    ///   3. divide by 10.0, restore the sign, turn −0.0 into 0.0.
    /// So it is NOT "decimal half-up of the exact binary value". Pinned example (QA 2026-10-07):
    ///   raw `26.049999999999997` (exact binary value 26.04999999999999715782905696…) shows **26.1**, because
    ///   26.049999999999997 × 10 rounds to exactly 260.5 in step 1, which step 2 takes to 261.
    ///   Decimal rounding of the exact value would give 26.0. The next Double down, 26.049999999999994, gives
    ///   260.49999999999994 → 26.0. `String(format: "%.1f")` also shows 26.0 for the raw value — don't use it.
    /// Other pins: 9.95 → 10.0, 4.95 → 5.0, −4.95 → −5.0, 0.15 → 0.2 (0.15 is 0.1499999999999999944… but ×10 = 1.5),
    /// −0.04 → 0.0. Ties are only "exact" to the last bit: 1-ulp differences in libm (Darwin vs glibc) can move a raw
    /// value sitting within ~1e-15° of an x.x5 tie to the other side.
    public static func roundHeel(_ phi: Double) -> Double {
        let r = (abs(phi) * 10.0).rounded(.toNearestOrAwayFromZero) / 10.0
        let v = phi.sign == .minus ? -r : r
        return v == 0 ? 0.0 : v
    }

    /// Static heel from a crane lift.
    /// - Parameters:
    ///   - azimuthDeg: boom azimuth θ, degrees (0 bow, 90 stbd, 180 aft, 270 port; any finite value, wrapped).
    ///   - outreach: horizontal outreach R from the crane pivot, m (≥ 0).
    ///   - hookLoad: PL incl. hook + rigging + spreader, t (≥ 0).
    ///   - displacement: Δ **including the lift**, t (> 0). No default.
    ///   - gm: transverse GM (FSC-corrected if known), m (> 0). No default.
    ///   - pivotOffset: crane pivot off centreline, m, + stbd (default 0 = on CL).
    ///   - ballastLever: optional transverse lever for ballast-to-level, m (> 0 when given).
    public static func heel(
        azimuthDeg: Double,
        outreach R: Double,
        hookLoad PL: Double,
        displacement disp: Double,
        gm GM: Double,
        pivotOffset yPivot: Double = 0.0,
        ballastLever: Double? = nil
    ) -> Outcome {
        // Finite gates first (reference checks all values before any range check).
        guard azimuthDeg.isFinite else { return .invalid(reason: Reason.azimuth) }
        guard R.isFinite else { return .invalid(reason: Reason.outreach) }
        guard PL.isFinite else { return .invalid(reason: Reason.hookLoad) }
        guard disp.isFinite else { return .invalid(reason: Reason.displacement) }
        guard GM.isFinite else { return .invalid(reason: Reason.gm) }
        guard yPivot.isFinite else { return .invalid(reason: Reason.pivotOffset) }
        if let lever = ballastLever, !lever.isFinite { return .invalid(reason: Reason.ballastLever) }

        let theta = wrapAzimuth(azimuthDeg)
        guard R >= 0 else { return .invalid(reason: Reason.outreach) }
        guard PL >= 0 else { return .invalid(reason: Reason.hookLoad) }
        guard disp > 0 else { return .invalid(reason: Reason.displacement) }
        guard GM > 0 else { return .invalid(reason: Reason.gm) }
        if let lever = ballastLever, !(lever > 0) { return .invalid(reason: Reason.ballastLever) }

        // Same op order as Python: math.radians(x) == x * (pi / 180).
        // Exact sin/cos at 0/90/180/270 (QA MOVE.md #7); elsewhere the same libm path as Python.
        let sc = exactSinCos(wrappedDeg: theta)
        var y = yPivot + R * sc.sin
        if abs(y) < snapEpsilon { y = 0.0 }
        var x = R * sc.cos
        if abs(x) < snapEpsilon { x = 0.0 }
        var mh = PL * y + 0.0
        if mh == 0 { mh = 0.0 }

        let denom = disp * GM
        // Python raises ZeroDivisionError here (Δ·GM underflow, e.g. 1e-200 · 1e-200).
        guard denom != 0 else { return .invalid(reason: Reason.outOfRange) }
        // math.degrees(x) == x * (180 / pi).
        let raw = atan(mh / denom) * (180.0 / Double.pi)
        // Python's floor(NaN) raises ValueError (inf·0 or inf/inf from overflowing magnitudes).
        guard !raw.isNaN else { return .invalid(reason: Reason.outOfRange) }

        var phi = roundHeel(raw)                                   // displayed value, 1 decimal
        phi = max(-displayCapDeg, min(displayCapDeg, phi))         // display cap
        if phi == 0 { phi = 0.0 }                                  // never −0.0

        let a = abs(phi)                                           // warn on the ROUNDED value
        let warning: Warning = a >= hardWarnDeg ? .hard : (a >= softWarnDeg ? .soft : .none)
        let side: HeelSide = phi > 0 ? .stbd : (phi < 0 ? .port : .upright)

        var ballast: Double? = nil
        if let lever = ballastLever, phi != 0 {                    // hidden when shown upright
            ballast = abs(mh) / lever
        }
        var pumpTo: Board? = nil
        if ballast != nil, mh != 0 {
            pumpTo = mh > 0 ? .port : .stbd
        }

        return .ok(Result(
            azimuthDeg: theta,
            y: y,
            x: x,
            heelingMoment: mh,
            heelDeg: phi,
            side: side,
            warning: warning,
            ballastTonnes: ballast,
            pumpTo: pumpTo
        ))
    }

    // MARK: - Two-point lift (B2)

    /// Single point (Start blank) or two-point move.
    public enum LiftMode: String, Equatable, Sendable {
        case single, move
    }

    public struct MoveResult: Equatable, Sendable {
        public let mode: LiftMode
        /// End azimuth after wrapping, 0..<360.
        public let endAzimuthDeg: Double
        /// Start azimuth after wrapping; nil in `.single` mode.
        public let startAzimuthDeg: Double?
        /// Transverse shift of the hook, m (+ stbd). `.move`: y_end − y_start (pivot cancels).
        /// `.single`: y_end incl. pivot (reference `y`).
        public let deltaY: Double
        /// Heeling moment, t·m (+ stbd). Never −0.0.
        public let heelingMoment: Double
        /// Displayed End heel, 1 decimal, + stbd, |φ| ≤ 90, never −0.0. The only heel the screen shows.
        public let heelDeg: Double
        public let side: HeelSide
        public let warning: Warning
        /// |MH| / d, tonnes (unrounded, reference `ballast_t`). nil without a tank distance or when the shown heel is 0.0.
        public let ballastTonnes: Double?
        /// Tank that receives water. nil whenever `ballastTonnes` is nil.
        public let pumpTo: Board?
        /// The full single-point result in `.single` mode (bit-identical to `heel(...)`), nil in `.move`.
        public let single: Result?

        /// Signed w = MH / d: + = stbd tank → port tank, − = port tank → stbd tank. nil when the tile is hidden.
        public var signedBallastTonnes: Double? {
            guard let w = ballastTonnes else { return nil }
            return heelingMoment < 0 ? -w : w
        }
    }

    public enum MoveOutcome: Equatable, Sendable {
        case invalid(reason: String)
        case ok(MoveResult)
    }

    /// Extra reasons for the Start fields.
    public enum MoveReason {
        public static let startAzimuth = "Check start azimuth"
        public static let startOutreach = "Check start outreach"
        /// Only one of the two Start values given.
        public static let startIncomplete = "Enter start azimuth and outreach, or leave both empty"
    }

    /// sin / cos of a **wrapped** azimuth (0..<360), exact at 0/90/180/270 (QA MOVE.md #7). Used by `heel` and `move`.
    nonisolated public static func exactSinCos(wrappedDeg theta: Double) -> (sin: Double, cos: Double) {
        switch theta {
        case 0: return (0.0, 1.0)
        case 90: return (1.0, 0.0)
        case 180: return (0.0, -1.0)
        case 270: return (-1.0, 0.0)
        default:
            let t = theta * (Double.pi / 180.0)   // == Python math.radians
            return (sin(t), cos(t))
        }
    }

    /// Two-point lift heel (B2). Port of `crane_heel_move()`; see the type doc for the one deliberate difference.
    /// - Parameters:
    ///   - endAzimuthDeg / endOutreach: boom over the side (End), any finite azimuth (wrapped), R ≥ 0.
    ///   - startAzimuthDeg / startOutreach: load on deck (Start). Both nil → single point. One nil → invalid.
    ///   - pivotOffset: only used by the single-point fallback (cancels in a move), must still be finite.
    public static func move(
        endAzimuthDeg: Double,
        endOutreach: Double,
        hookLoad PL: Double,
        displacement disp: Double,
        gm GM: Double,
        startAzimuthDeg: Double? = nil,
        startOutreach: Double? = nil,
        pivotOffset yPivot: Double = 0.0,
        ballastLever: Double? = nil
    ) -> MoveOutcome {
        if startAzimuthDeg == nil && startOutreach == nil {
            switch heel(azimuthDeg: endAzimuthDeg, outreach: endOutreach, hookLoad: PL, displacement: disp,
                        gm: GM, pivotOffset: yPivot, ballastLever: ballastLever) {
            case .invalid(let reason):
                return .invalid(reason: reason)
            case .ok(let r):
                return .ok(MoveResult(mode: .single, endAzimuthDeg: r.azimuthDeg, startAzimuthDeg: nil, deltaY: r.y,
                                      heelingMoment: r.heelingMoment, heelDeg: r.heelDeg, side: r.side,
                                      warning: r.warning, ballastTonnes: r.ballastTonnes, pumpTo: r.pumpTo, single: r))
            }
        }
        guard let startTheta = startAzimuthDeg, let startR = startOutreach else {
            return .invalid(reason: MoveReason.startIncomplete)
        }
        // Finite gates, reference order: end θ, end R, start θ, start R, PL, Δ, GM, pivot, lever.
        guard endAzimuthDeg.isFinite else { return .invalid(reason: Reason.azimuth) }
        guard endOutreach.isFinite else { return .invalid(reason: Reason.outreach) }
        guard startTheta.isFinite else { return .invalid(reason: MoveReason.startAzimuth) }
        guard startR.isFinite else { return .invalid(reason: MoveReason.startOutreach) }
        guard PL.isFinite else { return .invalid(reason: Reason.hookLoad) }
        guard disp.isFinite else { return .invalid(reason: Reason.displacement) }
        guard GM.isFinite else { return .invalid(reason: Reason.gm) }
        guard yPivot.isFinite else { return .invalid(reason: Reason.pivotOffset) }
        if let lever = ballastLever, !lever.isFinite { return .invalid(reason: Reason.ballastLever) }
        // Range gates.
        guard endOutreach >= 0 else { return .invalid(reason: Reason.outreach) }
        guard startR >= 0 else { return .invalid(reason: MoveReason.startOutreach) }
        guard PL >= 0 else { return .invalid(reason: Reason.hookLoad) }
        guard disp > 0 else { return .invalid(reason: Reason.displacement) }
        guard GM > 0 else { return .invalid(reason: Reason.gm) }
        if let lever = ballastLever, !(lever > 0) { return .invalid(reason: Reason.ballastLever) }

        let thS = wrapAzimuth(startTheta)
        let thE = wrapAzimuth(endAzimuthDeg)
        let ys = startR * exactSinCos(wrappedDeg: thS).sin
        let ye = endOutreach * exactSinCos(wrappedDeg: thE).sin
        var dy = ye - ys                                           // pivot cancels
        if abs(dy) < snapEpsilon { dy = 0.0 }
        var mh = PL * dy + 0.0
        if mh == 0 { mh = 0.0 }

        let denom = disp * GM
        guard denom != 0 else { return .invalid(reason: Reason.outOfRange) }      // Python ZeroDivisionError
        let raw = atan(mh / denom) * (180.0 / Double.pi)
        guard !raw.isNaN else { return .invalid(reason: Reason.outOfRange) }      // Python floor(NaN) ValueError

        var phi = roundHeel(raw)
        phi = max(-displayCapDeg, min(displayCapDeg, phi))
        if phi == 0 { phi = 0.0 }
        let a = abs(phi)
        let warning: Warning = a >= hardWarnDeg ? .hard : (a >= softWarnDeg ? .soft : .none)
        let side: HeelSide = phi > 0 ? .stbd : (phi < 0 ? .port : .upright)
        var ballast: Double? = nil
        if let lever = ballastLever, phi != 0 { ballast = abs(mh) / lever }
        var pumpTo: Board? = nil
        if ballast != nil, mh != 0 { pumpTo = mh > 0 ? .port : .stbd }

        return .ok(MoveResult(mode: .move, endAzimuthDeg: thE, startAzimuthDeg: thS, deltaY: dy,
                              heelingMoment: mh, heelDeg: phi, side: side, warning: warning,
                              ballastTonnes: ballast, pumpTo: pumpTo, single: nil))
    }
}
