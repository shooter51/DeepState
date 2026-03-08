import Foundation

public struct TissueCompartment: Sendable {
    public let halfTimeN2: Double
    public let halfTimeHe: Double
    public let aN2: Double
    public let bN2: Double
    public let aHe: Double
    public let bHe: Double

    public init(halfTimeN2: Double, halfTimeHe: Double, aN2: Double, bN2: Double, aHe: Double, bHe: Double) {
        self.halfTimeN2 = halfTimeN2
        self.halfTimeHe = halfTimeHe
        self.aN2 = aN2
        self.bN2 = bN2
        self.aHe = aHe
        self.bHe = bHe
    }
}

public struct TissueState: Sendable {
    public var pN2: Double
    public var pHe: Double

    public var pInert: Double {
        pN2 + pHe
    }

    public init(pN2: Double, pHe: Double) {
        self.pN2 = pN2
        self.pHe = pHe
    }
}

public class BuhlmannEngine {
    private static let ln2: Double = 0.693147180559945
    private static let waterVaporPressure: Double = 0.0627

    public static let compartments: [TissueCompartment] = [
        TissueCompartment(halfTimeN2: 4.0, halfTimeHe: 1.51, aN2: 1.2599, bN2: 0.5050, aHe: 1.7424, bHe: 0.4245),
        TissueCompartment(halfTimeN2: 8.0, halfTimeHe: 3.02, aN2: 1.0000, bN2: 0.6514, aHe: 1.3830, bHe: 0.5747),
        TissueCompartment(halfTimeN2: 12.5, halfTimeHe: 4.72, aN2: 0.8618, bN2: 0.7222, aHe: 1.1919, bHe: 0.6527),
        TissueCompartment(halfTimeN2: 18.5, halfTimeHe: 6.99, aN2: 0.7562, bN2: 0.7825, aHe: 1.0458, bHe: 0.7223),
        TissueCompartment(halfTimeN2: 27.0, halfTimeHe: 10.21, aN2: 0.6200, bN2: 0.8126, aHe: 0.9220, bHe: 0.7582),
        TissueCompartment(halfTimeN2: 38.3, halfTimeHe: 14.48, aN2: 0.5043, bN2: 0.8434, aHe: 0.8205, bHe: 0.7957),
        TissueCompartment(halfTimeN2: 54.3, halfTimeHe: 20.53, aN2: 0.4410, bN2: 0.8693, aHe: 0.7305, bHe: 0.8279),
        TissueCompartment(halfTimeN2: 77.0, halfTimeHe: 29.11, aN2: 0.4000, bN2: 0.8910, aHe: 0.6502, bHe: 0.8553),
        TissueCompartment(halfTimeN2: 109.0, halfTimeHe: 41.20, aN2: 0.3750, bN2: 0.9092, aHe: 0.5950, bHe: 0.8757),
        TissueCompartment(halfTimeN2: 146.0, halfTimeHe: 55.19, aN2: 0.3500, bN2: 0.9222, aHe: 0.5545, bHe: 0.8903),
        TissueCompartment(halfTimeN2: 187.0, halfTimeHe: 70.69, aN2: 0.3295, bN2: 0.9319, aHe: 0.5333, bHe: 0.8997),
        TissueCompartment(halfTimeN2: 239.0, halfTimeHe: 90.34, aN2: 0.3065, bN2: 0.9403, aHe: 0.5189, bHe: 0.9073),
        TissueCompartment(halfTimeN2: 305.0, halfTimeHe: 115.29, aN2: 0.2835, bN2: 0.9477, aHe: 0.5181, bHe: 0.9122),
        TissueCompartment(halfTimeN2: 390.0, halfTimeHe: 147.42, aN2: 0.2610, bN2: 0.9544, aHe: 0.5176, bHe: 0.9171),
        TissueCompartment(halfTimeN2: 498.0, halfTimeHe: 188.24, aN2: 0.2480, bN2: 0.9602, aHe: 0.5172, bHe: 0.9217),
        TissueCompartment(halfTimeN2: 635.0, halfTimeHe: 240.03, aN2: 0.2327, bN2: 0.9653, aHe: 0.5119, bHe: 0.9267),
    ]

    public var tissueStates: [TissueState]
    public var gfLow: Double
    public var gfHigh: Double
    public var surfacePressure: Double

