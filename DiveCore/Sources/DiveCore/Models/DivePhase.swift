import Foundation

public enum DivePhase: String, Codable, CaseIterable, Sendable {
    case surface
    case predive
    case descending
    case atDepth
    case ascending
    case safetyStop
    case surfaceInterval
}
