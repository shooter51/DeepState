import Foundation

/// Records a dive session's inputs and outputs into a DiveProfileExport.
///
/// Usage:
/// ```swift
/// let manager = DiveSessionManager(gasMix: .air, gfLow: 0.40, gfHigh: 0.85)
/// let recorder = DiveProfileRecorder(manager: manager)
/// manager.startDive()
/// recorder.recordStart()
///
/// // Each depth update:
/// manager.updateDepth(depth)
/// manager.updateTemperature(temp)
/// recorder.recordSample(inputDepth: depth, inputTemperature: temp)
///
/// // End:
/// manager.endDive()
/// let export = recorder.export()
/// let json = try export.toJSON()
/// ```
public class DiveProfileRecorder {

    private let manager: DiveSessionManager
    private var samples: [DiveProfileExport.ProfileSample] = []
    private var sampleIndex = 0

    public init(manager: DiveSessionManager) {
        self.manager = manager
    }

    /// Record the current state as a sample after a depth update.
    public func recordSample(inputDepth: Double, inputTemperature: Double?) {
        let sample = DiveProfileExport.ProfileSample(
            sampleIndex: sampleIndex,
            inputDepth: inputDepth,
            inputTemperature: inputTemperature,
            phase: manager.phase.rawValue,
            currentDepth: manager.currentDepth,
            maxDepth: manager.maxDepth,
            averageDepth: manager.averageDepth,
            elapsedTime: manager.elapsedTime,
            ndl: manager.ndl,
            ceilingDepth: manager.ceilingDepth,
            ascentRate: manager.ascentRate,
            ascentRateStatus: describeAscentRateStatus(manager.ascentRateStatus),
            ppO2: manager.ppO2,
            cnsPercent: manager.cnsPercent,
            otuTotal: manager.otuTotal,
            depthLimitStatus: describeDepthLimitStatus(manager.depthLimitStatus),
            safetyStopState: describeSafetyStopState(manager.safetyStopManager.state),
            temperature: manager.temperature,
            minTemperature: manager.minTemperature
        )
        samples.append(sample)
        sampleIndex += 1
    }

    /// Generate the export from all recorded samples.
    public func export() -> DiveProfileExport {
        let config = DiveProfileExport.DiveConfig(
            gasMix: manager.gasMix,
            gfLow: manager.engine.gfLow,
            gfHigh: manager.engine.gfHigh
        )

        let summary = DiveProfileExport.DiveSummary(
            maxDepth: manager.maxDepth,
            averageDepth: manager.averageDepth,
            duration: manager.elapsedTime,
            finalCNS: manager.cnsPercent,
            finalOTU: manager.otuTotal,
            finalPhase: manager.phase.rawValue,
            tissueLoading: manager.tissueLoadingPercent,
            healthEventCount: manager.healthLog.count,
            sampleCount: samples.count
        )

        return DiveProfileExport(config: config, samples: samples, summary: summary)
    }

    /// Reset the recorder for a new dive.
    public func reset() {
        samples = []
        sampleIndex = 0
    }

    // MARK: - Status Descriptions

    private func describeAscentRateStatus(_ status: AscentRateMonitor.AscentRateStatus) -> String {
        switch status {
        case .safe: return "safe"
        case .warning: return "warning"
        case .critical: return "critical"
        }
    }

    private func describeDepthLimitStatus(_ status: DepthLimits.DepthLimitStatus) -> String {
        switch status {
        case .safe: return "safe"
        case .approachingLimit: return "approachingLimit"
        case .maxDepthWarning: return "maxDepthWarning"
        case .depthLimitReached: return "depthLimitReached"
        }
    }

    private func describeSafetyStopState(_ state: SafetyStopManager.SafetyStopState) -> String {
        switch state {
        case .notRequired: return "notRequired"
        case .pending: return "pending"
        case .inProgress(let remaining): return "inProgress(\(Int(remaining)))"
        case .completed: return "completed"
        case .skipped: return "skipped"
        }
    }
}

// MARK: - Convenience: Record a complete dive from a profile array

extension DiveProfileRecorder {

    /// Run a complete dive from a set of waypoints and record every sample.
    /// Waypoints are linearly interpolated at 1-second intervals.
    ///
    /// - Parameters:
    ///   - waypoints: Array of (time in seconds, depth in meters)
    ///   - temperatureAt: Optional closure mapping depth to temperature
    ///   - tickInterval: Time between samples (default 1.0s)
    /// - Returns: The completed DiveProfileExport
    public static func recordDive(
        gasMix: GasMix = .air,
        gfLow: Double = 0.40,
        gfHigh: Double = 0.85,
        waypoints: [(time: TimeInterval, depth: Double)],
        temperatureAt: ((Double) -> Double)? = nil,
        tickInterval: TimeInterval = 1.0
    ) -> DiveProfileExport {
        let manager = DiveSessionManager(gasMix: gasMix, gfLow: gfLow, gfHigh: gfHigh)
        let recorder = DiveProfileRecorder(manager: manager)

        guard let lastWaypoint = waypoints.last else {
            return recorder.export()
        }

        manager.startDive()

        var elapsed: TimeInterval = tickInterval
        while elapsed <= lastWaypoint.time {
            let depth = interpolate(at: elapsed, waypoints: waypoints)
            let temp = temperatureAt?(depth)

            manager.updateDepth(depth)
            if let temp { manager.updateTemperature(temp) }

            recorder.recordSample(inputDepth: depth, inputTemperature: temp)
            elapsed += tickInterval
        }

        manager.endDive()
        return recorder.export()
    }

    private static func interpolate(at time: TimeInterval, waypoints: [(time: TimeInterval, depth: Double)]) -> Double {
        guard let first = waypoints.first, let last = waypoints.last else { return 0 }
        if time <= first.time { return first.depth }
        if time >= last.time { return last.depth }

        for i in 0..<(waypoints.count - 1) {
            let p1 = waypoints[i]
            let p2 = waypoints[i + 1]
            if time >= p1.time && time <= p2.time {
                let fraction = (time - p1.time) / (p2.time - p1.time)
                return p1.depth + (p2.depth - p1.depth) * fraction
            }
        }
        return 0
    }
}
