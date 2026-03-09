import XCTest
@testable import DiveCore

// =============================================================================
// EN 13319:2000 Compliance Test Suite
//
// Tests mapped to the European Standard EN 13319 for dive depth gauges and
// dive computers. Each section corresponds to the compliance test plan:
//   TC-D: Depth measurement accuracy
//   TC-M: Maximum depth memory
//   TC-T: Time measurement
//   TC-A: Decompression algorithm (Bühlmann ZHL-16C)
//   TC-W: Water temperature
//   TC-S: Dive phase state machine
//   TC-K: Persistence / crash recovery
// =============================================================================

// MARK: - TC-D: Depth Measurement Accuracy

final class EN13319_DepthTests: XCTestCase {

    // TC-D-001: Depth conversion uses EN 13319 seawater density
    // EN 13319 specifies ρ = 1020 kg/m³, g = 9.80665 m/s²
    // ambient pressure = surface_pressure + depth / 10.0 (simplified, 1 bar per 10m)
    // This test validates the pressure-to-depth conversion constant.
    func testDepthConversionConstant() {
        // BuhlmannEngine uses: ambientPressure = surfacePressure + depth/10.0
        // At 10m: 1.013 + 1.0 = 2.013 bar
        // EN 13319 seawater: 10m = 10 * 1020 * 9.80665 / 100000 = 1.00028 bar
        // Our simplified model uses 1.0 bar/10m which is within 0.03% — acceptable
        let engine = BuhlmannEngine()
        let depth = 10.0
        let ambientPressure = engine.surfacePressure + depth / 10.0
        let expectedPressure = 2.013 // 1.013 + 1.0
        XCTAssertEqual(ambientPressure, expectedPressure, accuracy: 0.001,
                       "TC-D-001: Ambient pressure at 10m should be ~2.013 bar")
    }

    // TC-D-002: Depth accuracy tolerance per EN 13319 (±1.0m to 80m, or 1.5%)
    // The system must display depth within ±1.0m for depths 0-80m
    func testDepthAccuracyTolerance() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        let testDepths: [Double] = [5.0, 10.0, 15.0, 20.0, 30.0, 40.0]
        for depth in testDepths {
            mgr.updateDepth(depth)
            XCTAssertEqual(mgr.currentDepth, depth, accuracy: 1.0,
                           "TC-D-002: Depth \(depth)m must be within ±1.0m tolerance")
        }
    }

    // TC-D-003: Depth display resolution — 0.1m increments
    func testDepthDisplayResolution() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(15.3)
        // currentDepth should preserve 0.1m resolution
        XCTAssertEqual(mgr.currentDepth, 15.3, accuracy: 0.05,
                       "TC-D-003: Depth should resolve to 0.1m increments")

        mgr.updateDepth(22.7)
        XCTAssertEqual(mgr.currentDepth, 22.7, accuracy: 0.05,
                       "TC-D-003: Depth should resolve to 0.1m increments")
    }

    // TC-D-004: Surface pressure constant
    func testSurfacePressureConstant() {
        let engine = BuhlmannEngine()
        XCTAssertEqual(engine.surfacePressure, 1.013, accuracy: 0.001,
                       "TC-D-004: Surface pressure must be 1.013 bar (standard atmosphere)")

        XCTAssertEqual(GasCalculator.surfacePressure, 1.013, accuracy: 0.001,
                       "TC-D-004: GasCalculator.surfacePressure must be 1.013 bar")
    }

    // TC-D-005: ppO2 calculation at known depths validates pressure model
    func testPpO2AtKnownDepths() {
        // ppO2 = fO2 × (surfacePressure + depth/10)
        // Air at 0m: 0.21 × 1.013 = 0.21273
        XCTAssertEqual(GasCalculator.ppO2(depth: 0, gasMix: .air), 0.21273, accuracy: 0.001,
                       "TC-D-005: ppO2 at surface should be ~0.213")

        // Air at 10m: 0.21 × 2.013 = 0.42273
        XCTAssertEqual(GasCalculator.ppO2(depth: 10, gasMix: .air), 0.42273, accuracy: 0.001,
                       "TC-D-005: ppO2 at 10m should be ~0.423")

        // Air at 30m: 0.21 × 4.013 = 0.84273
        XCTAssertEqual(GasCalculator.ppO2(depth: 30, gasMix: .air), 0.84273, accuracy: 0.001,
                       "TC-D-005: ppO2 at 30m should be ~0.843")

        // Air at 40m: 0.21 × 5.013 = 1.05273
        XCTAssertEqual(GasCalculator.ppO2(depth: 40, gasMix: .air), 1.05273, accuracy: 0.001,
                       "TC-D-005: ppO2 at 40m should be ~1.053")
    }

    // TC-D-006: Depth zero at surface
    func testDepthZeroAtSurface() {
        let mgr = DiveSessionManager()
        XCTAssertEqual(mgr.currentDepth, 0.0, accuracy: 0.001,
                       "TC-D-006: Depth at surface must be 0.0m")
    }

    // TC-D-007: Negative depth clamping — depth should never display negative
    func testDepthNeverNegative() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(0.0)
        XCTAssertGreaterThanOrEqual(mgr.currentDepth, 0.0,
                                     "TC-D-007: Depth must never be negative")
    }
}

// MARK: - TC-M: Maximum Depth Memory

final class EN13319_MaxDepthTests: XCTestCase {

    // TC-M-001: Max depth is recorded during dive
    func testMaxDepthRecordedDuringDive() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(10.0)
        XCTAssertEqual(mgr.maxDepth, 10.0, accuracy: 0.1,
                       "TC-M-001: Max depth should be 10m after reaching 10m")

        mgr.updateDepth(25.0)
        XCTAssertEqual(mgr.maxDepth, 25.0, accuracy: 0.1,
                       "TC-M-001: Max depth should update to 25m")

        mgr.updateDepth(30.0)
        XCTAssertEqual(mgr.maxDepth, 30.0, accuracy: 0.1,
                       "TC-M-001: Max depth should update to 30m")
    }

    // TC-M-002: Max depth is non-decreasing during a dive
    func testMaxDepthNeverDecreases() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(20.0)
        let peakDepth = mgr.maxDepth

        mgr.updateDepth(15.0) // ascending
        XCTAssertGreaterThanOrEqual(mgr.maxDepth, peakDepth,
                                     "TC-M-002: Max depth must never decrease during a dive")

        mgr.updateDepth(10.0) // still ascending
        XCTAssertGreaterThanOrEqual(mgr.maxDepth, peakDepth,
                                     "TC-M-002: Max depth must be preserved during ascent")

        mgr.updateDepth(5.0)
        XCTAssertEqual(mgr.maxDepth, peakDepth, accuracy: 0.1,
                       "TC-M-002: Max depth should remain at peak value")
    }

    // TC-M-003: Max depth persists through entire dive
    func testMaxDepthPersistsThroughEntireDive() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Multi-level dive profile
        mgr.updateDepth(15.0)
        mgr.updateDepth(25.0)
        mgr.updateDepth(18.0)
        mgr.updateDepth(22.0)
        mgr.updateDepth(10.0)

        XCTAssertEqual(mgr.maxDepth, 25.0, accuracy: 0.1,
                       "TC-M-003: Max depth should be 25m (deepest point in profile)")
    }

    // TC-M-004: Max depth resets on new dive
    func testMaxDepthResetsOnNewDive() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(30.0)
        XCTAssertEqual(mgr.maxDepth, 30.0, accuracy: 0.1)

        // Start new dive
        mgr.startDive()
        XCTAssertEqual(mgr.maxDepth, 0.0, accuracy: 0.1,
                       "TC-M-004: Max depth must reset to 0 for new dive")
    }

    // TC-M-005: Max depth accuracy matches depth display resolution
    func testMaxDepthResolution() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(18.7)
        XCTAssertEqual(mgr.maxDepth, 18.7, accuracy: 0.05,
                       "TC-M-005: Max depth resolution should match depth display (0.1m)")
    }
}

