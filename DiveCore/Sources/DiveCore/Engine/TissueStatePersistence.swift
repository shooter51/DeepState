import Foundation

/// Persists tissue compartment state to disk for crash recovery
public class TissueStatePersistence {

    public struct PersistedDiveState: Codable {
        public let tissueStates: [PersistedTissueState]
        public let gasMix: GasMix
        public let gfLow: Double
        public let gfHigh: Double
        public let phase: String // DivePhase rawValue
        public let elapsedTime: TimeInterval
        public let maxDepth: Double
        public let avgDepth: Double
        public let currentDepth: Double
        public let temperature: Double
        public let minTemperature: Double
        public let cnsPercent: Double
        public let otuTotal: Double
        public let lastUpdateTimestamp: Date
        public let healthLog: [DiveHealthEvent]
    }

    public struct PersistedTissueState: Codable {
        public let pN2: Double
        public let pHe: Double
    }

    private static let fileName = "deepstate_active_dive.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    /// Save current dive state to disk
    public static func persist(manager: DiveSessionManager) {
        let state = PersistedDiveState(
            tissueStates: manager.engine.tissueStates.map { PersistedTissueState(pN2: $0.pN2, pHe: $0.pHe) },
            gasMix: manager.gasMix,
            gfLow: manager.engine.gfLow,
            gfHigh: manager.engine.gfHigh,
            phase: manager.phase.rawValue,
            elapsedTime: manager.elapsedTime,
            maxDepth: manager.maxDepth,
            avgDepth: manager.averageDepth,
            currentDepth: manager.currentDepth,
            temperature: manager.temperature,
            minTemperature: manager.minTemperature,
            cnsPercent: manager.cnsPercent,
            otuTotal: manager.otuTotal,
            lastUpdateTimestamp: Date(),
            healthLog: manager.healthLog
        )

        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Persistence failure is logged but non-fatal
            print("[DeepState] Failed to persist tissue state: \(error)")
        }
    }

    /// Load persisted dive state (returns nil if no active session)
    public static func loadPersistedState() -> PersistedDiveState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(PersistedDiveState.self, from: data)
        } catch {
            return nil
        }
    }

    /// Check if there's an interrupted dive session to recover
    public static func hasInterruptedSession() -> Bool {
        guard let state = loadPersistedState() else { return false }
        // Session is interrupted if it was in an active dive phase
        let activePhases: Set<String> = ["descending", "atDepth", "ascending", "safetyStop"]
        return activePhases.contains(state.phase)
    }

    /// Clear persisted state (call when dive ends normally)
    public static func clearPersistedState() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Restore a DiveSessionManager from persisted state
    public static func restore(from state: PersistedDiveState) -> DiveSessionManager {
        let manager = DiveSessionManager(gasMix: state.gasMix, gfLow: state.gfLow, gfHigh: state.gfHigh)

        // Validate tissue state count matches expected 16 compartments.
        // If mismatched, return a fresh manager rather than restoring partial state.
        guard state.tissueStates.count == 16 else {
            return manager
        }

        // Restore tissue states
        for (i, tissue) in state.tissueStates.enumerated() where i < 16 {
            manager.engine.tissueStates[i] = TissueState(pN2: tissue.pN2, pHe: tissue.pHe)
        }

        // Restore session state
        manager.restoreState(
            phase: DivePhase(rawValue: state.phase) ?? .surface,
            elapsedTime: state.elapsedTime,
            maxDepth: state.maxDepth,
            avgDepth: state.avgDepth,
            currentDepth: state.currentDepth,
            temperature: state.temperature,
            minTemperature: state.minTemperature,
            cnsPercent: state.cnsPercent,
            otuTotal: state.otuTotal,
            healthLog: state.healthLog
        )

        return manager
    }
}
