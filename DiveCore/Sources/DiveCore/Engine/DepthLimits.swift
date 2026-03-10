import Foundation

/// EN13319-compliant depth limits for Apple Watch Ultra
/// These values are NON-CONFIGURABLE safety constants
public enum DepthLimits {
    /// Apple Watch Ultra maximum rated depth (meters)
    public static let maxOperatingDepth: Double = 40.0
    /// Depth alarm default threshold (meters) - 2m buffer below MOD
    public static let defaultDepthAlarm: Double = 38.0
    /// Depth at which MAX DEPTH WARNING activates (meters)
    public static let warningDepth: Double = 39.0
    /// Depth at which NDL calculation is terminated (meters)
    public static let criticalDepth: Double = 40.0

    public enum DepthLimitStatus: Sendable, Equatable {
        case safe
        case approachingLimit  // >= depthAlarm setting
        case maxDepthWarning   // >= 39m
        case depthLimitReached // >= 40m
    }

    public static func evaluate(depth: Double, depthAlarm: Double = defaultDepthAlarm) -> DepthLimitStatus {
        let clampedAlarm = min(depthAlarm, criticalDepth)
        if depth >= criticalDepth { return .depthLimitReached }
        if depth >= warningDepth { return .maxDepthWarning }
        if depth >= clampedAlarm { return .approachingLimit }
        return .safe
    }
}
