import Foundation

/// Winch / reel drum wire-rope capacity (layer method) for MaritimeOperations.
/// Pure functions, Foundation only — no UIKit/SwiftUI.
///
/// # Formula (standard drum capacity, layer by layer)
/// Inputs (consistent length unit — typically **mm** for diameters/width):
///   - d  = rope diameter
///   - D0 = barrel (core) diameter
///   - W  = usable drum width between flanges
///   - Df = flange outer diameter (optional; limits max layers)
///   - freeSpaceMm = radial free space per side (default **400**). Usable fill OD = Df − 2·freeSpaceMm (Scout lock).
///     Pass `0` for a full drum. Ignored for layer count when Df is nil.
///   - deadWraps = anchor wraps that must remain on the drum (default **3**)
///   - firstLayerPullTonnes = optional 1st-layer line pull (tonnes). Constant-torque derate per layer.
///
/// Per layer k = 1…N (1-based, innermost first):
///   wrapsPerLayer = floor(W / d + ε)
///   pitchDiameter_k = D0 + d · (2k − 1)
///   length_k = wrapsPerLayer · π · pitchDiameter_k
///   pull_k = F1 · (pitchDiameter_1 / pitchDiameter_k)   // when F1 provided
///
/// Max layers when Df is given:
///   usableOD = Df − 2 · freeSpaceMm
///   N = floor( (usableOD − D0) / (2 · d) + ε )
///
/// # Pixel / UI
/// The **hero number is `workingLengthM`** (storage after subtracting dead wraps).
/// Locked T/W starboard-ish (free space 400): d=87, D0=1800, W=3400, Df=4300, freeSpace=400, dead=3
///   → 9 layers, **working ≈ 2831 m**; with F1=170 t → **top ≈ 98 t**.
/// Full drum (freeSpace=0): same dims → 14 layers, storage ≈ 5177 m (maker ~5200).
///
/// Wire diameter must be in **6…250 mm** (inclusive). Outside → `.invalid("Check wire size")`.
/// Field-specific invalid reasons (exact strings for Pixel):
///   - `"Check wire size"` — rope diameter outside 6…250 mm
///   - `"Check drum width"` — W &lt; d, or wraps overflow / huge W
///   - `"Check flange size"` — bad / overflowing flange
///   - `"Check free space"` — free space leaves usable OD ≤ D0
///   - `"Check barrel size"` — barrel yields non-finite totals
///   - `"Check 1st layer pull"` — pull provided but not finite / ≤ 0
///
/// If `layerCount > 40`, `Result.layersExcessive` is true (Pixel shows numbers + red pill).
/// Hard-cap: N > 10_000 → invalid (crash guard).
///
/// Pull is for the rope the maker rated (constant-torque model).
///
/// Line-pull-per-layer is implemented when `firstLayerPullTonnes` is set.
enum WinchCapacityMath {
    static let defaultDeadWraps = 3
    static let defaultFreeSpaceMm = 400.0
    /// Inclusive rope diameter range in millimetres.
    static let minRopeDiameterMm = 6.0
    static let maxRopeDiameterMm = 250.0
    /// Pixel warning threshold: pill when layerCount > this (40 = OK, 41 = warn).
    static let layersExcessiveThreshold = 40
    /// Hard ceiling on layer count to avoid runaway loops / memory.
    static let maxLayersHardCap = 10_000
    private static let floorEpsilon = 1e-9

    struct Layer: Equatable {
        let index: Int          // 1-based
        let wraps: Int
        let pitchDiameter: Double
        let length: Double      // same unit as D0/d/W before scale
        /// Constant-torque pull at this layer (tonnes). nil when pull not requested.
        let pullTonnes: Double?
    }

    struct Result: Equatable {
        let layers: [Layer]
        let layerCount: Int
        /// Total rope that fits (includes dead wraps), metres.
        let storageLengthM: Double
        /// Approximate length of dead wraps on the barrel, metres.
        let deadLengthM: Double
        /// Usable paid-out length (storage − dead), metres. **Pixel hero number.**
        let workingLengthM: Double
        let wrapsPerLayer: Int
        let deadWraps: Int
        let freeSpaceMm: Double
        /// Usable fill OD used for layer count (Df − 2·freeSpace), or nil if no Df.
        let usableFlangeDiameter: Double?
        let ropeDiameter: Double
        let barrelDiameter: Double
        let drumWidth: Double
        let flangeDiameter: Double?
        /// Unit of d/D0/W/Df before conversion ("mm" or "m").
        let inputUnit: String
        /// Echo of 1st-layer pull input (tonnes), nil if not requested.
        let firstLayerPullTonnes: Double?
        /// Pull on the outermost computed layer (tonnes), nil if pull not requested.
        let topLayerPullTonnes: Double?

        /// Pixel: show "Check sizes, over 40 layers" pill when true. Exactly 40 does **not** flag.
        var layersExcessive: Bool { layerCount > WinchCapacityMath.layersExcessiveThreshold }
    }

    enum Outcome: Equatable {
        case invalid(reason: String)
        case ok(Result)
    }

    /// Safe `Int(floor(x))` — nil if non-finite, &lt; 1, or `floored >= 2^63` (exactly 2^63 must not call `Int()`).
    private static func safeFloorInt(_ x: Double) -> Int? {
        guard x.isFinite else { return nil }
        let floored = floor(x)
        // Use `< Double(Int.max)`: Double(Int.max) rounds up to 2^63, so `<=` would let 2^63 through and crash.
        guard floored.isFinite, floored >= 1.0, floored < Double(Int.max) else { return nil }
        return Int(floored)
    }

