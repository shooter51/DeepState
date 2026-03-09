import XCTest
@testable import DiveCore

final class GasCalculatorTests: XCTestCase {

    func testMODAir() {
        let mod = GasCalculator.mod(gasMix: .air)
        // (1.4 / 0.21 - 1.013) * 10 = 56.54m
        XCTAssertEqual(mod, 56.54, accuracy: 0.1, "MOD for air at ppO2 1.4 should be ~56.5m")
    }

    func testMODEAN32() {
        let mod = GasCalculator.mod(gasMix: .ean32)
        // (1.4 / 0.32 - 1.013) * 10 = 33.62m
        XCTAssertEqual(mod, 33.62, accuracy: 0.1, "MOD for EAN32 at ppO2 1.4 should be ~33.6m")
    }

    func testMODEAN36() {
        let mod = GasCalculator.mod(gasMix: .ean36)
        // (1.4 / 0.36 - 1.013) * 10 = 28.76m
        XCTAssertEqual(mod, 28.76, accuracy: 0.1, "MOD for EAN36 at ppO2 1.4 should be ~28.8m")
    }

    func testPPO2AtDepth() {
        let pp = GasCalculator.ppO2(depth: 30.0, gasMix: .air)
        // 0.21 * (1.0 + 30/10) = 0.21 * 4.0 = 0.84
        XCTAssertEqual(pp, 0.84, accuracy: 0.01, "ppO2 for air at 30m should be ~0.84")
    }

    func testPPO2AtSurface() {
        let pp = GasCalculator.ppO2(depth: 0.0, gasMix: .air)
        // 0.21 * 1.0 = 0.21
        XCTAssertEqual(pp, 0.21, accuracy: 0.01, "ppO2 for air at surface should be ~0.21")
    }

    func testCNSIncreases() {
        let cns = GasCalculator.updateCNS(currentCNS: 0.0, ppO2: 1.4, timeInterval: 60.0)
        XCTAssertGreaterThan(cns, 0.0, "CNS should increase at ppO2 > 0.6")
    }

