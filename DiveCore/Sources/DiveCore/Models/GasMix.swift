import Foundation

public struct GasMix: Codable, Sendable, Equatable {
    public let o2Fraction: Double
    public let n2Fraction: Double
    public let heFraction: Double

    public init(o2Fraction: Double, n2Fraction: Double, heFraction: Double) {
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
        precondition(o2Percent >= 21 && o2Percent <= 40, "O2 percent must be between 21 and 40")
        let o2 = Double(o2Percent) / 100.0
        return GasMix(o2Fraction: o2, n2Fraction: 1.0 - o2, heFraction: 0.0)
    }
}