    /// Drum capacity by the layer method.
    /// - Parameters:
    ///   - freeSpaceMm: radial free space per side in mm (default 400). `0` = full drum.
    ///     When `inputUnit == "m"`, pass metres (default still means 0.4 m if you override unit — prefer mm inputs).
    ///   - firstLayerPullTonnes: optional 1st-layer pull in tonnes; enables per-layer pull fields.
    static func capacity(
        ropeDiameter d: Double,
        barrelDiameter D0: Double,
        drumWidth W: Double,
        flangeDiameter Df: Double? = nil,
        maxLayers: Int? = nil,
        deadWraps: Int = WinchCapacityMath.defaultDeadWraps,
        freeSpaceMm: Double = WinchCapacityMath.defaultFreeSpaceMm,
        firstLayerPullTonnes: Double? = nil,
        inputUnit: String = "mm"
    ) -> Outcome {
        guard d.isFinite, d > 0 else {
            return .invalid(reason: "Check wire size")
        }
        guard D0.isFinite, D0 > 0 else {
            return .invalid(reason: "Check barrel size")
        }
        guard W.isFinite, W > 0 else {
            return .invalid(reason: "Check drum width")
        }
        guard deadWraps >= 0 else {
            return .invalid(reason: "deadWraps must be ≥ 0.")
        }
        guard freeSpaceMm.isFinite, freeSpaceMm >= 0 else {
            return .invalid(reason: "Check free space")
        }

        let scale: Double
        let dMm: Double
        let freeSpaceInInputUnit: Double
        switch inputUnit.lowercased() {
        case "mm":
            scale = 0.001
            dMm = d
            freeSpaceInInputUnit = freeSpaceMm
        case "m":
            scale = 1.0
            dMm = d * 1000.0
            // API still takes freeSpaceMm in millimetres for a stable Pixel default (400).
            freeSpaceInInputUnit = freeSpaceMm * 0.001
        default:
            return .invalid(reason: "inputUnit must be \"mm\" or \"m\".")
        }

        // Wire size gate (UI: red field + dash). Inclusive 6…250 mm.
        guard dMm.isFinite, dMm >= minRopeDiameterMm, dMm <= maxRopeDiameterMm else {
            return .invalid(reason: "Check wire size")
        }

        // Optional pull
        let F1: Double?
        if let f = firstLayerPullTonnes {
            guard f.isFinite, f > 0 else {
                return .invalid(reason: "Check 1st layer pull")
            }
            F1 = f
        } else {
            F1 = nil
        }

        var usableOD: Double? = nil
        if let df = Df {
            guard df.isFinite, df > D0 else {
                return .invalid(reason: "Check flange size")
            }
            let u = df - 2.0 * freeSpaceInInputUnit
            guard u.isFinite else {
                return .invalid(reason: "Check free space")
            }
            guard u > D0 else {
                return .invalid(reason: "Check free space")
            }
            usableOD = u
        }

        // +ε absorbs binary float noise; safeFloorInt refuses overflow / non-finite.
        guard let wraps = safeFloorInt(W / d + floorEpsilon) else {
            return .invalid(reason: "Check drum width")
        }

        let nFromFlange: Int?
        if let u = usableOD {
            let raw = (u - D0) / (2.0 * d) + floorEpsilon
            guard let n = safeFloorInt(raw) else {
                return .invalid(reason: "Check flange size")
            }
            nFromFlange = n
        } else {
            nFromFlange = nil
        }

        let N: Int
        if let nf = nFromFlange, let ml = maxLayers {
            guard ml >= 1 else { return .invalid(reason: "maxLayers must be ≥ 1.") }
            N = min(nf, ml)
        } else if let nf = nFromFlange {
            N = nf
        } else if let ml = maxLayers {
            guard ml >= 1 else { return .invalid(reason: "maxLayers must be ≥ 1.") }
            N = ml
        } else {
            return .invalid(reason: "Provide flangeDiameter Df and/or maxLayers.")
        }

        guard N <= maxLayersHardCap else {
            if nFromFlange != nil {
                return .invalid(reason: "Check flange size")
            }
            return .invalid(reason: "Layer count exceeds safe limit.")
        }

        var layers: [Layer] = []
        var total = 0.0
        let pitch1 = D0 + d  // k=1
        for k in 1...N {
            let pitch = D0 + d * Double(2 * k - 1)
            let len = Double(wraps) * Double.pi * pitch
            guard pitch.isFinite, len.isFinite else {
                return .invalid(reason: "Check barrel size")
            }
            var pull: Double? = nil
            if let f1 = F1 {
                let p = f1 * (pitch1 / pitch)
                guard p.isFinite else {
                    return .invalid(reason: "Check 1st layer pull")
                }
                pull = p
            }
            layers.append(Layer(index: k, wraps: wraps, pitchDiameter: pitch, length: len, pullTonnes: pull))
            total += len
        }

        let deadLen = Double(deadWraps) * Double.pi * D0
        let storageM = total * scale
        let deadM = deadLen * scale
        let workingM = max(0.0, storageM - deadM)

        guard storageM.isFinite, deadM.isFinite, workingM.isFinite else {
            return .invalid(reason: "Check barrel size")
        }

        let topPull = layers.last?.pullTonnes

        return .ok(Result(
            layers: layers,
            layerCount: N,
            storageLengthM: storageM,
            deadLengthM: deadM,
            workingLengthM: workingM,
            wrapsPerLayer: wraps,
            deadWraps: deadWraps,
            freeSpaceMm: freeSpaceMm,
            usableFlangeDiameter: usableOD,
            ropeDiameter: d,
            barrelDiameter: D0,
            drumWidth: W,
            flangeDiameter: Df,
            inputUnit: inputUnit.lowercased(),
            firstLayerPullTonnes: F1,
            topLayerPullTonnes: topPull
        ))
    }
}
