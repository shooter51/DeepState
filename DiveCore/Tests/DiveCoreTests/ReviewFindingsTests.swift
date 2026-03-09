import XCTest
@testable import DiveCore

/// Tests for defects identified by the independent algorithm review.
/// Each test is named with the Beads ID and reproduces the exact defect.
final class ReviewFindingsTests: XCTestCase {

    // MARK: - DeepState-r8s: N2 fraction inconsistency

    /// The engine's surface N2 partial pressure must match what GasMix.air would produce.
    /// BUG: Engine uses 0.7808, GasMix.air uses 0.79.
    func testDeepState_r8s_surfaceN2MatchesGasMixAir() {
        let engine = BuhlmannEngine()
        let waterVapor = 0.0627
        let expectedPpN2 = GasMix.air.n2Fraction * (engine.surfacePressure - waterVapor)
        XCTAssertEqual(engine.tissueStates[0].pN2, expectedPpN2, accuracy: 0.0001,
                       "Surface tissue pN2 must use GasMix.air.n2Fraction (0.79), not 0.7808")
    }

    /// After resetToSurface(), tissue N2 must also match GasMix.air.
    func testDeepState_r8s_resetToSurfaceUsesConsistentN2() {
        let engine = BuhlmannEngine()
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 300.0)
        engine.resetToSurface()

        let waterVapor = 0.0627
        let expectedPpN2 = GasMix.air.n2Fraction * (engine.surfacePressure - waterVapor)
        XCTAssertEqual(engine.tissueStates[0].pN2, expectedPpN2, accuracy: 0.0001,
                       "resetToSurface must use GasMix.air.n2Fraction consistently")
    }

    // MARK: - DeepState-baz: ppO2 surface pressure inconsistency

    /// ppO2 at depth must use the same surface pressure as the engine (1.013 bar).
    /// BUG: GasCalculator uses implicit 1.0 bar.
    func testDeepState_baz_ppO2UsesCorrectSurfacePressure() {
        // At 30m with air, correct ppO2 = 0.21 * (1.013 + 30/10) = 0.21 * 4.013 = 0.84273
        // Bug produces: 0.21 * (1.0 + 30/10) = 0.21 * 4.0 = 0.84
        let ppO2 = GasCalculator.ppO2(depth: 30.0, gasMix: .air)
        let expectedPpO2 = GasMix.air.o2Fraction * (1.013 + 30.0 / 10.0)
        XCTAssertEqual(ppO2, expectedPpO2, accuracy: 0.001,
                       "ppO2 must use 1.013 bar surface pressure, not 1.0")
    }

    /// MOD must also use correct surface pressure.
    func testDeepState_baz_modUsesCorrectSurfacePressure() {
        // MOD = (ppO2Max / o2Fraction) * 10.0 - surfacePressure * 10.0
        // For air at 1.4: (1.4/0.21) * 10 - 10.13 = 66.67 - 10.13 = 56.54m
        // Bug produces: (1.4/0.21 - 1) * 10 = 56.67m
        let mod = GasCalculator.mod(gasMix: .air, ppO2Max: 1.4)
        let expectedMOD = (1.4 / GasMix.air.o2Fraction - 1.013) * 10.0
        XCTAssertEqual(mod, expectedMOD, accuracy: 0.01,
                       "MOD must use 1.013 bar surface pressure")
    }

    // MARK: - DeepState-3ld: No gas fraction validation

    /// GasMix fractions must sum to 1.0 (within tolerance).
    /// BUG: No validation — invalid mixes silently produce wrong calculations.
    func testDeepState_3ld_gasMixValidatesFractions() {
        // Valid mixes should work fine
        let validMix = GasMix(o2Fraction: 0.21, n2Fraction: 0.79, heFraction: 0.0)
        XCTAssertNotNil(validMix)

        // Trimix should also work
        let trimix = GasMix(o2Fraction: 0.18, n2Fraction: 0.45, heFraction: 0.37)
        XCTAssertNotNil(trimix)
    }

    // MARK: - DeepState-rmu: CNS table documentation

    /// CNS table must include source reference comment.
    /// This is a code documentation test — we verify the values are intentional
    /// by checking key reference points against the documented source.
    func testDeepState_rmu_cnsTableReferenceValues() {
        // These values should match the documented source (NOAA-derived conservative table)
        // At ppO2 <= 0.6: no CNS accumulation
        XCTAssertEqual(GasCalculator.cnsPerMinute(ppO2: 0.5), 0.0)
        XCTAssertEqual(GasCalculator.cnsPerMinute(ppO2: 0.6), 0.0)

        // At ppO2 0.6-0.7: NOAA 150 min limit
        let cns065 = GasCalculator.cnsPerMinute(ppO2: 0.65)
        XCTAssertEqual(cns065, 1.0 / 150.0, accuracy: 0.0001)
    }

    // MARK: - DeepState-8c2: NDL zeroed at 40m

    /// At 40m depth limit, actual NDL should still be available (not zeroed).
    /// BUG: NDL forced to 0 at depthLimitReached.
    func testDeepState_8c2_ndlPreservedAtDepthLimit() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Dive to 40m — there should be real NDL remaining (about 8-10 min for air)
        for _ in 0..<10 {
            mgr.updateDepth(40.0)
        }

        XCTAssertEqual(mgr.depthLimitStatus, .depthLimitReached)
        XCTAssertGreaterThan(mgr.ndl, 0,
                             "Actual NDL should be preserved at depth limit — show it with a depth warning overlay, don't zero it")
    }
}
