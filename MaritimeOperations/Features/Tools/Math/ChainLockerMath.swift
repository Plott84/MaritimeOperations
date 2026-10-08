import Foundation

/// Anchor-chain locker volume helpers for MaritimeOperations.
/// Pure functions, Foundation only — no UIKit/SwiftUI.
///
/// # Primary (shipyard / stowage rule of thumb)
///   V = L · d² / 49000     (m³)
///   where d = chain diameter in **mm**, L = total chain length in **m**.
///
/// # Length from shots
///   L = shots · shotLengthM   (default shotLengthM = 27.5 m, a common “shot” / shackle)
///
/// # Optional class / rule-of-thumb secondary
///   V_class = 1.1 · d² · L · 1e-5     (m³)
///   (often cited in class-society style estimates; smaller than primary stowage volume)
///
/// Example: d=76 mm, 25 shots × 27.5 m → L=687.5 m → V≈81.0 m³, V_class≈43.7 m³.
enum ChainLockerMath {
    /// Default shot / shackle length in metres.
    static let defaultShotLengthM = 27.5
    /// Inclusive shot-length range (m). Pixel: 10…50 covers 25 / 27.5 / 90 ft (27.4).
    static let minShotLengthM = 10.0
    static let maxShotLengthM = 50.0

    struct VolumeResult: Equatable {
        let lengthM: Double
        /// Primary stowage volume V = L·d²/49000 (m³).
        let volumeM3: Double
        /// Optional class estimate 1.1·d²·L·1e-5 (m³).
        let classVolumeM3: Double
        let diameterMm: Double
        let shots: Double?
        let shotLengthM: Double?
    }

    enum Outcome: Equatable {
        case invalid(reason: String)
        case ok(VolumeResult)
    }

    /// Volume from chain diameter and total length.
    static func volume(diameterMm d: Double, lengthM L: Double) -> Outcome {
        guard d.isFinite, L.isFinite, d > 0, L > 0 else {
            return .invalid(reason: "Diameter (mm) and length (m) must be finite and > 0.")
        }
        let V = L * d * d / 49000.0
        let Vc = 1.1 * d * d * L * 1e-5
        guard V.isFinite, Vc.isFinite else {
            return .invalid(reason: "Result not finite.")
        }
        return .ok(VolumeResult(
            lengthM: L,
            volumeM3: V,
            classVolumeM3: Vc,
            diameterMm: d,
            shots: nil,
            shotLengthM: nil
        ))
    }

    /// Volume from diameter and number of shots (shackles).
    static func volume(
        diameterMm d: Double,
        shots: Double,
        shotLengthM: Double = ChainLockerMath.defaultShotLengthM
    ) -> Outcome {
        guard shots.isFinite, shots > 0 else {
            return .invalid(reason: "Check shots")
        }
        guard shotLengthM.isFinite,
              shotLengthM >= minShotLengthM,
              shotLengthM <= maxShotLengthM else {
            return .invalid(reason: "Check shot length")
        }
        let L = shots * shotLengthM
        switch volume(diameterMm: d, lengthM: L) {
        case .invalid(let reason):
            return .invalid(reason: reason)
        case .ok(let base):
            return .ok(VolumeResult(
                lengthM: base.lengthM,
                volumeM3: base.volumeM3,
                classVolumeM3: base.classVolumeM3,
                diameterMm: base.diameterMm,
                shots: shots,
                shotLengthM: shotLengthM
            ))
        }
    }

    /// Invert primary formula: L = V · 49000 / d².
    static func lengthFromVolume(volumeM3 V: Double, diameterMm d: Double) -> Outcome {
        guard V.isFinite, d.isFinite, V > 0, d > 0 else {
            return .invalid(reason: "Volume (m³) and diameter (mm) must be finite and > 0.")
        }
        let L = V * 49000.0 / (d * d)
        guard L.isFinite, L > 0 else {
            return .invalid(reason: "Result not finite.")
        }
        let Vc = 1.1 * d * d * L * 1e-5
        return .ok(VolumeResult(
            lengthM: L,
            volumeM3: V,
            classVolumeM3: Vc,
            diameterMm: d,
            shots: nil,
            shotLengthM: nil
        ))
    }

    /// Invert primary formula via shots: shots = L / shotLengthM.
    static func shotsFromVolume(
        volumeM3 V: Double,
        diameterMm d: Double,
        shotLengthM: Double = ChainLockerMath.defaultShotLengthM
    ) -> Outcome {
        guard shotLengthM.isFinite,
              shotLengthM >= minShotLengthM,
              shotLengthM <= maxShotLengthM else {
            return .invalid(reason: "Check shot length")
        }
        switch lengthFromVolume(volumeM3: V, diameterMm: d) {
        case .invalid(let reason):
            return .invalid(reason: reason)
        case .ok(let base):
            let shots = base.lengthM / shotLengthM
            // Tiny shot length → shots can be inf; Pixel: red field "Check shot length" + dash.
            guard shots.isFinite else {
                return .invalid(reason: "Check shot length")
            }
            return .ok(VolumeResult(
                lengthM: base.lengthM,
                volumeM3: base.volumeM3,
                classVolumeM3: base.classVolumeM3,
                diameterMm: base.diameterMm,
                shots: shots,
                shotLengthM: shotLengthM
            ))
        }
    }
}
