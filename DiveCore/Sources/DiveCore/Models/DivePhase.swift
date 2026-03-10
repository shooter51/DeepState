import Foundation

public enum DivePhase: String, Codable, CaseIterable, Sendable {
    case surface
    case predive
    case descending
    case atDepth
    case ascending
    case safetyStop
    case surfaceInterval

    /// A human-readable name suitable for display in the UI.
    public var displayName: String {
        switch self {
        case .surface: return "Surface"
        case .predive: return "Pre-Dive"
        case .descending: return "Descending"
        case .atDepth: return "At Depth"
        case .ascending: return "Ascending"
        case .safetyStop: return "Safety Stop"
        case .surfaceInterval: return "Surface Interval"
        }
    }
}