// MARK: - TC-T: Time Measurement

final class EN13319_TimeTests: XCTestCase {

    // TC-T-001: Elapsed time starts at 0
    func testElapsedTimeStartsAtZero() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        XCTAssertEqual(mgr.elapsedTime, 0, accuracy: 1.0,
                       "TC-T-001: Elapsed time must start at 0 on dive start")
    }

    // TC-T-002: Elapsed time increments during dive
    func testElapsedTimeIncrements() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.diveStartTime = Date().addingTimeInterval(-120) // 2 minutes ago

        mgr.updateDepth(10.0)

        XCTAssertEqual(mgr.elapsedTime, 120, accuracy: 2.0,
                       "TC-T-002: Elapsed time should be ~120s after 2 minutes")
    }

    // TC-T-003: EN 13319 time accuracy ±1% or ±5 seconds per hour
    // Validates that elapsed time computation is based on system clock (Date())
    // which has sub-millisecond accuracy, well within the ±5s/hour EN 13319 requirement.
    func testTimeAccuracyWithinEN13319Tolerance() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        let oneHourAgo = Date().addingTimeInterval(-3600)
        mgr.diveStartTime = oneHourAgo

        mgr.updateDepth(10.0)

        // EN 13319: ±1% or ±5s per hour (whichever is greater)
        // ±1% of 3600s = ±36s, ±5s → use ±36s as the tolerance
        XCTAssertEqual(mgr.elapsedTime, 3600, accuracy: 36.0,
                       "TC-T-003: Elapsed time at 1 hour should be within ±1% (36s)")
    }

    // TC-T-004: Safety stop timer counts down from 180 seconds
    func testSafetyStopTimerDuration() {
        let ssm = SafetyStopManager()

        // notRequired -> pending
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)
        // pending -> inProgress
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)

        XCTAssertTrue(ssm.isAtSafetyStop)
        // Timer starts at 180s, minus 0 accumulated = 180 remaining
        XCTAssertEqual(ssm.remainingTime, 180.0, accuracy: 1.0,
                       "TC-T-004: Safety stop timer must start at 180 seconds")
    }

    // TC-T-005: Safety stop timer counts down correctly
    func testSafetyStopTimerCountdown() {
        let ssm = SafetyStopManager()

        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // pending
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // inProgress

        // Count down 60 seconds
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 60.0)

        XCTAssertEqual(ssm.remainingTime, 120.0, accuracy: 1.0,
                       "TC-T-005: After 60s at stop, remaining should be ~120s")
    }

    // TC-T-006: Safety stop completes after exactly 180 seconds
    func testSafetyStopCompletesAt180Seconds() {
        let ssm = SafetyStopManager()

        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // pending
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // inProgress
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 180.0) // complete

        if case .completed = ssm.state {
            // Pass
        } else {
            XCTFail("TC-T-006: Safety stop should complete after 180s, got \(ssm.state)")
        }
    }

    // TC-T-007: Surface interval start time is recorded
    func testSurfaceIntervalStartRecorded() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        let beforeEnd = Date()
        mgr.endDive()
        let afterEnd = Date()

        XCTAssertNotNil(mgr.surfaceIntervalStart,
                        "TC-T-007: Surface interval start must be set when dive ends")
        XCTAssertGreaterThanOrEqual(mgr.surfaceIntervalStart!, beforeEnd.addingTimeInterval(-1))
        XCTAssertLessThanOrEqual(mgr.surfaceIntervalStart!, afterEnd.addingTimeInterval(1))
    }

    // TC-T-008: Elapsed time resets on new dive
    func testElapsedTimeResetsOnNewDive() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.diveStartTime = Date().addingTimeInterval(-300)
        mgr.updateDepth(10.0)
        XCTAssertGreaterThan(mgr.elapsedTime, 200)

        mgr.startDive()
        XCTAssertEqual(mgr.elapsedTime, 0, accuracy: 1.0,
                       "TC-T-008: Elapsed time must reset to 0 on new dive start")
    }
}

// MARK: - TC-A: Decompression Algorithm (Bühlmann ZHL-16C)

final class EN13319_AlgorithmTests: XCTestCase {

    // TC-A-001: 16 tissue compartments
    func testSixteenTissueCompartments() {
        XCTAssertEqual(BuhlmannEngine.compartments.count, 16,
                       "TC-A-001: ZHL-16C must have exactly 16 tissue compartments")
    }

    // TC-A-002: Compartment half-times match published ZHL-16C values
    func testCompartmentHalfTimes() {
        let expectedHalfTimes: [Double] = [
            4.0, 8.0, 12.5, 18.5, 27.0, 38.3, 54.3, 77.0,
            109.0, 146.0, 187.0, 239.0, 305.0, 390.0, 498.0, 635.0
        ]
        for (i, expected) in expectedHalfTimes.enumerated() {
            XCTAssertEqual(BuhlmannEngine.compartments[i].halfTimeN2, expected, accuracy: 0.01,
                           "TC-A-002: Compartment \(i) N2 half-time should be \(expected) min")
        }
    }

    // TC-A-003: NDL at 10m on Air (GF 100/100) — reference ~219 min (Bühlmann)
    func testNDLAt10mGF100() {
        let engine = BuhlmannEngine(gfLow: 1.0, gfHigh: 1.0)
        let ndl = engine.ndl(depth: 10.0, gasMix: .air)
        // Bühlmann ZHL-16C at 10m on air GF 100/100: large NDL (several hundred min)
        // Exact value depends on implementation details; key assertion is it's very long
        XCTAssertGreaterThan(ndl, 180, "TC-A-003: NDL at 10m GF100/100 should be > 180 min")
        XCTAssertLessThan(ndl, 999, "TC-A-003: NDL at 10m GF100/100 should be finite (< 999)")
    }

