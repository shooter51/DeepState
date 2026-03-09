import Foundation

public struct DiveHealthEvent: Codable, Sendable {
    public let timestamp: Date
    public let eventType: EventType
    public let detail: String

    public enum EventType: String, Codable, Sendable {
        case sensorUnavailable
        case sensorRestored
        case sensorDataStale
        case backgroundInterruption
        case backgroundResumed
        case depthLimitWarning
        case depthLimitReached
        case ndlAnomaly
        case phaseTransition
        case safetyStopStarted
        case safetyStopCompleted
        case safetyStopSkipped
    }

    public init(timestamp: Date = Date(), eventType: EventType, detail: String = "") {
        self.timestamp = timestamp
        self.eventType = eventType
        self.detail = detail
    }
}

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

    // MARK: - Depth Limit Tracking

    public private(set) var depthLimitStatus: DepthLimits.DepthLimitStatus = .safe
    public var depthAlarm: Double = DepthLimits.defaultDepthAlarm

    // MARK: - Stale Sensor Data Detection

    public private(set) var sensorDataAge: TimeInterval = 0
    public private(set) var isSensorDataStale: Bool = false
    private static let maxSensorDataAge: TimeInterval = 10.0

    // MARK: - Health Event Logging

    public private(set) var healthLog: [DiveHealthEvent] = []
    private var lastNDL: Int = 999
    private var lastSafetyStopState: SafetyStopManager.SafetyStopState?

    // MARK: - Persistence

    private var samplesSincePersist: Int = 0

    // MARK: - Sub-objects

    public let gasMix: GasMix
    public let engine: BuhlmannEngine
    public let safetyStopManager: SafetyStopManager
    public let ascentRateMonitor: AscentRateMonitor

    var diveStartTime: Date?
    var lastUpdateTime: Date?
    var lastDepth: Double = 0
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
        let previousPhase = phase
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
        healthLog = []
        lastNDL = 999
        samplesSincePersist = 0
        depthLimitStatus = .safe
        sensorDataAge = 0
        isSensorDataStale = false
        safetyStopManager.reset()
        // Only reset tissues for first dive; preserve residual loading for repetitive dives
        if previousPhase != .surfaceInterval {
            engine.resetToSurface()
        }

        if previousPhase != .descending {
            logEvent(.phaseTransition, detail: "surface -> descending")
        }
    }

    public func endDive() {
        let previousPhase = phase
        phase = .surfaceInterval
        surfaceIntervalStart = Date()
        TissueStatePersistence.clearPersistedState()

        if previousPhase != .surfaceInterval {
            logEvent(.phaseTransition, detail: "\(previousPhase.rawValue) -> surfaceInterval")
        }
    }

    public func resetForNewDive() {
        phase = .surface
        surfaceIntervalStart = nil
    }

    // MARK: - Sensor Updates

    public func updateDepth(_ depth: Double) {
        let now = Date()
        let depth = max(0, depth)
        let interval: TimeInterval
        if let last = lastUpdateTime {
            interval = now.timeIntervalSince(last)
        } else {
            interval = 1.0
        }
        lastUpdateTime = now

        // Reset stale sensor tracking
        sensorDataAge = 0
        isSensorDataStale = false

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

        // Depth limit evaluation
        let previousDepthLimitStatus = depthLimitStatus
        depthLimitStatus = DepthLimits.evaluate(depth: depth, depthAlarm: depthAlarm)

        if depthLimitStatus == .depthLimitReached {
            // Preserve actual NDL — the UI layer shows a full-screen DEPTH LIMIT
            // overlay, so zeroing NDL is unnecessary and removes useful info
            if previousDepthLimitStatus != .depthLimitReached {
                logEvent(.depthLimitReached, detail: "Depth \(String(format: "%.1f", depth))m >= \(String(format: "%.1f", DepthLimits.criticalDepth))m")
            }
        } else if depthLimitStatus == .maxDepthWarning || depthLimitStatus == .approachingLimit {
            if previousDepthLimitStatus == .safe {
                logEvent(.depthLimitWarning, detail: "Depth \(String(format: "%.1f", depth))m approaching limit")
            }
        }

        // NDL anomaly detection
        let ndlChange = abs(lastNDL - ndl)
        if ndlChange > 5 && lastNDL != 999 && ndl != 999 && ndl != 0 {
            logEvent(.ndlAnomaly, detail: "NDL changed by \(ndlChange) minutes (\(lastNDL) -> \(ndl))")
        }
        lastNDL = ndl

        // Gas calculations
        ppO2 = GasCalculator.ppO2(depth: depth, gasMix: gasMix)
        cnsPercent = GasCalculator.updateCNS(currentCNS: cnsPercent, ppO2: ppO2, timeInterval: interval)
        otuTotal = GasCalculator.updateOTU(currentOTU: otuTotal, ppO2: ppO2, timeInterval: interval)

        // Safety stop - track previous state for logging
        let previousSafetyState = safetyStopManager.state
        safetyStopManager.update(currentDepth: depth, maxDepth: maxDepth, timeInterval: interval)
        logSafetyStopTransitions(from: previousSafetyState, to: safetyStopManager.state)

        // Track stats
        if depth > maxDepth { maxDepth = depth }
        depthSamples.append((depth: depth, time: elapsedTime))
        let totalDepth = depthSamples.reduce(0.0) { $0 + $1.depth }
        averageDepth = totalDepth / Double(depthSamples.count)

        // Update phase
        updatePhase(depth: depth)

        currentDepth = depth
        lastDepth = depth

        // Periodic persistence
        samplesSincePersist += 1
        if samplesSincePersist >= 5 {
            TissueStatePersistence.persist(manager: self)
            samplesSincePersist = 0
        }
    }

    public func updateTemperature(_ temp: Double) {
        temperature = temp
        if temp < minTemperature {
            minTemperature = temp
        }
    }

    // MARK: - Stale Sensor Detection

    /// Call periodically (e.g., every 1 second) to track sensor data freshness
    public func checkSensorStaleness() {
        sensorDataAge += 1.0
        if sensorDataAge > DiveSessionManager.maxSensorDataAge {
            if !isSensorDataStale {
                logEvent(.sensorDataStale, detail: "No sensor update for \(String(format: "%.0f", sensorDataAge))s")
            }
            isSensorDataStale = true
            ndl = 0
        }
    }

    // MARK: - Session Integrity Score

    public var sessionIntegrityScore: Double {
        var score = 100.0
        for event in healthLog {
            switch event.eventType {
            case .sensorDataStale:
                score -= 5.0
            case .backgroundInterruption:
                score -= 10.0
            case .ndlAnomaly:
                score -= 15.0
            case .depthLimitReached:
                score -= 20.0
            case .sensorUnavailable:
                score -= 25.0
            default:
                break
            }
        }
        return min(100.0, max(0.0, score))
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

    // MARK: - State Restoration (Crash Recovery)

    /// Restore state from persisted snapshot (crash recovery only)
    public func restoreState(
        phase: DivePhase,
        elapsedTime: TimeInterval,
        maxDepth: Double,
        avgDepth: Double,
        currentDepth: Double,
        temperature: Double,
        minTemperature: Double,
        cnsPercent: Double,
        otuTotal: Double,
        healthLog: [DiveHealthEvent]
    ) {
        self.phase = phase
        self.elapsedTime = elapsedTime
        self.maxDepth = maxDepth
        self.averageDepth = avgDepth
        self.currentDepth = currentDepth
        self.temperature = temperature
        self.minTemperature = minTemperature
        self.cnsPercent = cnsPercent
        self.otuTotal = otuTotal
        self.healthLog = healthLog
        self.diveStartTime = Date().addingTimeInterval(-elapsedTime)
        self.lastUpdateTime = Date()
        self.lastDepth = currentDepth

        // Log recovery event
        logEvent(.backgroundResumed, detail: "Session recovered from persisted state")
    }

    // MARK: - Phase Detection

    private func updatePhase(depth: Double) {
        guard phase != .surface && phase != .surfaceInterval else { return }

        let isSubmerged = depth >= depthThreshold
        let previousPhase = phase

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

        if phase != previousPhase {
            logEvent(.phaseTransition, detail: "\(previousPhase.rawValue) -> \(phase.rawValue)")
        }
    }

    // MARK: - Health Event Helpers

    private func logEvent(_ type: DiveHealthEvent.EventType, detail: String = "") {
        let event = DiveHealthEvent(timestamp: Date(), eventType: type, detail: detail)
        healthLog.append(event)
    }

    private func logSafetyStopTransitions(from previous: SafetyStopManager.SafetyStopState, to current: SafetyStopManager.SafetyStopState) {
        switch (previous, current) {
        case (.pending, .inProgress):
            logEvent(.safetyStopStarted, detail: "Safety stop begun")
        case (.inProgress, .completed):
            logEvent(.safetyStopCompleted, detail: "Safety stop completed")
        case (.inProgress, .skipped), (.pending, .skipped):
            logEvent(.safetyStopSkipped, detail: "Safety stop skipped")
        default:
            break
        }
    }
}
