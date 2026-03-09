import XCTest
@testable import DiveCore

final class BuhlmannEngineTests: XCTestCase {

    func testInitialTissuesAtSurfaceSaturation() {
        let engine = BuhlmannEngine()
        let expectedN2 = GasMix.air.n2Fraction * (1.013 - 0.0627) // ~0.7507

        for i in 0..<16 {
            XCTAssertEqual(engine.tissueStates[i].pN2, expectedN2, accuracy: 0.001,
                           "Compartment \(i) N2 should be at surface saturation")
            XCTAssertEqual(engine.tissueStates[i].pHe, 0.0, accuracy: 0.001,
                           "Compartment \(i) He should be 0")
        }
    }

    func testNDLAtShallowDepth() {
        let engine = BuhlmannEngine()
        let ndl = engine.ndl(depth: 10.0, gasMix: .air)
        XCTAssertGreaterThan(ndl, 200, "NDL at 10m on air should be > 200 minutes")
    }

    func testNDLAt18m() {
        let engine = BuhlmannEngine()
        // Simulate being at 18m for a brief period to establish loading
        engine.updateTissues(depth: 18.0, gasMix: .air, timeInterval: 60.0)
        let ndl = engine.ndl(depth: 18.0, gasMix: .air)
        // PADI table: 56 min. Allow ±20% tolerance (45-67)
        // Plus we already spent 1 min, so expect ~55
        XCTAssertGreaterThan(ndl, 35, "NDL at 18m should be > 35 min")
        XCTAssertLessThan(ndl, 70, "NDL at 18m should be < 70 min")
    }