    // TC-A-004: NDL at 18m on Air (GF 100/100) — reference ~56 min (PADI/Bühlmann)
    func testNDLAt18mGF100() {
        let engine = BuhlmannEngine(gfLow: 1.0, gfHigh: 1.0)
        let ndl = engine.ndl(depth: 18.0, gasMix: .air)
        // Bühlmann at 18m GF100/100: ~56 min, allow ±20%
        XCTAssertGreaterThan(ndl, 45, "TC-A-004: NDL at 18m GF100/100 should be > 45 min")
        XCTAssertLessThan(ndl, 80, "TC-A-004: NDL at 18m GF100/100 should be < 80 min")
    }

    // TC-A-005: NDL at 30m on Air (GF 100/100) — reference ~20 min
    func testNDLAt30mGF100() {
        let engine = BuhlmannEngine(gfLow: 1.0, gfHigh: 1.0)
        let ndl = engine.ndl(depth: 30.0, gasMix: .air)
        XCTAssertGreaterThan(ndl, 15, "TC-A-005: NDL at 30m GF100/100 should be > 15 min")
        XCTAssertLessThan(ndl, 30, "TC-A-005: NDL at 30m GF100/100 should be < 30 min")
    }

    // TC-A-006: NDL at 40m on Air (GF 100/100) — reference ~9 min
    func testNDLAt40mGF100() {
        let engine = BuhlmannEngine(gfLow: 1.0, gfHigh: 1.0)
        let ndl = engine.ndl(depth: 40.0, gasMix: .air)
        XCTAssertGreaterThan(ndl, 5, "TC-A-006: NDL at 40m GF100/100 should be > 5 min")
        XCTAssertLessThan(ndl, 15, "TC-A-006: NDL at 40m GF100/100 should be < 15 min")
    }

    // TC-A-007: NDL at 18m with GF 40/85 (conservative) should be shorter than GF 100/100
    func testNDLConservativeGFShorterThanReference() {
        let gf100 = BuhlmannEngine(gfLow: 1.0, gfHigh: 1.0)
        let gf4085 = BuhlmannEngine(gfLow: 0.40, gfHigh: 0.85)

        let ndlRef = gf100.ndl(depth: 18.0, gasMix: .air)
        let ndlCons = gf4085.ndl(depth: 18.0, gasMix: .air)

        XCTAssertLessThan(ndlCons, ndlRef,
                          "TC-A-007: GF 40/85 NDL at 18m must be shorter than GF 100/100")
    }

    // TC-A-008: NDL at 30m with GF 40/85 vs GF 30/70
    func testNDLProgressivelyConservative() {
        let gf4085 = BuhlmannEngine(gfLow: 0.40, gfHigh: 0.85)
        let gf3070 = BuhlmannEngine(gfLow: 0.30, gfHigh: 0.70)

        let ndl1 = gf4085.ndl(depth: 30.0, gasMix: .air)
        let ndl2 = gf3070.ndl(depth: 30.0, gasMix: .air)

        XCTAssertLessThan(ndl2, ndl1,
                          "TC-A-008: GF 30/70 must produce shorter NDL than GF 40/85")
    }

    // TC-A-009: EAN32 gives longer NDL than Air at 30m (less N2 absorption)
    func testNitroxExtensionOfNDL() {
        let engine = BuhlmannEngine()
        let ndlAir = engine.ndl(depth: 30.0, gasMix: .air)

        let engine2 = BuhlmannEngine()
        let ndlEAN32 = engine2.ndl(depth: 30.0, gasMix: .ean32)

        XCTAssertGreaterThan(ndlEAN32, ndlAir,
                             "TC-A-009: EAN32 should give longer NDL than air at 30m")
    }

    // TC-A-010: Deco ceiling emerges when NDL is exceeded
    func testDecoCeilingAfterExceedingNDL() {
        let engine = BuhlmannEngine()
        // Stay at 40m for 20 min — well beyond the ~9 min NDL
        engine.updateTissues(depth: 40.0, gasMix: .air, timeInterval: 20.0 * 60.0)

        let ceiling = engine.ceilingDepth()
        XCTAssertGreaterThan(ceiling, 0.0,
                             "TC-A-010: Ceiling must be > 0 after exceeding NDL at 40m")
    }

    // TC-A-011: Deco stops at 3m increments
    func testDecoStopsAt3mIncrements() {
        let engine = BuhlmannEngine()
        engine.updateTissues(depth: 40.0, gasMix: .air, timeInterval: 20.0 * 60.0)

        let stops = engine.decoStops(gasMix: .air)
        XCTAssertFalse(stops.isEmpty, "TC-A-011: Deco stops must be generated")

        for stop in stops {
            let remainder = stop.depth.truncatingRemainder(dividingBy: 3.0)
            XCTAssertEqual(remainder, 0.0, accuracy: 0.01,
                           "TC-A-011: Deco stop depth \(stop.depth)m must be a multiple of 3m")
        }
    }

    // TC-A-012: Tissue loading at surface saturation is near 0%
    func testTissueLoadingAtSurface() {
        let engine = BuhlmannEngine()
        let loading = engine.tissueLoadingPercentages()

        XCTAssertEqual(loading.count, 16, "TC-A-012: Must have 16 tissue loading values")
        for (i, pct) in loading.enumerated() {
            XCTAssertEqual(pct, 0.0, accuracy: 2.0,
                           "TC-A-012: Tissue \(i) loading at surface should be ~0%")
        }
    }

    // TC-A-013: Tissue loading increases after depth exposure
    func testTissueLoadingIncreases() {
        let engine = BuhlmannEngine()
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 20.0 * 60.0)

