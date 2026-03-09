import Foundation

public struct GasCalculator {

    /// Standard surface pressure in bar (sea level)
    public static let surfacePressure: Double = 1.013

    // MARK: - Maximum Operating Depth

    public static func mod(gasMix: GasMix, ppO2Max: Double = 1.4) -> Double {
        (ppO2Max / gasMix.o2Fraction - surfacePressure) * 10.0
    }

    // MARK: - Partial Pressure of O2

    public static func ppO2(depth: Double, gasMix: GasMix) -> Double {
        gasMix.o2Fraction * (surfacePressure + depth / 10.0)
    }

    // MARK: - CNS Toxicity
    //
    // CNS per-minute rates derived from NOAA Diving Manual single-exposure limits
    // with conservative interpolation for intermediate ppO2 ranges.
    // Source: NOAA Diving Program, NOAA Technical Memorandum; Shearwater CNS
    // Oxygen Clock implementation (shearwater.com/blogs/community).
    // Values at ppO2 > 1.1 are more conservative than NOAA baseline to provide
    // additional safety margin for recreational dive computer use.

    public static func cnsPerMinute(ppO2: Double) -> Double {
        switch ppO2 {
        case ...0.60:
            return 0.0
        case 0.60...0.70:
            return 1.0 / 150.0
        case 0.70...0.80:
            return 1.0 / 120.0
        case 0.80...0.90:
            return 1.0 / 90.0
        case 0.90...1.10:
            return 1.0 / 75.0
        case 1.10...1.35:
            return 1.0 / 51.0
        case 1.35...1.40:
            return 1.0 / 45.0
        case 1.40...1.50:
            return 1.0 / 25.0
        case 1.50...1.60:
            return 1.0 / 12.0
        default:
            return 1.0 / 5.0
        }
    }

    public static func updateCNS(currentCNS: Double, ppO2: Double, timeInterval: TimeInterval) -> Double {
        currentCNS + cnsPerMinute(ppO2: ppO2) * (timeInterval / 60.0) * 100.0
    }

    // MARK: - OTU (Oxygen Toxicity Units)

    public static func updateOTU(currentOTU: Double, ppO2: Double, timeInterval: TimeInterval) -> Double {
        guard ppO2 > 0.5 else { return currentOTU }
        let otuPerMin = pow((ppO2 - 0.5) / 0.5, 0.8333)
        return currentOTU + otuPerMin * (timeInterval / 60.0)
    }

    // MARK: - Equivalent Air Depth

    public static func ead(depth: Double, gasMix: GasMix) -> Double {
        (depth + 10.0) * gasMix.n2Fraction / 0.79 - 10.0
    }
}
