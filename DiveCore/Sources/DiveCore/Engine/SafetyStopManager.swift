import Foundation

public class SafetyStopManager {

    public enum SafetyStopState: Sendable {
        case notRequired
        case pending
        case inProgress(remaining: TimeInterval)
        case completed
        case skipped
    }

    public var safetyStopDepth: Double = 5.0
    public var safetyStopDuration: TimeInterval = 180.0
    public var depthTolerance: Double = 1.5
    public var minimumDepthForStop: Double = 10.0

    public private(set) var state: SafetyStopState = .notRequired
    public private(set) var timeAccumulated: TimeInterval = 0.0

    public init(stopDepth: Double = 5.0, stopDuration: TimeInterval = 180.0, minimumDepthForStop: Double = 10.0) {
        self.safetyStopDepth = stopDepth
        self.safetyStopDuration = stopDuration
        self.minimumDepthForStop = minimumDepthForStop
    }

    public func update(currentDepth: Double, maxDepth: Double, timeInterval: TimeInterval) {
        switch state {
        case .notRequired:
            if maxDepth >= minimumDepthForStop && currentDepth < safetyStopDepth + depthTolerance && currentDepth > 0.5 {
                state = .pending
            }

        case .pending:
            if currentDepth <= safetyStopDepth + depthTolerance && currentDepth >= safetyStopDepth - depthTolerance {
                state = .inProgress(remaining: safetyStopDuration)
                timeAccumulated = 0
            } else if currentDepth < safetyStopDepth - depthTolerance {
                state = .skipped
            }

        case .inProgress:
            if currentDepth <= safetyStopDepth + depthTolerance && currentDepth >= safetyStopDepth - depthTolerance {
                timeAccumulated += timeInterval
                let remaining = max(0, safetyStopDuration - timeAccumulated)
                if remaining <= 0 {
                    state = .completed
                } else {
                    state = .inProgress(remaining: remaining)
                }
            } else if currentDepth > safetyStopDepth + depthTolerance {
                state = .pending
                timeAccumulated = 0
            } else if currentDepth < safetyStopDepth - depthTolerance {
                state = .skipped
            }

        case .completed, .skipped:
            break
        }
    }

    public var isAtSafetyStop: Bool {
        if case .inProgress = state { return true }
        return false
    }

    public var remainingTime: TimeInterval {
        if case .inProgress(let remaining) = state { return remaining }
        return 0
    }

    public var safetyStopRequired: Bool {
        switch state {
        case .pending, .inProgress:
            return true
        default:
            return false
        }
    }

    public func reset() {
        state = .notRequired
        timeAccumulated = 0
    }
}