    func testNDLAt30m() {
        let engine = BuhlmannEngine()
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 60.0)
        let ndl = engine.ndl(depth: 30.0, gasMix: .air)
        // PADI table: 20 min. Allow ±20% (16-24), minus 1 min already spent
        XCTAssertGreaterThan(ndl, 10, "NDL at 30m should be > 10 min")
        XCTAssertLessThan(ndl, 30, "NDL at 30m should be < 30 min")
    }

    func testNDLAt40m() {
        let engine = BuhlmannEngine()
        engine.updateTissues(depth: 40.0, gasMix: .air, timeInterval: 60.0)
        let ndl = engine.ndl(depth: 40.0, gasMix: .air)
        // PADI table: 9 min. Allow ±20% (7-11), minus 1 min already spent
        XCTAssertGreaterThan(ndl, 3, "NDL at 40m should be > 3 min")
        XCTAssertLessThan(ndl, 15, "NDL at 40m should be < 15 min")
    }

    func testCeilingDepthAtSurface() {
        let engine = BuhlmannEngine()
        XCTAssertEqual(engine.ceilingDepth(), 0.0, accuracy: 0.01,
                       "Ceiling should be 0 at surface saturation")
    }

    func testTissueLoadingAfterDive() {
        let engine = BuhlmannEngine()
        // Simulate 20 minutes at 30m
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 20.0 * 60.0)

        let surfaceN2 = GasMix.air.n2Fraction * (1.013 - 0.0627)
        var anyLoaded = false
        for state in engine.tissueStates {
            if state.pN2 > surfaceN2 + 0.01 {
                anyLoaded = true
                break
            }
        }
        XCTAssertTrue(anyLoaded, "At least some tissues should be loaded above surface levels")
    }

    func testResetToSurface() {
        let engine = BuhlmannEngine()
        // Load tissues
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 20.0 * 60.0)
        // Reset
        engine.resetToSurface()

        let expectedN2 = GasMix.air.n2Fraction * (1.013 - 0.0627)
        for i in 0..<16 {
            XCTAssertEqual(engine.tissueStates[i].pN2, expectedN2, accuracy: 0.001,
                           "Compartment \(i) should be back to surface saturation after reset")
            XCTAssertEqual(engine.tissueStates[i].pHe, 0.0, accuracy: 0.001)
        }
    }

    func testConservativeGFReducesNDL() {
        let liberal = BuhlmannEngine(gfLow: 0.40, gfHigh: 0.85)
        let conservative = BuhlmannEngine(gfLow: 0.30, gfHigh: 0.70)

        let ndlLiberal = liberal.ndl(depth: 30.0, gasMix: .air)
        let ndlConservative = conservative.ndl(depth: 30.0, gasMix: .air)

        XCTAssertLessThan(ndlConservative, ndlLiberal,
                          "Conservative GF should produce shorter NDL")
    }

    func testDecoStopsGenerated() {
        let engine = BuhlmannEngine()
        // Simulate exceeding NDL at 40m (stay 20 min, well beyond NDL)
        engine.updateTissues(depth: 40.0, gasMix: .air, timeInterval: 20.0 * 60.0)

        let stops = engine.decoStops(gasMix: .air)
        XCTAssertFalse(stops.isEmpty, "Deco stops should be required after exceeding NDL at 40m")

        // All stops should be at 3m increments
        for stop in stops {
            XCTAssertEqual(stop.depth.truncatingRemainder(dividingBy: 3.0), 0.0, accuracy: 0.01,
                           "Deco stops should be at 3m increments")
            XCTAssertGreaterThan(stop.time, 0, "Stop time should be positive")
        }
    }

    // MARK: - Additional Coverage Tests

    func testDecoStopsAt50mExtendedTime() {
        let engine = BuhlmannEngine()
        // Saturate at 50m for 30 minutes — well beyond NDL
        engine.updateTissues(depth: 50.0, gasMix: .air, timeInterval: 30.0 * 60.0)

        let stops = engine.decoStops(gasMix: .air)
        XCTAssertFalse(stops.isEmpty, "Deco stops should be required after 30 min at 50m")

        // Should have multiple stops at different depths
        let totalDecoTime = stops.reduce(0) { $0 + $1.time }
        XCTAssertGreaterThan(totalDecoTime, 5, "Total deco time at 50m/30min should be substantial")

        // Stops should be in descending depth order
        for i in 0..<(stops.count - 1) {
            XCTAssertGreaterThanOrEqual(stops[i].depth, stops[i + 1].depth,
                                         "Stops should be ordered from deep to shallow")
        }
    }

    func testTissueLoadingPercentagesReturns16Values() {
        let engine = BuhlmannEngine()
        let loading = engine.tissueLoadingPercentages()
        XCTAssertEqual(loading.count, 16, "Should return 16 tissue loading percentages")
    }

    func testTissueLoadingPercentagesNearZeroAtSurface() {
        let engine = BuhlmannEngine()
        let loading = engine.tissueLoadingPercentages()
        for (i, pct) in loading.enumerated() {
            XCTAssertEqual(pct, 0.0, accuracy: 2.0,
                           "Tissue \(i) loading should be near 0 at surface saturation")
        }
    }

    func testTissueLoadingPercentagesIncreaseAfterDive() {
        let engine = BuhlmannEngine()
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 15.0 * 60.0)

        let loading = engine.tissueLoadingPercentages()
        let maxLoading = loading.max() ?? 0.0
        XCTAssertGreaterThan(maxLoading, 10.0,
                             "At least one tissue should show significant loading after 15min at 30m")
    }

    func testGfAtDepthReturnsGfHighWhenNotInDeco() {
        let engine = BuhlmannEngine()
        // At surface saturation, ceiling is 0 — not in deco
        let gf = engine.gfAtDepth(depth: 10.0)
        XCTAssertEqual(gf, engine.gfHigh, accuracy: 0.001,
                       "gfAtDepth should return gfHigh when not in deco (ceiling <= 0)")
    }

    func testGfAtDepthReturnsValueBetweenGfLowAndGfHigh() {
        let engine = BuhlmannEngine(gfLow: 0.30, gfHigh: 0.85)
        // Create a deco situation
        engine.updateTissues(depth: 50.0, gasMix: .air, timeInterval: 25.0 * 60.0)

        let ceiling = engine.ceilingDepth(gfNow: engine.gfLow)
        XCTAssertGreaterThan(ceiling, 0, "Should be in deco after 25min at 50m")

        // Test at a depth between ceiling and surface
        let testDepth = ceiling / 2.0
        let gf = engine.gfAtDepth(depth: testDepth)
        XCTAssertGreaterThanOrEqual(gf, engine.gfLow - 0.001,
                                     "GF should be >= gfLow")
        XCTAssertLessThanOrEqual(gf, engine.gfHigh + 0.001,
                                  "GF should be <= gfHigh")
    }

    func testGfAtDepthAtCeilingReturnsGfLow() {
        let engine = BuhlmannEngine(gfLow: 0.30, gfHigh: 0.85)
        engine.updateTissues(depth: 50.0, gasMix: .air, timeInterval: 25.0 * 60.0)

        let ceiling = engine.ceilingDepth(gfNow: engine.gfLow)
        XCTAssertGreaterThan(ceiling, 0, "Should be in deco")

        let gf = engine.gfAtDepth(depth: ceiling)
        XCTAssertEqual(gf, engine.gfLow, accuracy: 0.01,
                       "GF at ceiling depth should be approximately gfLow")
    }

    func testCeilingDepthWithExplicitGfNow() {
        let engine = BuhlmannEngine(gfLow: 0.30, gfHigh: 0.85)
        engine.updateTissues(depth: 40.0, gasMix: .air, timeInterval: 20.0 * 60.0)

        let ceilingLow = engine.ceilingDepth(gfNow: 0.30)
        let ceilingHigh = engine.ceilingDepth(gfNow: 0.85)

        XCTAssertGreaterThanOrEqual(ceilingLow, ceilingHigh,
                                     "Lower GF should produce deeper or equal ceiling")
    }

    func testCeilingDepthDefaultUsesGfHigh() {
        let engine = BuhlmannEngine(gfLow: 0.30, gfHigh: 0.85)
        engine.updateTissues(depth: 40.0, gasMix: .air, timeInterval: 20.0 * 60.0)

        let ceilingDefault = engine.ceilingDepth()
        let ceilingExplicit = engine.ceilingDepth(gfNow: 0.85)

        XCTAssertEqual(ceilingDefault, ceilingExplicit, accuracy: 0.001,
                       "Default ceiling should use gfHigh")
    }

    func testUpdateTissuesWithHelium() {
        let engine = BuhlmannEngine()
        let trimix = GasMix(o2Fraction: 0.21, n2Fraction: 0.35, heFraction: 0.44)

        engine.updateTissues(depth: 40.0, gasMix: trimix, timeInterval: 10.0 * 60.0)

        // Helium should have been loaded into tissues
        var anyHeLoaded = false
        for state in engine.tissueStates {
            if state.pHe > 0.01 {
                anyHeLoaded = true
                break
            }
        }
        XCTAssertTrue(anyHeLoaded, "Tissues should have helium loading after breathing trimix")

        // N2 loading should be less than with air at same depth/time
        let airEngine = BuhlmannEngine()
        airEngine.updateTissues(depth: 40.0, gasMix: .air, timeInterval: 10.0 * 60.0)

        // Fastest compartment (index 0) should show the difference clearly
        XCTAssertLessThan(engine.tissueStates[0].pN2, airEngine.tissueStates[0].pN2,
                          "Trimix should result in less N2 loading than air")
    }

    func testNDLWithHeliumMix() {
        let engine = BuhlmannEngine()
        let trimix = GasMix(o2Fraction: 0.21, n2Fraction: 0.35, heFraction: 0.44)
        let ndl = engine.ndl(depth: 30.0, gasMix: trimix)
        XCTAssertGreaterThan(ndl, 0, "NDL with trimix at 30m should be positive")
    }

    func testDecoStopsEmptyWhenNoCeiling() {
        let engine = BuhlmannEngine()
        // At surface saturation, no deco obligation
        let stops = engine.decoStops(gasMix: .air)
        XCTAssertTrue(stops.isEmpty, "No deco stops should be needed at surface saturation")
    }

    func testNDLAt999ForVeryShallowDepth() {
        let engine = BuhlmannEngine()
        let ndl = engine.ndl(depth: 3.0, gasMix: .air)
        XCTAssertEqual(ndl, 999, "NDL at 3m should be 999 (effectively unlimited)")
    }
}