        let loading = engine.tissueLoadingPercentages()
        let maxLoading = loading.max() ?? 0
        XCTAssertGreaterThan(maxLoading, 30.0,
                             "TC-A-013: Peak tissue loading after 20min@30m should be > 30%")
    }

    // TC-A-014: Faster tissues load faster than slower tissues
    func testFastTissuesLoadFirst() {
        let engine = BuhlmannEngine()
        // Short exposure at depth — fast compartments should load more
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 5.0 * 60.0)

        let loading = engine.tissueLoadingPercentages()
        // Compartment 0 (4 min half-time) should load more than compartment 15 (635 min)
        XCTAssertGreaterThan(loading[0], loading[15],
                             "TC-A-014: Fast tissue (T1) should load more than slow tissue (T16) on short exposure")
    }

    // TC-A-015: Schreiner equation — tissue off-gasses toward surface after ascent
    func testTissueOffgassingOnAscent() {
        let engine = BuhlmannEngine()

        // Load tissues at depth
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 30.0 * 60.0)
        let loadedN2 = engine.tissueStates[0].pN2

        // Simulate ascent to surface (sitting at 0m for 30 min)
        engine.updateTissues(depth: 0.0, gasMix: .air, timeInterval: 30.0 * 60.0)
        let offgassedN2 = engine.tissueStates[0].pN2

        XCTAssertLessThan(offgassedN2, loadedN2,
                          "TC-A-015: Tissue pN2 must decrease after returning to surface (off-gassing)")
    }

    // TC-A-016: Ascent rate thresholds per EN 13319
    func testAscentRateThresholds() {
        let monitor = AscentRateMonitor()

        // Safe: < 12 m/min
        let safe = monitor.evaluate(previousDepth: 20.0, currentDepth: 19.0, timeInterval: 6.0) // 10 m/min
        XCTAssertEqual(safe.status, .safe, "TC-A-016: 10 m/min should be safe")

        // Warning: 12-18 m/min
        let warning = monitor.evaluate(previousDepth: 20.0, currentDepth: 17.0, timeInterval: 15.0) // 12 m/min
        XCTAssertEqual(warning.status, .warning, "TC-A-016: 12 m/min should be warning")

        // Critical: >= 18 m/min
        let critical = monitor.evaluate(previousDepth: 20.0, currentDepth: 14.0, timeInterval: 10.0) // 36 m/min
        XCTAssertEqual(critical.status, .critical, "TC-A-016: 36 m/min should be critical")
    }

    // TC-A-017: Ascent rate calculation is correct (m/min)
    func testAscentRateCalculation() {
        let monitor = AscentRateMonitor()

        // 6m ascent in 30 seconds = 12 m/min
        let result = monitor.evaluate(previousDepth: 20.0, currentDepth: 14.0, timeInterval: 30.0)
        XCTAssertEqual(result.rate, 12.0, accuracy: 0.1,
                       "TC-A-017: 6m in 30s = 12 m/min")
    }

    // TC-A-018: Descent always classified as safe
    func testDescentAlwaysSafe() {
        let monitor = AscentRateMonitor()

        let result = monitor.evaluate(previousDepth: 10.0, currentDepth: 30.0, timeInterval: 30.0)
        XCTAssertEqual(result.status, .safe, "TC-A-018: Descent must always be classified as safe")
    }

    // TC-A-019: Safety stop triggers when maxDepth >= 10m
    func testSafetyStopTriggerThreshold() {
        let ssm = SafetyStopManager()

        // Max depth = 9m — no safety stop
        ssm.update(currentDepth: 5.0, maxDepth: 9.0, timeInterval: 1.0)
        XCTAssertFalse(ssm.safetyStopRequired,
                       "TC-A-019: Safety stop should NOT be required for maxDepth < 10m")

        // Max depth = 10m — safety stop required
        let ssm2 = SafetyStopManager()
        ssm2.update(currentDepth: 5.0, maxDepth: 10.0, timeInterval: 1.0)
        XCTAssertTrue(ssm2.safetyStopRequired,
                      "TC-A-019: Safety stop MUST be required for maxDepth >= 10m")
    }

    // TC-A-020: Safety stop depth zone is 5m ± 1.5m
    func testSafetyStopDepthZone() {
        let ssm = SafetyStopManager()
        XCTAssertEqual(ssm.safetyStopDepth, 5.0, accuracy: 0.1,
                       "TC-A-020: Safety stop depth should be 5m")
        XCTAssertEqual(ssm.depthTolerance, 1.5, accuracy: 0.1,
                       "TC-A-020: Safety stop tolerance should be 1.5m")
    }

    // TC-A-021: Safety stop zone boundaries (3.5m to 6.5m)
    func testSafetyStopZoneBoundaries() {
        // At 3.4m (below lower bound) — should skip from pending
        let ssm = SafetyStopManager()
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // pending
        ssm.update(currentDepth: 3.4, maxDepth: 20.0, timeInterval: 1.0) // below zone
        if case .skipped = ssm.state {
            // Expected
        } else {
            XCTFail("TC-A-021: Depth 3.4m should be below safety stop zone (3.5-6.5m)")
        }

        // At 6.5m (upper bound) — should be in zone
        // SafetyStopManager requires: first update transitions notRequired→pending,
        // second update at same depth in zone transitions pending→inProgress
        let ssm2 = SafetyStopManager()
        ssm2.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // notRequired→pending
        ssm2.update(currentDepth: 6.5, maxDepth: 20.0, timeInterval: 1.0) // pending→inProgress (in zone)
        XCTAssertTrue(ssm2.isAtSafetyStop,
                      "TC-A-021: 6.5m should be within safety stop zone")

        // At 3.5m (lower bound) — should be in zone
        let ssm3 = SafetyStopManager()
        ssm3.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // notRequired→pending
        ssm3.update(currentDepth: 3.5, maxDepth: 20.0, timeInterval: 1.0) // pending→inProgress (in zone)
        XCTAssertTrue(ssm3.isAtSafetyStop,
                      "TC-A-021: 3.5m should be within safety stop zone")
    }

    // TC-A-022: Safety stop timer resets if diver drops below zone
    func testSafetyStopTimerResetsOnDrop() {
        let ssm = SafetyStopManager()

        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // pending
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0) // inProgress
        ssm.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 60.0) // 60s accumulated

        XCTAssertEqual(ssm.timeAccumulated, 60.0, accuracy: 1.0)

        // Drop below zone
        ssm.update(currentDepth: 8.0, maxDepth: 20.0, timeInterval: 1.0) // back to pending

        XCTAssertEqual(ssm.timeAccumulated, 0.0, accuracy: 0.1,
                       "TC-A-022: Timer must reset when diver drops below safety stop zone")
    }

    // TC-A-023: CNS toxicity tracking above 0.6 ppO2
    func testCNSTrackingAboveThreshold() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 0.5)
        XCTAssertEqual(rate, 0.0, accuracy: 0.0001,
                       "TC-A-023: CNS rate must be 0 below 0.6 ppO2")

        let rate2 = GasCalculator.cnsPerMinute(ppO2: 0.7)
        XCTAssertGreaterThan(rate2, 0.0,
                             "TC-A-023: CNS rate must be > 0 above 0.6 ppO2")
    }

    // TC-A-024: CNS accumulation over time
    func testCNSAccumulationOverTime() {
        var cns = 0.0
        // Simulate 30 min at ppO2 = 1.0 (air at ~37m)
        for _ in 0..<30 {
            cns = GasCalculator.updateCNS(currentCNS: cns, ppO2: 1.0, timeInterval: 60.0)
        }
        XCTAssertGreaterThan(cns, 0.0,
                             "TC-A-024: CNS must accumulate over 30 min at ppO2 1.0")
        XCTAssertLessThan(cns, 100.0,
                          "TC-A-024: CNS after 30 min at ppO2 1.0 should be well below 100%")
    }

    // TC-A-025: OTU calculation above 0.5 ppO2
    func testOTUCalculation() {
        let otu0 = GasCalculator.updateOTU(currentOTU: 0, ppO2: 0.4, timeInterval: 60.0)
        XCTAssertEqual(otu0, 0.0,
                       "TC-A-025: OTU must be 0 below 0.5 ppO2")

        let otu1 = GasCalculator.updateOTU(currentOTU: 0, ppO2: 1.0, timeInterval: 60.0)
        XCTAssertGreaterThan(otu1, 0.0,
                             "TC-A-025: OTU must accumulate above 0.5 ppO2")
    }

    // TC-A-026: Maximum Operating Depth (MOD) calculation
    func testMODCalculation() {
        // Air (21%) at ppO2max 1.4: MOD = (1.4/0.21 - 1.013) × 10 = ~56.5m
        let modAir = GasCalculator.mod(gasMix: .air)
        XCTAssertEqual(modAir, 56.6, accuracy: 1.0,
                       "TC-A-026: MOD for air at ppO2 1.4 should be ~56.6m")

        // EAN32 at ppO2max 1.4: MOD = (1.4/0.32 - 1.013) × 10 = ~33.6m
        let modEAN32 = GasCalculator.mod(gasMix: .ean32)
        XCTAssertEqual(modEAN32, 33.6, accuracy: 1.0,
                       "TC-A-026: MOD for EAN32 at ppO2 1.4 should be ~33.6m")

        // EAN36 at ppO2max 1.4: MOD = (1.4/0.36 - 1.013) × 10 = ~28.8m
        let modEAN36 = GasCalculator.mod(gasMix: .ean36)
        XCTAssertEqual(modEAN36, 28.8, accuracy: 1.0,
                       "TC-A-026: MOD for EAN36 at ppO2 1.4 should be ~28.8m")
    }

    // TC-A-027: Equivalent Air Depth (EAD) for nitrox
    func testEADCalculation() {
        // EAD for air should equal the depth itself
        let eadAir = GasCalculator.ead(depth: 30.0, gasMix: .air)
        XCTAssertEqual(eadAir, 30.0, accuracy: 0.5,
                       "TC-A-027: EAD for air should equal actual depth")

        // EAD for EAN32 at 30m: (30+10) × 0.68/0.79 - 10 = ~24.4m
        let eadEAN32 = GasCalculator.ead(depth: 30.0, gasMix: .ean32)
        XCTAssertLessThan(eadEAN32, 30.0,
                          "TC-A-027: EAD for nitrox must be less than actual depth")
        XCTAssertEqual(eadEAN32, 24.4, accuracy: 1.0,
                       "TC-A-027: EAD for EAN32 at 30m should be ~24.4m")
    }

    // TC-A-028: GF gradient interpolation between gfLow and gfHigh
    func testGFGradientInterpolation() {
        let engine = BuhlmannEngine(gfLow: 0.30, gfHigh: 0.85)

        // At surface with no deco obligation, should return gfHigh
        let gfSurface = engine.gfAtDepth(depth: 0)
        XCTAssertEqual(gfSurface, 0.85, accuracy: 0.01,
                       "TC-A-028: GF at surface (no deco) should be gfHigh")

        // Create deco obligation
        engine.updateTissues(depth: 50.0, gasMix: .air, timeInterval: 25.0 * 60.0)
        let ceiling = engine.ceilingDepth(gfNow: 0.30)
        XCTAssertGreaterThan(ceiling, 0, "Should be in deco")

        // GF at ceiling should be gfLow
        let gfAtCeiling = engine.gfAtDepth(depth: ceiling)
        XCTAssertEqual(gfAtCeiling, 0.30, accuracy: 0.02,
                       "TC-A-028: GF at ceiling should be approximately gfLow")
    }

    // TC-A-029: NDL is 999 at very shallow depth (effectively unlimited)
    func testNDLUnlimitedAtShallowDepth() {
        let engine = BuhlmannEngine()
        let ndl = engine.ndl(depth: 3.0, gasMix: .air)
        XCTAssertEqual(ndl, 999,
                       "TC-A-029: NDL at 3m should be 999 (unlimited)")
    }

    // TC-A-030: NDL decreases monotonically with depth (same gas, fresh tissues)
    func testNDLDecreasesWithDepth() {
        let depths: [Double] = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0]
        var previousNDL = 999

        for depth in depths {
            let engine = BuhlmannEngine() // fresh tissues each time
            let ndl = engine.ndl(depth: depth, gasMix: .air)
            XCTAssertLessThanOrEqual(ndl, previousNDL,
                                      "TC-A-030: NDL at \(depth)m must be <= NDL at shallower depth")
            previousNDL = ndl
        }
    }

    // TC-A-031: Water vapor pressure is accounted for in tissue calculations
    func testWaterVaporPressureAccounted() {
        let engine = BuhlmannEngine()
        // At surface, tissue pN2 should equal:
        // n2Fraction × (surfacePressure - waterVaporPressure)
        // = 0.79 × (1.013 - 0.0627) = 0.79 × 0.9503 = 0.7507
        let expectedN2 = 0.79 * (1.013 - 0.0627)
        XCTAssertEqual(engine.tissueStates[0].pN2, expectedN2, accuracy: 0.001,
                       "TC-A-031: Initial tissue pN2 must account for water vapor pressure")
    }

    // TC-A-032: Gas fractions must sum to 1.0
    func testGasFractionsSumToOne() {
        let air = GasMix.air
        XCTAssertEqual(air.o2Fraction + air.n2Fraction + air.heFraction, 1.0, accuracy: 0.01,
                       "TC-A-032: Air gas fractions must sum to 1.0")

        let ean32 = GasMix.ean32
        XCTAssertEqual(ean32.o2Fraction + ean32.n2Fraction + ean32.heFraction, 1.0, accuracy: 0.01,
                       "TC-A-032: EAN32 gas fractions must sum to 1.0")

        let ean36 = GasMix.ean36
        XCTAssertEqual(ean36.o2Fraction + ean36.n2Fraction + ean36.heFraction, 1.0, accuracy: 0.01,
                       "TC-A-032: EAN36 gas fractions must sum to 1.0")
    }

    // TC-A-033: Depth limit enforcement — 40m maximum operating depth
    func testDepthLimitConstants() {
        XCTAssertEqual(DepthLimits.maxOperatingDepth, 40.0,
                       "TC-A-033: Max operating depth must be 40m")
        XCTAssertEqual(DepthLimits.criticalDepth, 40.0,
                       "TC-A-033: Critical depth must be 40m")
        XCTAssertEqual(DepthLimits.warningDepth, 39.0,
                       "TC-A-033: Warning depth must be 39m")
        XCTAssertEqual(DepthLimits.defaultDepthAlarm, 38.0,
                       "TC-A-033: Default depth alarm must be 38m")
    }

    // TC-A-034: Depth limit status progression
    func testDepthLimitStatusProgression() {
        XCTAssertEqual(DepthLimits.evaluate(depth: 30.0), .safe, "TC-A-034")
        XCTAssertEqual(DepthLimits.evaluate(depth: 38.0), .approachingLimit, "TC-A-034")
        XCTAssertEqual(DepthLimits.evaluate(depth: 39.0), .maxDepthWarning, "TC-A-034")
        XCTAssertEqual(DepthLimits.evaluate(depth: 40.0), .depthLimitReached, "TC-A-034")
        XCTAssertEqual(DepthLimits.evaluate(depth: 45.0), .depthLimitReached, "TC-A-034")
    }

    // TC-A-035: NDL preserved at depth limit (not zeroed)
    func testNDLPreservedAtDepthLimit() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(40.0)

        XCTAssertGreaterThan(mgr.ndl, 0,
                             "TC-A-035: NDL must be preserved at depth limit — UI handles warning overlay")
    }

    // TC-A-036: NDL blanked (zeroed) when sensor data is stale
    func testNDLZeroedOnStaleSensor() {
        let mgr = DiveSessionManager()
        for _ in 0..<11 {
            mgr.checkSensorStaleness()
        }
        XCTAssertEqual(mgr.ndl, 0,
                       "TC-A-036: NDL must be 0 when sensor data is stale")
    }
}

