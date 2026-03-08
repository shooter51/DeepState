import Foundation

public class DiveSessionManager {

    // MARK: - State

    public private(set) var phase: DivePhase = .surface
    public private(set) var currentDepth: Double = 0
    public private(set) var maxDepth: Double = 0
    public private(set) var averageDepth: Double = 0
    public private(set) var temperature: Double = 22.0
    public private(set) var minTemperature: Double = 22.0
    public private(set) var elapsedTime: TimeInterval = 0
    public private(set) var ndl: Int = 999
    public private(set) var ceilingDepth: Double = 0
    public private(set) var ascentRate: Double = 0
    public private(set) var ascentRateStatus: AscentRateMonitor.AscentRateStatus = .safe
    public private(set) var cnsPercent: Double = 0
    public private(set) var otuTotal: Double = 0
    public private(set) var ppO2: Double = 0.21
    public private(set) var surfaceIntervalStart: Date?

    public let gasMix: GasMix
    public let engine: BuhlmannEngine
    public let safetyStopManager: SafetyStopManager
    public let ascentRateMonitor: AscentRateMonitor

    private var diveStartTime: Date?
    private var lastUpdateTime: Date?
    private var lastDepth: Double = 0
    private var depthSamples: [(depth: Double, time: TimeInterval)] = []
    private let depthThreshold: Double = 0.5

    // MARK: - Init

    public init(gasMix: GasMix = .air, gfLow: Double = 0.40, gfHigh: Double = 0.85) {
        self.gasMix = gasMix
        self.engine = BuhlmannEngine(gfLow: gfLow, gfHigh: gfHigh)
        self.safetyStopManager = SafetyStopManager()
        self.ascentRateMonitor = AscentRateMonitor()
    }

    // MARK: - Dive Control

    public func startDive() {
        phase = .descending
        diveStartTime = Date()
        lastUpdateTime = Date()
        lastDepth = 0
        maxDepth = 0
        averageDepth = 0
        elapsedTime = 0
        cnsPercent = 0
        otuTotal = 0
        depthSamples = []
        safetyStopManager.reset()
        engine.resetToSurface()
    }

    public func endDive() {
        phase = .surfaceInterval
        surfaceIntervalStart = Date()
    }

    public func resetForNewDive() {
        phase = .surface
        surfaceIntervalStart = nil
    }

    // MARK: - Sensor Updates

    public func updateDepth(_ depth: Double) {
        let now = Date()
        let interval: TimeInterval
        if let last = lastUpdateTime {
            interval = now.timeIntervalSince(last)
        } else {
            interval = 1.0
        }
        lastUpdateTime = now

        if let start = diveStartTime {
            elapsedTime = now.timeIntervalSince(start)
        }

        // Ascent rate
        let result = ascentRateMonitor.evaluate(
            previousDepth: lastDepth,
            currentDepth: depth,
            timeInterval: interval
        )
        ascentRate = result.rate
        ascentRateStatus = result.status

        // Deco engine
        engine.updateTissues(depth: depth, gasMix: gasMix, timeInterval: interval)
        ndl = engine.ndl(depth: depth, gasMix: gasMix)
        ceilingDepth = engine.ceilingDepth()

        // Gas calculations
        ppO2 = GasCalculator.ppO2(depth: depth, gasMix: gasMix)
        cnsPercent = GasCalculator.updateCNS(currentCNS: cnsPercent, ppO2: ppO2, timeInterval: interval)
        otuTotal = GasCalculator.updateOTU(currentOTU: otuTotal, ppO2: ppO2, timeInterval: interval)

        // Safety stop
        safetyStopManager.update(currentDepth: depth, maxDepth: maxDepth, timeInterval: interval)

        // Track stats
        if depth > maxDepth { maxDepth = depth }
        depthSamples.append((depth: depth, time: elapsedTime))
        let totalDepth = depthSamples.reduce(0.0) { $0 + $1.depth }
        averageDepth = totalDepth / Double(depthSamples.count)

        // Update phase
        updatePhase(depth: depth)

        currentDepth = depth
        lastDepth = depth
    }

    public func updateTemperature(_ temp: Double) {
        temperature = temp
        if temp < minTemperature {
            minTemperature = temp
        }
    }

    // MARK: - Tissue Loading

    public var tissueLoadingPercent: [Double] {
        engine.tissueLoadingPercentages()
    }

    // MARK: - Gas Description

    public var gasDescription: String {
        if gasMix == .air { return "Air" }
        let o2Percent = Int(gasMix.o2Fraction * 100)
        return "EAN\(o2Percent)"
    }

    public var gfDescription: String {
        let low = Int(engine.gfLow * 100)
        let high = Int(engine.gfHigh * 100)
        return "\(low)/\(high)"
    }

    // MARK: - Phase Detection

    private func updatePhase(depth: Double) {
        guard phase != .surface && phase != .surfaceInterval else { return }

        let isSubmerged = depth >= depthThreshold

        if !isSubmerged && elapsedTime > 5 {
            endDive()
            return
        }

        if depth > lastDepth + 0.1 {
            phase = .descending
        } else if depth < lastDepth - 0.1 {
            if safetyStopManager.isAtSafetyStop {
                phase = .safetyStop
            } else {
                phase = .ascending
            }
        } else {
            if safetyStopManager.isAtSafetyStop {
                phase = .safetyStop
            } else {
                phase = .atDepth
            }
        }
    }
}
