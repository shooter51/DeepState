import XCTest
@testable import DiveCore

final class GasMixTests: XCTestCase {

    // MARK: - Presets

    func testAirPreset() {
        let air = GasMix.air
        XCTAssertEqual(air.o2Fraction, 0.21, accuracy: 0.001)
        XCTAssertEqual(air.n2Fraction, 0.79, accuracy: 0.001)
        XCTAssertEqual(air.heFraction, 0.0, accuracy: 0.001)
    }

    func testEAN32Preset() {
        let ean32 = GasMix.ean32
        XCTAssertEqual(ean32.o2Fraction, 0.32, accuracy: 0.001)
        XCTAssertEqual(ean32.n2Fraction, 0.68, accuracy: 0.001)
        XCTAssertEqual(ean32.heFraction, 0.0, accuracy: 0.001)
    }

    func testEAN36Preset() {
        let ean36 = GasMix.ean36
        XCTAssertEqual(ean36.o2Fraction, 0.36, accuracy: 0.001)
        XCTAssertEqual(ean36.n2Fraction, 0.64, accuracy: 0.001)
        XCTAssertEqual(ean36.heFraction, 0.0, accuracy: 0.001)
    }

    // MARK: - Nitrox Factory

    func testNitrox32MatchesEAN32() {
        let nitrox32 = GasMix.nitrox(o2Percent: 32)
        XCTAssertEqual(nitrox32.o2Fraction, GasMix.ean32.o2Fraction, accuracy: 0.0001)
        XCTAssertEqual(nitrox32.n2Fraction, GasMix.ean32.n2Fraction, accuracy: 0.0001)
        XCTAssertEqual(nitrox32.heFraction, GasMix.ean32.heFraction, accuracy: 0.0001)
    }

    func testNitrox36MatchesEAN36() {
        let nitrox36 = GasMix.nitrox(o2Percent: 36)
        XCTAssertEqual(nitrox36.o2Fraction, GasMix.ean36.o2Fraction, accuracy: 0.0001)
        XCTAssertEqual(nitrox36.n2Fraction, GasMix.ean36.n2Fraction, accuracy: 0.0001)
        XCTAssertEqual(nitrox36.heFraction, GasMix.ean36.heFraction, accuracy: 0.0001)
    }

    func testNitrox21() {
        let nitrox21 = GasMix.nitrox(o2Percent: 21)
        XCTAssertEqual(nitrox21.o2Fraction, 0.21, accuracy: 0.001)
        XCTAssertEqual(nitrox21.n2Fraction, 0.79, accuracy: 0.001)
        XCTAssertEqual(nitrox21.heFraction, 0.0, accuracy: 0.001)
    }

    func testNitrox40() {
        let nitrox40 = GasMix.nitrox(o2Percent: 40)
        XCTAssertEqual(nitrox40.o2Fraction, 0.40, accuracy: 0.001)
        XCTAssertEqual(nitrox40.n2Fraction, 0.60, accuracy: 0.001)
        XCTAssertEqual(nitrox40.heFraction, 0.0, accuracy: 0.001)
    }

    func testNitroxFractionsSumToOne() {
        for percent in 21...40 {
            let mix = GasMix.nitrox(o2Percent: percent)
            let total = mix.o2Fraction + mix.n2Fraction + mix.heFraction
            XCTAssertEqual(total, 1.0, accuracy: 0.0001,
                           "Gas fractions for nitrox \(percent)% should sum to 1.0")
        }
    }

    // MARK: - isNitrox

    func testIsNitroxForEAN32() {
        XCTAssertTrue(GasMix.ean32.isNitrox, "EAN32 should be nitrox")
    }

    func testIsNitroxForEAN36() {
        XCTAssertTrue(GasMix.ean36.isNitrox, "EAN36 should be nitrox")
    }

    func testIsNitroxFalseForAir() {
        XCTAssertFalse(GasMix.air.isNitrox, "Air (21% O2) should not be nitrox")
    }

    func testIsNitroxFalseForTrimix() {
        let trimix = GasMix(o2Fraction: 0.21, n2Fraction: 0.35, heFraction: 0.44)
        XCTAssertFalse(trimix.isNitrox, "Trimix with helium should not be nitrox")
    }

    // MARK: - Equatable

    func testAirEqualsAir() {
        XCTAssertEqual(GasMix.air, GasMix.air)
    }

    func testAirNotEqualsEAN32() {
        XCTAssertNotEqual(GasMix.air, GasMix.ean32)
    }

    func testCustomMixEquality() {
        let a = GasMix(o2Fraction: 0.30, n2Fraction: 0.50, heFraction: 0.20)
        let b = GasMix(o2Fraction: 0.30, n2Fraction: 0.50, heFraction: 0.20)
        XCTAssertEqual(a, b, "Identical custom mixes should be equal")
    }

    func testCustomMixInequality() {
        let a = GasMix(o2Fraction: 0.30, n2Fraction: 0.50, heFraction: 0.20)
        let b = GasMix(o2Fraction: 0.30, n2Fraction: 0.51, heFraction: 0.19)
        XCTAssertNotEqual(a, b, "Different custom mixes should not be equal")
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original = GasMix.ean32
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        XCTAssertEqual(decoded, original, "Decoded GasMix should match original")
    }

    func testCodableRoundTripAir() throws {
        let original = GasMix.air
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        XCTAssertEqual(decoded, original, "Decoded air should match original")
    }

    func testCodableRoundTripTrimix() throws {
        let original = GasMix(o2Fraction: 0.21, n2Fraction: 0.35, heFraction: 0.44)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        XCTAssertEqual(decoded, original, "Decoded trimix should match original")
    }

    func testCodableJSON() throws {
        let mix = GasMix.ean32
        let data = try JSONEncoder().encode(mix)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        let o2 = try XCTUnwrap(json?["o2Fraction"] as? Double)
        let n2 = try XCTUnwrap(json?["n2Fraction"] as? Double)
        let he = try XCTUnwrap(json?["heFraction"] as? Double)
        XCTAssertEqual(o2, 0.32, accuracy: 0.001)
        XCTAssertEqual(n2, 0.68, accuracy: 0.001)
        XCTAssertEqual(he, 0.0, accuracy: 0.001)
    }

    // MARK: - Init

    func testCustomInit() {
        let mix = GasMix(o2Fraction: 0.50, n2Fraction: 0.25, heFraction: 0.25)
        XCTAssertEqual(mix.o2Fraction, 0.50, accuracy: 0.001)
        XCTAssertEqual(mix.n2Fraction, 0.25, accuracy: 0.001)
        XCTAssertEqual(mix.heFraction, 0.25, accuracy: 0.001)
    }
}