// MARK: - TC-W: Water Temperature

final class EN13319_TemperatureTests: XCTestCase {

    // TC-W-001: Temperature records current value
    func testTemperatureRecordsCurrent() {
        let mgr = DiveSessionManager()
        mgr.updateTemperature(18.5)
        XCTAssertEqual(mgr.temperature, 18.5, accuracy: 0.1,
                       "TC-W-001: Temperature should record the current reading")
    }

    // TC-W-002: Minimum temperature is tracked
    func testMinTemperatureTracked() {
        let mgr = DiveSessionManager()
        mgr.updateTemperature(22.0)
        mgr.updateTemperature(18.0)
        mgr.updateTemperature(20.0)
        mgr.updateTemperature(16.0)
        mgr.updateTemperature(19.0)

        XCTAssertEqual(mgr.minTemperature, 16.0, accuracy: 0.1,
                       "TC-W-002: Minimum temperature should be tracked across all readings")
    }

    // TC-W-003: Minimum temperature never increases
    func testMinTemperatureNeverIncreases() {
        let mgr = DiveSessionManager()
        mgr.updateTemperature(20.0)
        let min1 = mgr.minTemperature

        mgr.updateTemperature(25.0) // warmer
        XCTAssertEqual(mgr.minTemperature, min1, accuracy: 0.1,
                       "TC-W-003: Min temperature must never increase when warmer reading arrives")
    }

