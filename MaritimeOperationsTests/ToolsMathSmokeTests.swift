import Testing
import Foundation
@testable import MaritimeOperations

struct ToolsMathSmokeTests {
    @Test func catenarySheetLock() {
        let outcome = CatenaryMath.freeHang(H: 106, w: 108, S: 1500)
        guard case .ok(let r) = outcome else {
            Issue.record("Expected ok outcome")
            return
        }
        #expect(abs(r.spanL - 1382.8) < 0.6)
        #expect(abs(r.sag - 253.8) < 0.6)
    }

    @Test func chainLockerShotLock() {
        let outcome = ChainLockerMath.volume(diameterMm: 76, shots: 25, shotLengthM: 27.5)
        guard case .ok(let r) = outcome else {
            Issue.record("Expected ok outcome")
            return
        }
        #expect(abs(r.volumeM3 - 81.0) < 0.15)
        #expect(abs(r.classVolumeM3 - 43.7) < 0.15)
    }

    @Test func winchFullDrumLock() {
        // d=76, D0=1400, W=2000, Df=3600, free=0, dead=3 → working ≈ 2804.49 / 14 layers
        let outcome = WinchCapacityMath.capacity(
            ropeDiameter: 76,
            barrelDiameter: 1400,
            drumWidth: 2000,
            flangeDiameter: 3600,
            deadWraps: 3,
            freeSpaceMm: 0
        )
        guard case .ok(let r) = outcome else {
            Issue.record("Expected ok outcome")
            return
        }
        #expect(r.layerCount == 14)
        #expect(abs(r.workingLengthM - 2804.49) < 1.0)
    }

    @Test func winchFreeSpaceTWLock() {
        // d=87, D0=1800, W=3400, Df=4300, free empty(=400), dead=3, F1=170
        // → 9 layers, working ≈ 2831 m, top ≈ 98 t
        let outcome = WinchCapacityMath.capacity(
            ropeDiameter: 87,
            barrelDiameter: 1800,
            drumWidth: 3400,
            flangeDiameter: 4300,
            deadWraps: 3,
            freeSpaceMm: 400,
            firstLayerPullTonnes: 170
        )
        guard case .ok(let r) = outcome else {
            Issue.record("Expected ok outcome")
            return
        }
        #expect(r.layerCount == 9)
        #expect(abs(r.workingLengthM - 2831) < 2.0)
        #expect(abs((r.topLayerPullTonnes ?? -1) - 98) < 1.5)
    }
}