    public init(gfLow: Double = 0.40, gfHigh: Double = 0.85) {
        self.gfLow = gfLow
        self.gfHigh = gfHigh
        self.surfacePressure = 1.013

        let surfaceN2PP = 0.7808 * (surfacePressure - BuhlmannEngine.waterVaporPressure)
        self.tissueStates = Array(repeating: TissueState(pN2: surfaceN2PP, pHe: 0.0), count: 16)
    }

    // MARK: - Tissue Update

    public func updateTissues(depth: Double, gasMix: GasMix, timeInterval: TimeInterval) {
        let ambientPressure = surfacePressure + depth / 10.0
        let timeMinutes = timeInterval / 60.0

        let inspiredN2 = (ambientPressure - BuhlmannEngine.waterVaporPressure) * gasMix.n2Fraction
        let inspiredHe = (ambientPressure - BuhlmannEngine.waterVaporPressure) * gasMix.heFraction

        for i in 0..<16 {
            let compartment = BuhlmannEngine.compartments[i]

            let kN2 = BuhlmannEngine.ln2 / compartment.halfTimeN2
            let newN2 = inspiredN2 + (tissueStates[i].pN2 - inspiredN2) * exp(-kN2 * timeMinutes)

            let kHe = BuhlmannEngine.ln2 / compartment.halfTimeHe
            let newHe = inspiredHe + (tissueStates[i].pHe - inspiredHe) * exp(-kHe * timeMinutes)

            tissueStates[i] = TissueState(pN2: newN2, pHe: newHe)
        }
    }

    // MARK: - NDL Calculation

    public func ndl(depth: Double, gasMix: GasMix) -> Int {
        // Work on a copy of tissue states
        var simStates = tissueStates

        let ambientPressure = surfacePressure + depth / 10.0
        let inspiredN2 = (ambientPressure - BuhlmannEngine.waterVaporPressure) * gasMix.n2Fraction
        let inspiredHe = (ambientPressure - BuhlmannEngine.waterVaporPressure) * gasMix.heFraction

        for minute in 0..<999 {
            // Check if any compartment exceeds M-value at current GF high
            for i in 0..<16 {
                let comp = BuhlmannEngine.compartments[i]
                let pInert = simStates[i].pInert

                // Weighted a and b values for mixed gas
                let a: Double
                let b: Double
                if pInert > 0 {
                    a = (simStates[i].pN2 * comp.aN2 + simStates[i].pHe * comp.aHe) / pInert
                    b = (simStates[i].pN2 * comp.bN2 + simStates[i].pHe * comp.bHe) / pInert
                } else {
                    a = comp.aN2
                    b = comp.bN2
                }

                // Tolerated ambient pressure with GF high applied
                let toleratedAmbient = (pInert - a * gfHigh) / (gfHigh / b - gfHigh + 1.0)

                if toleratedAmbient > surfacePressure {
                    return minute
                }
            }

            // Simulate one more minute at depth
            for i in 0..<16 {
                let comp = BuhlmannEngine.compartments[i]
                let kN2 = BuhlmannEngine.ln2 / comp.halfTimeN2
                let kHe = BuhlmannEngine.ln2 / comp.halfTimeHe
                simStates[i] = TissueState(
                    pN2: inspiredN2 + (simStates[i].pN2 - inspiredN2) * exp(-kN2),
                    pHe: inspiredHe + (simStates[i].pHe - inspiredHe) * exp(-kHe)
                )
            }
        }

        return 999
    }

    // MARK: - Ceiling Depth

    public func ceilingDepth(gfNow: Double? = nil) -> Double {
        let gf = gfNow ?? gfHigh
        var maxCeiling: Double = 0.0

        for i in 0..<16 {
            let comp = BuhlmannEngine.compartments[i]
            let pInert = tissueStates[i].pInert

            let a: Double
            let b: Double
            if pInert > 0 {
                a = (tissueStates[i].pN2 * comp.aN2 + tissueStates[i].pHe * comp.aHe) / pInert
                b = (tissueStates[i].pN2 * comp.bN2 + tissueStates[i].pHe * comp.bHe) / pInert
            } else {
                a = comp.aN2
                b = comp.bN2
            }

            let toleratedAmbient = (pInert - a * gf) / (gf / b - gf + 1.0)
            let ceilingMeters = (toleratedAmbient - surfacePressure) * 10.0

            if ceilingMeters > maxCeiling {
                maxCeiling = ceilingMeters
            }
        }

        return max(0.0, maxCeiling)
    }

    // MARK: - GF at Depth