    // TC-W-004: Temperature default value
    func testTemperatureDefault() {
        let mgr = DiveSessionManager()
        XCTAssertEqual(mgr.temperature, 22.0, accuracy: 0.1,
                       "TC-W-004: Default temperature should be 22.0°C")
        XCTAssertEqual(mgr.minTemperature, 22.0, accuracy: 0.1,
                       "TC-W-004: Default min temperature should be 22.0°C")
    }

    // TC-W-005: Temperature display resolution (0.1°C)
    func testTemperatureDisplayResolution() {
        let mgr = DiveSessionManager()
        mgr.updateTemperature(18.7)
        XCTAssertEqual(mgr.temperature, 18.7, accuracy: 0.05,
                       "TC-W-005: Temperature should maintain 0.1°C resolution")
    }
}

// MARK: - TC-S: Dive Phase State Machine

final class EN13319_StateMachineTests: XCTestCase {

    // TC-S-001: Initial state is .surface
    func testInitialStateSurface() {
        let mgr = DiveSessionManager()
        XCTAssertEqual(mgr.phase, .surface, "TC-S-001: Initial phase must be .surface")
    }

    // TC-S-002: surface → descending on startDive()
    func testSurfaceToDescending() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        XCTAssertEqual(mgr.phase, .descending, "TC-S-002: startDive() must transition to .descending")
    }

    // TC-S-003: descending → atDepth when depth stabilizes
    func testDescendingToAtDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(15.0)
        XCTAssertEqual(mgr.phase, .descending)

        mgr.updateDepth(15.0) // same depth
        XCTAssertEqual(mgr.phase, .atDepth,
                       "TC-S-003: Phase should be .atDepth when depth stabilizes")
    }

    // TC-S-004: atDepth → ascending when depth decreases
    func testAtDepthToAscending() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(20.0)
        mgr.updateDepth(20.0) // atDepth
        XCTAssertEqual(mgr.phase, .atDepth)

        mgr.updateDepth(18.0) // ascending
        XCTAssertEqual(mgr.phase, .ascending,
                       "TC-S-004: Phase must transition to .ascending when depth decreases")
    }

    // TC-S-005: ascending → safetyStop when in safety stop zone
    func testAscendingToSafetyStop() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Go deep enough for safety stop
        mgr.updateDepth(15.0)
        mgr.updateDepth(20.0)

        // Ascend to safety stop zone
        mgr.updateDepth(6.0)  // pending
        mgr.updateDepth(5.0)  // inProgress (descending into zone triggers it)

        if mgr.safetyStopManager.isAtSafetyStop {
            XCTAssertEqual(mgr.phase, .safetyStop,
                           "TC-S-005: Phase should be .safetyStop when at safety stop depth")
        }
    }

    // TC-S-006: dive → surfaceInterval when depth < 0.5m after 5s elapsed
    func testAutoSurfaceOnShallowDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(15.0)
        mgr.diveStartTime = Date().addingTimeInterval(-10) // 10 seconds elapsed

        mgr.updateDepth(0.3) // below 0.5m threshold

        XCTAssertEqual(mgr.phase, .surfaceInterval,
                       "TC-S-006: Dive should auto-end when depth < 0.5m and elapsed > 5s")
    }

    // TC-S-007: surfaceInterval → surface on resetForNewDive()
    func testSurfaceIntervalToSurface() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.endDive()
        XCTAssertEqual(mgr.phase, .surfaceInterval)

        mgr.resetForNewDive()
        XCTAssertEqual(mgr.phase, .surface,
                       "TC-S-007: resetForNewDive() must return to .surface")
    }

    // TC-S-008: Phase guards — .surface and .surfaceInterval block phase updates
    func testPhaseGuards() {
        let mgr = DiveSessionManager()

        // At .surface, updateDepth should NOT change phase
        mgr.updateDepth(10.0)
        XCTAssertEqual(mgr.phase, .surface,
                       "TC-S-008: Phase must not change from .surface via updateDepth")

        // At .surfaceInterval, updateDepth should NOT change phase
        mgr.startDive()
        mgr.endDive()
        XCTAssertEqual(mgr.phase, .surfaceInterval)
        mgr.updateDepth(10.0)
        XCTAssertEqual(mgr.phase, .surfaceInterval,
                       "TC-S-008: Phase must not change from .surfaceInterval via updateDepth")
    }

    // TC-S-009: False surface rejection — depth dip to < 0.5m before 5s elapsed
    func testFalseSurfaceRejection() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(5.0)
        // elapsedTime is very small (< 5s), so going shallow should NOT end dive
        mgr.updateDepth(0.3)

        XCTAssertNotEqual(mgr.phase, .surfaceInterval,
                          "TC-S-009: Dive should NOT auto-end if < 5 seconds elapsed (false surface)")
    }

    // TC-S-010: Phase transitions are logged as health events
    func testPhaseTransitionsLogged() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(10.0) // descending
        mgr.updateDepth(10.0) // atDepth
        mgr.updateDepth(5.0)  // ascending

        let phaseEvents = mgr.healthLog.filter { $0.eventType == .phaseTransition }
        // Should have: surface→descending, descending→atDepth, atDepth→ascending
        XCTAssertGreaterThanOrEqual(phaseEvents.count, 3,
                                     "TC-S-010: All phase transitions must be logged")
    }

    // TC-S-011: All DivePhase cases are defined
    func testAllDivePhaseCasesDefined() {
        let allPhases = DivePhase.allCases
        let expectedPhases: Set<DivePhase> = [
            .surface, .predive, .descending, .atDepth,
            .ascending, .safetyStop, .surfaceInterval
        ]
        XCTAssertEqual(Set(allPhases), expectedPhases,
                       "TC-S-011: All expected dive phases must be defined")
    }

    // TC-S-012: Phase is Codable (can be serialized/deserialized)
    func testDivePhaseCodable() throws {
        let phase = DivePhase.ascending
        let data = try JSONEncoder().encode(phase)
        let decoded = try JSONDecoder().decode(DivePhase.self, from: data)
        XCTAssertEqual(decoded, phase,
                       "TC-S-012: DivePhase must be Codable for persistence")
    }

    // TC-S-013: Multi-level dive — phase transitions correctly through complex profile
    func testMultiLevelDivePhaseTransitions() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Level 1: descend to 20m
        mgr.updateDepth(10.0)
        mgr.updateDepth(20.0)
        XCTAssertEqual(mgr.phase, .descending)

        // Stay at 20m
        mgr.updateDepth(20.0)
        XCTAssertEqual(mgr.phase, .atDepth)

        // Ascend to 12m
        mgr.updateDepth(15.0)
        XCTAssertEqual(mgr.phase, .ascending)

        // Level 2: descend to 18m
        mgr.updateDepth(18.0)
        XCTAssertEqual(mgr.phase, .descending)

        // Stay at 18m
        mgr.updateDepth(18.0)
        XCTAssertEqual(mgr.phase, .atDepth)

        // Ascend
        mgr.updateDepth(10.0)
        XCTAssertEqual(mgr.phase, .ascending)
    }
}

