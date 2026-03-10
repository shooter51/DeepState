import Foundation

public struct GasMix: Codable, Sendable, Equatable {
    public let o2Fraction: Double
    public let n2Fraction: Double
    public let heFraction: Double

    public init(o2Fraction: Double, n2Fraction: Double, heFraction: Double) {
        let sum = o2Fraction + n2Fraction + heFraction
        if abs(sum - 1.0) >= 0.01 {
            print("[DiveCore] Warning: Gas fractions should sum to 1.0 (got \(sum)). Proceeding with provided values.")
            assert(false, "Gas fractions must sum to 1.0 (got \(sum))")
        }
        self.o2Fraction = o2Fraction
        self.n2Fraction = n2Fraction
        self.heFraction = heFraction
    }

    // MARK: - Presets

    public static let air = GasMix(o2Fraction: 0.21, n2Fraction: 0.79, heFraction: 0.0)
    public static let ean32 = GasMix(o2Fraction: 0.32, n2Fraction: 0.68, heFraction: 0.0)
    public static let ean36 = GasMix(o2Fraction: 0.36, n2Fraction: 0.64, heFraction: 0.0)

    // MARK: - Computed Properties

    public var isNitrox: Bool {
        o2Fraction > 0.21 && heFraction == 0.0
    }

    // MARK: - Factory

    public static func nitrox(o2Percent: Int) -> GasMix {
        let clamped = min(max(o2Percent, 21), 40)
        if clamped != o2Percent {
            print("[DiveCore] Warning: o2Percent \(o2Percent) clamped to \(clamped) (valid range: 21-40)")
        }
        let o2 = Double(clamped) / 100.0
        return GasMix(o2Fraction: o2, n2Fraction: 1.0 - o2, heFraction: 0.0)
    }
}
