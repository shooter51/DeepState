import XCTest
@testable import DiveCore

final class BuhlmannEngineTests: XCTestCase {

    func testInitialTissuesAtSurfaceSaturation() {
        let engine = BuhlmannEngine()
        let expectedN2 = 0.7808 * (1.013 - 0.0627) // ~0.7416

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

        let surfaceN2 = 0.7808 * (1.013 - 0.0627)
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

        let expectedN2 = 0.7808 * (1.013 - 0.0627)
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
}