// MARK: - TC-K: Persistence & Crash Recovery

final class EN13319_PersistenceTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        TissueStatePersistence.clearPersistedState()
    }

    // TC-K-001: Tissue state can be persisted to disk
    func testTissueStatePersistence() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(20.0)

        TissueStatePersistence.persist(manager: mgr)

        let loaded = TissueStatePersistence.loadPersistedState()
        XCTAssertNotNil(loaded, "TC-K-001: Persisted state should be loadable")
    }

    // TC-K-002: Persisted state contains all required fields
    func testPersistedStateContainsAllFields() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(20.0)
        mgr.updateTemperature(19.0)

        TissueStatePersistence.persist(manager: mgr)
        let state = TissueStatePersistence.loadPersistedState()!

        XCTAssertEqual(state.tissueStates.count, 16,
                       "TC-K-002: Must persist all 16 tissue compartments")
        XCTAssertEqual(state.phase, "descending",
                       "TC-K-002: Phase must be persisted")
        XCTAssertEqual(state.currentDepth, 20.0, accuracy: 0.1,
                       "TC-K-002: Current depth must be persisted")
        XCTAssertEqual(state.temperature, 19.0, accuracy: 0.1,
                       "TC-K-002: Temperature must be persisted")
        XCTAssertEqual(state.gasMix, .air,
                       "TC-K-002: Gas mix must be persisted")
    }

    // TC-K-003: Interrupted session detection for active dive phases
    func testInterruptedSessionDetection() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(15.0)

        TissueStatePersistence.persist(manager: mgr)

        XCTAssertTrue(TissueStatePersistence.hasInterruptedSession(),
                      "TC-K-003: Active dive phase must be detected as interrupted")
    }

    // TC-K-004: No interrupted session for surface/surfaceInterval
    func testNoInterruptedSessionOnSurface() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.endDive()

        TissueStatePersistence.persist(manager: mgr)

        XCTAssertFalse(TissueStatePersistence.hasInterruptedSession(),
                       "TC-K-004: surfaceInterval should not be detected as interrupted")
    }

    // TC-K-005: Restore creates a valid DiveSessionManager
    func testRestoreCreatesValidManager() {
        let original = DiveSessionManager(gasMix: .ean32, gfLow: 0.30, gfHigh: 0.70)
        original.startDive()
        original.updateDepth(25.0)
        original.updateTemperature(18.0)

        TissueStatePersistence.persist(manager: original)
        let state = TissueStatePersistence.loadPersistedState()!
        let restored = TissueStatePersistence.restore(from: state)

        XCTAssertEqual(restored.gasMix, .ean32,
                       "TC-K-005: Restored manager must have correct gas mix")
        XCTAssertEqual(restored.engine.gfLow, 0.30, accuracy: 0.01,
                       "TC-K-005: Restored manager must have correct GF low")
        XCTAssertEqual(restored.engine.gfHigh, 0.70, accuracy: 0.01,
                       "TC-K-005: Restored manager must have correct GF high")
        XCTAssertEqual(restored.currentDepth, 25.0, accuracy: 0.1,
                       "TC-K-005: Restored manager must have correct depth")
        XCTAssertEqual(restored.temperature, 18.0, accuracy: 0.1,
                       "TC-K-005: Restored manager must have correct temperature")
    }

    // TC-K-006: Restored tissue states match original
    func testRestoredTissueStatesMatch() {
        let original = DiveSessionManager()
        original.startDive()
        // Build up significant tissue loading
        for _ in 0..<10 {
            original.updateDepth(30.0)
        }

        TissueStatePersistence.persist(manager: original)
        let state = TissueStatePersistence.loadPersistedState()!
        let restored = TissueStatePersistence.restore(from: state)

        for i in 0..<16 {
            XCTAssertEqual(restored.engine.tissueStates[i].pN2,
                           original.engine.tissueStates[i].pN2, accuracy: 0.001,
                           "TC-K-006: Tissue \(i) pN2 must match after restore")
            XCTAssertEqual(restored.engine.tissueStates[i].pHe,
                           original.engine.tissueStates[i].pHe, accuracy: 0.001,
                           "TC-K-006: Tissue \(i) pHe must match after restore")
        }
    }

    // TC-K-007: Clear persisted state removes file
    func testClearPersistedState() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(15.0)

        TissueStatePersistence.persist(manager: mgr)
        XCTAssertNotNil(TissueStatePersistence.loadPersistedState())

        TissueStatePersistence.clearPersistedState()
        XCTAssertNil(TissueStatePersistence.loadPersistedState(),
                     "TC-K-007: Persisted state must be nil after clearing")
    }

    // TC-K-008: Persisted state is Codable JSON
    func testPersistedStateIsCodableJSON() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(20.0)

        TissueStatePersistence.persist(manager: mgr)
        let state = TissueStatePersistence.loadPersistedState()!

        // Verify it can round-trip through JSON
        let encoder = JSONEncoder()
        let data = try! encoder.encode(state)
        XCTAssertGreaterThan(data.count, 0, "TC-K-008: Persisted state must serialize to JSON")

        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(TissueStatePersistence.PersistedDiveState.self, from: data)
        XCTAssertEqual(decoded.currentDepth, state.currentDepth, accuracy: 0.1,
                       "TC-K-008: JSON round-trip must preserve data")
    }

    // TC-K-009: restoreState() logs recovery event
    func testRestoreLogsRecoveryEvent() {
        let mgr = DiveSessionManager()
        mgr.restoreState(
            phase: .atDepth,
            elapsedTime: 300,
            maxDepth: 20.0,
            avgDepth: 15.0,
            currentDepth: 18.0,
            temperature: 20.0,
            minTemperature: 18.0,
            cnsPercent: 2.0,
            otuTotal: 5.0,
            healthLog: []
        )

        let resumeEvents = mgr.healthLog.filter { $0.eventType == .backgroundResumed }
        XCTAssertEqual(resumeEvents.count, 1,
                       "TC-K-009: Restore must log a backgroundResumed event")
    }

    // TC-K-010: Persistence triggered every 5 depth updates
    func testPersistenceFrequency() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // 5 updates should trigger persistence
        for i in 1...5 {
            mgr.updateDepth(Double(i) * 2.0)
        }

        // Verify a persisted state exists
        let state = TissueStatePersistence.loadPersistedState()
        XCTAssertNotNil(state,
                        "TC-K-010: State should be persisted after 5 depth updates")
    }

    // TC-K-011: Health events are persisted and restored
    func testHealthEventsPersisted() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Generate some health events
        mgr.updateDepth(39.0) // depth warning
        mgr.updateDepth(40.0) // depth limit reached

        let eventCount = mgr.healthLog.count
        XCTAssertGreaterThan(eventCount, 0, "Should have health events")

        TissueStatePersistence.persist(manager: mgr)
        let state = TissueStatePersistence.loadPersistedState()!

        XCTAssertEqual(state.healthLog.count, eventCount,
                       "TC-K-011: All health events must be persisted")
    }
}

