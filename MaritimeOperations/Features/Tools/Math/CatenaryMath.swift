import Foundation

/// Free-hanging tow-wire / anchor-cable catenary helpers for MaritimeOperations.
/// Pure functions, Foundation only — no UIKit/SwiftUI.
///
/// # Unit convention (maritime sheet style)
/// - `H` bollard pull / horizontal tension in **tonnes-force** (sheet input).
/// - Converted internally to kilogram-force: `H_kg = H * 1000`.
/// - `w` linear density in **kg/m** (mass per metre; treated as kgf/m under g so units cancel).
/// - `S` paid-out wire length in **m**.
/// - Results `L` (horizontal span) and `h` (sag) in **m**.
///
/// Equivalent SI form uses `H_N = H * 1000 * 9.80665` and `w_Npm = w * 9.80665`;
/// the `g` factors cancel, so the kgf form below is identical and matches the sheet.
///
/// QA lock (sheet): H=106 t, w=108 kg/m, S=1500 m → L ≈ 1382.8 m, h ≈ 253.8 m.
///
/// Formulas:
///   L = (2·H_kg / w) · asinh(S·w / (2·H_kg))
///   h = sqrt((H_kg/w)² + (S/2)²) − H_kg/w
///   clearance = depth − h   (warning when h ≥ depth; free-hanging math still returned)
enum CatenaryMath {
    /// Standard gravity (m/s²). Documented for SI equivalence; not needed in the kgf form.
    static let g = 9.80665

    struct Result: Equatable {
        /// Horizontal span between ends, metres.
        let spanL: Double
        /// Sag (vertical drop from supports to lowest point for symmetric free hang), metres.
        let sag: Double
        /// `depth - sag`. Negative means the wire would touch / dig into the seabed under free-hanging assumptions.
        let clearance: Double?
        /// True when depth was provided and sag ≥ depth.
        let seabedWarning: Bool
        /// Echo of inputs used (after conversion).
        let H_kg: Double
        let w: Double
        let S: Double
    }

    enum Outcome: Equatable {
        case invalid(reason: String)
        case ok(Result)
    }

    /// Compute free-hanging catenary span and sag.
    /// - Parameters:
    ///   - H: bollard pull / horizontal tension, tonnes-force (> 0).
    ///   - w: wire mass per metre, kg/m (> 0).
    ///   - S: paid-out length, metres (> 0).
    ///   - depth: optional water depth, metres (> 0 if provided). Used only for clearance / warning.
    static func freeHang(H: Double, w: Double, S: Double, depth: Double? = nil) -> Outcome {
        guard H.isFinite, w.isFinite, S.isFinite, H > 0, w > 0, S > 0 else {
            return .invalid(reason: "H, w and S must be finite and > 0.")
        }
        if let d = depth {
            guard d.isFinite, d > 0 else {
                return .invalid(reason: "Depth must be finite and > 0 when provided.")
            }
        }

        let H_kg = H * 1000.0
        let half = S / 2.0
        let Hw = H_kg / w
        let arg = (S * w) / (2.0 * H_kg)
        guard arg.isFinite, Hw.isFinite else {
            return .invalid(reason: "Intermediate values not finite.")
        }

        let spanL = (2.0 * Hw) * asinh(arg)
        let sag = sqrt(Hw * Hw + half * half) - Hw
        guard spanL.isFinite, sag.isFinite, spanL >= 0, sag >= 0 else {
            return .invalid(reason: "Result not finite.")
        }

        var clearance: Double?
        var warn = false
        if let d = depth {
            clearance = d - sag
            warn = sag >= d
        }

        return .ok(Result(
            spanL: spanL,
            sag: sag,
            clearance: clearance,
            seabedWarning: warn,
            H_kg: H_kg,
            w: w,
            S: S
        ))
    }
}
