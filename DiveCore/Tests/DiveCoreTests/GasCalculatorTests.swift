import XCTest
@testable import DiveCore

final class GasCalculatorTests: XCTestCase {

    func testMODAir() {
        let mod = GasCalculator.mod(gasMix: .air)
        // (1.4 / 0.21 - 1) * 10 = 56.67m
        XCTAssertEqual(mod, 56.67, accuracy: 0.1, "MOD for air at ppO2 1.4 should be ~56.7m")
    }

    func testMODEAN32() {
        let mod = GasCalculator.mod(gasMix: .ean32)
        // (1.4 / 0.32 - 1) * 10 = 33.75m
        XCTAssertEqual(mod, 33.75, accuracy: 0.1, "MOD for EAN32 at ppO2 1.4 should be ~33.75m")
    }

    func testMODEAN36() {
        let mod = GasCalculator.mod(gasMix: .ean36)
        // (1.4 / 0.36 - 1) * 10 = 28.89m
        XCTAssertEqual(mod, 28.89, accuracy: 0.1, "MOD for EAN36 at ppO2 1.4 should be ~28.9m")
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
}