    public func gfAtDepth(depth: Double) -> Double {
        let currentCeiling = ceilingDepth(gfNow: gfLow)
        if currentCeiling <= 0 {
            return gfHigh
        }
        // Linear interpolation: gfLow at ceiling, gfHigh at surface
        let fraction = (currentCeiling - depth) / currentCeiling
        return gfLow + (gfHigh - gfLow) * max(0.0, min(1.0, fraction))
    }

    // MARK: - Deco Stops

    public func decoStops(gasMix: GasMix) -> [(depth: Double, time: Int)] {
        var simStates = tissueStates
        var stops: [(depth: Double, time: Int)] = []

        // Find first stop depth (round ceiling up to next 3m increment)
        let currentCeiling = ceilingDepth(gfNow: gfLow)
        if currentCeiling <= 0 {
            return []
        }

        var stopDepth = ceil(currentCeiling / 3.0) * 3.0

        while stopDepth >= 3.0 {
            var stopTime = 0
            let firstStopDepth = ceil(currentCeiling / 3.0) * 3.0

            // Simulate at stop depth until ceiling clears
            let nextStop = stopDepth - 3.0
            let nextStopPressure = nextStop > 0 ? surfacePressure + nextStop / 10.0 : surfacePressure

            let ambientPressure = surfacePressure + stopDepth / 10.0
            let inspiredN2 = (ambientPressure - BuhlmannEngine.waterVaporPressure) * gasMix.n2Fraction
            let inspiredHe = (ambientPressure - BuhlmannEngine.waterVaporPressure) * gasMix.heFraction

            var cleared = false
            while !cleared && stopTime < 999 {
                stopTime += 1
                for i in 0..<16 {
                    let comp = BuhlmannEngine.compartments[i]
                    let kN2 = BuhlmannEngine.ln2 / comp.halfTimeN2
                    let kHe = BuhlmannEngine.ln2 / comp.halfTimeHe
                    simStates[i] = TissueState(
                        pN2: inspiredN2 + (simStates[i].pN2 - inspiredN2) * exp(-kN2),
                        pHe: inspiredHe + (simStates[i].pHe - inspiredHe) * exp(-kHe)
                    )
                }

                // Check if we can ascend to next stop
                cleared = true
                for i in 0..<16 {
                    let comp = BuhlmannEngine.compartments[i]
                    let pInert = simStates[i].pInert
                    let a: Double
                    let b: Double
                    if pInert > 0 {
                        a = (simStates[i].pN2 * comp.aN2 + simStates[i].pHe * comp.aHe) / pInert
                        b = (simStates[i].pN2 * comp.bN2 + simStates[i].pHe * comp.bHe) / pInert
                    } else {
                        a = comp.aN2
                        b = comp.bN2
                    }
                    let nextGf: Double
                    if firstStopDepth > 0 {
                        nextGf = gfLow + (gfHigh - gfLow) * (1.0 - nextStop / firstStopDepth)
                    } else {
                        nextGf = gfHigh
                    }
                    let toleratedAmbient = (pInert - a * nextGf) / (nextGf / b - nextGf + 1.0)
                    if toleratedAmbient > nextStopPressure {
                        cleared = false
                        break
                    }
                }
            }

            if stopTime > 0 {
                stops.append((depth: stopDepth, time: stopTime))
            }
            stopDepth -= 3.0
        }

        return stops
    }

    // MARK: - Reset

    public func resetToSurface() {
        let surfaceN2PP = 0.7808 * (surfacePressure - BuhlmannEngine.waterVaporPressure)
        for i in 0..<16 {
            tissueStates[i] = TissueState(pN2: surfaceN2PP, pHe: 0.0)
        }
    }

    // MARK: - Tissue Loading Percentages

    public func tissueLoadingPercentages() -> [Double] {
        return (0..<16).map { i in
            let comp = BuhlmannEngine.compartments[i]
            let pInert = tissueStates[i].pInert

            let a: Double
            let b: Double
            if pInert > 0 {
                a = (tissueStates[i].pN2 * comp.aN2 + tissueStates[i].pHe * comp.aHe) / pInert
                b = (tissueStates[i].pN2 * comp.bN2 + tissueStates[i].pHe * comp.bHe) / pInert
            } else {
                a = comp.aN2
                b = comp.bN2
            }

            // M-value at surface
            let mValue = a + surfacePressure / b
            let surfaceN2PP = 0.7808 * (surfacePressure - BuhlmannEngine.waterVaporPressure)

            // Percentage: how far between surface saturation and M-value
            let loading = (pInert - surfaceN2PP) / (mValue - surfaceN2PP) * 100.0
            return max(0.0, loading)
        }
    }
}