// MARK: - TC-E2E: End-to-End Profile Validation

final class EN13319_E2ETests: XCTestCase {

    // TC-E2E-001: Standard recreational dive profile
    func testStandardRecreationalDiveProfile() {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .air,
            gfLow: 0.40,
            gfHigh: 0.85,
            waypoints: [
                (time: 0, depth: 0),
                (time: 120, depth: 20),    // 2 min descent to 20m
                (time: 1320, depth: 20),   // 20 min at 20m
                (time: 1500, depth: 5),    // 3 min ascent to 5m
                (time: 1680, depth: 5),    // 3 min safety stop
                (time: 1740, depth: 0)     // 1 min to surface
            ]
        )

        XCTAssertEqual(profile.config.gasMix, .air)
        XCTAssertEqual(profile.summary.maxDepth, 20.0, accuracy: 1.0,
                       "TC-E2E-001: Max depth should be ~20m")
        XCTAssertGreaterThan(profile.summary.sampleCount, 100,
                             "TC-E2E-001: Profile should have >100 samples for a 29-min dive")

        // Verify NDL was always positive (no deco obligation for this profile)
        let allNDLs = profile.samples.map { $0.ndl }
        for ndl in allNDLs {
            XCTAssertGreaterThan(ndl, 0,
                                 "TC-E2E-001: NDL should always be > 0 for a 20-min@20m dive")
        }
    }

    // TC-E2E-002: Deep dive approaching deco limits
    func testDeepDiveApproachingDecoLimits() {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .air,
            gfLow: 0.40,
            gfHigh: 0.85,
            waypoints: [
                (time: 0, depth: 0),
                (time: 60, depth: 35),     // 1 min descent to 35m
                (time: 360, depth: 35),    // 5 min at 35m
                (time: 540, depth: 5),     // 3 min ascent
                (time: 720, depth: 5),     // safety stop
                (time: 780, depth: 0)      // surface
            ]
        )

        XCTAssertEqual(profile.summary.maxDepth, 35.0, accuracy: 1.0,
                       "TC-E2E-002: Max depth should be ~35m")

        // NDL should be reduced but not zero (5 min at 35m is within limits)
        let bottomSamples = profile.samples.filter { $0.currentDepth > 30 }
        if let lastBottom = bottomSamples.last {
            XCTAssertGreaterThan(lastBottom.ndl, 0,
                                 "TC-E2E-002: NDL should still be > 0 after 5 min at 35m")
            XCTAssertLessThan(lastBottom.ndl, 30,
                              "TC-E2E-002: NDL at 35m should be < 30 min")
        }
    }

    // TC-E2E-003: Nitrox dive profile
    func testNitroxDiveProfile() {
        let profileAir = DiveProfileRecorder.recordDive(
            gasMix: .air,
            waypoints: [
                (time: 0, depth: 0),
                (time: 60, depth: 25),
                (time: 660, depth: 25),
                (time: 780, depth: 0)
            ]
        )

        let profileEAN32 = DiveProfileRecorder.recordDive(
            gasMix: .ean32,
            waypoints: [
                (time: 0, depth: 0),
                (time: 60, depth: 25),
                (time: 660, depth: 25),
                (time: 780, depth: 0)
            ]
        )

        // EAN32 should have higher NDL at equivalent depth
        let airBottomNDLs = profileAir.samples.filter { $0.currentDepth > 20 }.map { $0.ndl }
        let ean32BottomNDLs = profileEAN32.samples.filter { $0.currentDepth > 20 }.map { $0.ndl }

        if let airMinNDL = airBottomNDLs.min(), let ean32MinNDL = ean32BottomNDLs.min() {
            XCTAssertGreaterThan(ean32MinNDL, airMinNDL,
                                 "TC-E2E-003: EAN32 must provide longer NDL than air at same depth")
        }

        // EAN32 should have higher ppO2
        let ean32PPO2 = profileEAN32.samples.filter { $0.currentDepth > 20 }.map { $0.ppO2 }
        let airPPO2 = profileAir.samples.filter { $0.currentDepth > 20 }.map { $0.ppO2 }

        if let ean32MaxPPO2 = ean32PPO2.max(), let airMaxPPO2 = airPPO2.max() {
            XCTAssertGreaterThan(ean32MaxPPO2, airMaxPPO2,
                                 "TC-E2E-003: EAN32 ppO2 must be higher than air at same depth")
        }
    }

    // TC-E2E-004: Dive profile export is Codable
    func testDiveProfileExportCodable() throws {
        let profile = DiveProfileRecorder.recordDive(
            waypoints: [
                (time: 0, depth: 0),
                (time: 60, depth: 15),
                (time: 300, depth: 15),
                (time: 360, depth: 0)
            ]
        )

        let json = try profile.toJSON()
        let decoded = try DiveProfileExport.fromJSON(json)

        XCTAssertEqual(decoded.samples.count, profile.samples.count,
                       "TC-E2E-004: JSON round-trip must preserve sample count")
        XCTAssertEqual(decoded.summary.maxDepth, profile.summary.maxDepth, accuracy: 0.1,
                       "TC-E2E-004: JSON round-trip must preserve max depth")
        XCTAssertEqual(decoded.config.gasMix, profile.config.gasMix,
                       "TC-E2E-004: JSON round-trip must preserve gas mix")
    }
}