    func testCNSZeroBelowThreshold() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 0.5)
        XCTAssertEqual(rate, 0.0, "CNS rate should be 0 at ppO2 <= 0.6")
    }

    func testOTUCalculation() {
        let otu = GasCalculator.updateOTU(currentOTU: 0.0, ppO2: 1.4, timeInterval: 60.0)
        XCTAssertGreaterThan(otu, 0.0, "OTU should increase at ppO2 > 0.5")
    }

    func testOTUNoBelowThreshold() {
        let otu = GasCalculator.updateOTU(currentOTU: 5.0, ppO2: 0.4, timeInterval: 60.0)
        XCTAssertEqual(otu, 5.0, "OTU should not increase at ppO2 <= 0.5")
    }

    func testEADAir() {
        let ead = GasCalculator.ead(depth: 30.0, gasMix: .air)
        // (30 + 10) * 0.79 / 0.79 - 10 = 30
        XCTAssertEqual(ead, 30.0, accuracy: 0.1, "EAD for air at any depth should equal that depth")
    }

    func testEADNitrox() {
        let ead = GasCalculator.ead(depth: 30.0, gasMix: .ean32)
        // (30 + 10) * 0.68 / 0.79 - 10 = 24.43m
        XCTAssertLessThan(ead, 30.0, "EAD for EAN32 at 30m should be less than 30m")
        XCTAssertGreaterThan(ead, 20.0, "EAD for EAN32 at 30m should be reasonable")
    }

    // MARK: - CNS Per Minute for Every ppO2 Range Bracket

    func testCNSPerMinuteAt0_5() {
        // ppO2 <= 0.60 -> 0
        let rate = GasCalculator.cnsPerMinute(ppO2: 0.50)
        XCTAssertEqual(rate, 0.0, accuracy: 0.0001, "CNS rate at ppO2 0.50 should be 0")
    }

    func testCNSPerMinuteAt0_60() {
        // ppO2 0.60 falls into ...0.60 range (returns 0, boundary is inclusive)
        let rate = GasCalculator.cnsPerMinute(ppO2: 0.60)
        XCTAssertEqual(rate, 0.0, accuracy: 0.0001, "CNS rate at ppO2 0.60 should be 0 (boundary of ...0.60)")
    }

    func testCNSPerMinuteAt0_65() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 0.65)
        XCTAssertEqual(rate, 1.0 / 150.0, accuracy: 0.0001, "CNS rate at ppO2 0.65 should be 1/150")
    }

    func testCNSPerMinuteAt0_75() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 0.75)
        XCTAssertEqual(rate, 1.0 / 120.0, accuracy: 0.0001, "CNS rate at ppO2 0.75 should be 1/120")
    }

    func testCNSPerMinuteAt0_85() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 0.85)
        XCTAssertEqual(rate, 1.0 / 90.0, accuracy: 0.0001, "CNS rate at ppO2 0.85 should be 1/90")
    }

    func testCNSPerMinuteAt1_0() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 1.0)
        XCTAssertEqual(rate, 1.0 / 75.0, accuracy: 0.0001, "CNS rate at ppO2 1.0 should be 1/75")
    }

    func testCNSPerMinuteAt1_2() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 1.2)
        XCTAssertEqual(rate, 1.0 / 51.0, accuracy: 0.0001, "CNS rate at ppO2 1.2 should be 1/51")
    }

    func testCNSPerMinuteAt1_37() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 1.37)
        XCTAssertEqual(rate, 1.0 / 45.0, accuracy: 0.0001, "CNS rate at ppO2 1.37 should be 1/45")
    }

    func testCNSPerMinuteAt1_45() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 1.45)
        XCTAssertEqual(rate, 1.0 / 25.0, accuracy: 0.0001, "CNS rate at ppO2 1.45 should be 1/25")
    }

    func testCNSPerMinuteAt1_55() {
        let rate = GasCalculator.cnsPerMinute(ppO2: 1.55)
        XCTAssertEqual(rate, 1.0 / 12.0, accuracy: 0.0001, "CNS rate at ppO2 1.55 should be 1/12")
    }

    func testCNSPerMinuteAt1_7() {
        // ppO2 > 1.60 -> 1/5
        let rate = GasCalculator.cnsPerMinute(ppO2: 1.70)
        XCTAssertEqual(rate, 1.0 / 5.0, accuracy: 0.0001, "CNS rate at ppO2 1.70 should be 1/5")
    }

    // MARK: - EAD Edge Cases

    func testEADAtDepthZero() {
        let ead = GasCalculator.ead(depth: 0.0, gasMix: .air)
        // (0 + 10) * 0.79 / 0.79 - 10 = 0
        XCTAssertEqual(ead, 0.0, accuracy: 0.01, "EAD at depth 0 for air should be 0")
    }

    func testEADNitroxAtZero() {
        let ead = GasCalculator.ead(depth: 0.0, gasMix: .ean32)
        // (0 + 10) * 0.68 / 0.79 - 10 = -1.39m (less than 0 because less N2)
        XCTAssertLessThan(ead, 0.0, "EAD at depth 0 for nitrox should be negative (less N2)")
    }

    // MARK: - MOD with Custom ppO2Max

    func testMODWithPpO2Max1_6() {
        let mod = GasCalculator.mod(gasMix: .air, ppO2Max: 1.6)
        // (1.6 / 0.21 - 1.013) * 10 = 66.06m
        XCTAssertEqual(mod, 66.06, accuracy: 0.1, "MOD for air at ppO2 1.6 should be ~66.1m")
    }

    func testMODWithPpO2Max1_6EAN32() {
        let mod = GasCalculator.mod(gasMix: .ean32, ppO2Max: 1.6)
        // (1.6 / 0.32 - 1.013) * 10 = 39.87m
        XCTAssertEqual(mod, 39.87, accuracy: 0.1, "MOD for EAN32 at ppO2 1.6 should be ~39.9m")
    }

    func testMODWithPpO2Max1_2() {
        let mod = GasCalculator.mod(gasMix: .air, ppO2Max: 1.2)
        // (1.2 / 0.21 - 1.013) * 10 = 47.01m
        XCTAssertEqual(mod, 47.01, accuracy: 0.1, "MOD for air at ppO2 1.2 should be ~47.0m")
    }

    // MARK: - OTU Edge Cases

    func testOTUAtExactThreshold() {
        let otu = GasCalculator.updateOTU(currentOTU: 0.0, ppO2: 0.5, timeInterval: 60.0)
        XCTAssertEqual(otu, 0.0, "OTU should not increase at exactly ppO2 0.5")
    }

    func testOTUJustAboveThreshold() {
        let otu = GasCalculator.updateOTU(currentOTU: 0.0, ppO2: 0.51, timeInterval: 60.0)
        XCTAssertGreaterThan(otu, 0.0, "OTU should increase at ppO2 0.51")
    }

    // MARK: - CNS Update Accumulation

    func testCNSAccumulatesOverTime() {
        var cns = 0.0
        cns = GasCalculator.updateCNS(currentCNS: cns, ppO2: 1.4, timeInterval: 60.0)
        let firstUpdate = cns
        cns = GasCalculator.updateCNS(currentCNS: cns, ppO2: 1.4, timeInterval: 60.0)
        XCTAssertEqual(cns, firstUpdate * 2, accuracy: 0.01,
                       "CNS should accumulate linearly")
    }
}
