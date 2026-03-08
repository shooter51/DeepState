import Foundation

public struct AscentRateMonitor {

    public enum AscentRateStatus: Sendable {
        case safe
        case warning
        case critical
    }

    public var targetRate: Double
    public var warningRate: Double
    public var criticalRate: Double

    public init(targetRate: Double = 9.0, warningRate: Double = 12.0, criticalRate: Double = 18.0) {
        self.targetRate = targetRate
        self.warningRate = warningRate
        self.criticalRate = criticalRate
    }

    public func evaluate(previousDepth: Double, currentDepth: Double, timeInterval: TimeInterval) -> (rate: Double, status: AscentRateStatus) {
        let timeMinutes = timeInterval / 60.0
        guard timeMinutes > 0 else {
            return (rate: 0.0, status: .safe)
        }

        let depthChange = previousDepth - currentDepth
        let rate = depthChange / timeMinutes

        // Descending (negative rate means going deeper)
        if rate < 0 {
            return (rate: abs(rate), status: .safe)
        }

        let status: AscentRateStatus
        if rate >= criticalRate {
            status = .critical
        } else if rate >= warningRate {
            status = .warning
        } else {
            status = .safe
        }

        return (rate: rate, status: status)
    }
}
