import XCTest
@testable import DiveCore

final class TissueStatePersistenceTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        TissueStatePersistence.clearPersistedState()
    }

    // MARK: - Round-trip persist/load

    func testPersistAndLoadRoundTrip() {
        let manager = DiveSessionManager(gasMix: .ean32, gfLow: 0.30, gfHigh: 0.70)
        manager.startDive()
        manager.updateDepth(10.0)
        manager.updateDepth(15.0)
        manager.updateDepth(18.0)

        TissueStatePersistence.persist(manager: manager)

        let loaded = TissueStatePersistence.loadPersistedState()
        XCTAssertNotNil(loaded, "Should load persisted state")

        guard let state = loaded else { return }

        // Verify tissue states match
        XCTAssertEqual(state.tissueStates.count, 16)
        for i in 0..<16 {
            XCTAssertEqual(state.tissueStates[i].pN2, manager.engine.tissueStates[i].pN2, accuracy: 0.0001,
                           "Tissue \(i) pN2 should match")
            XCTAssertEqual(state.tissueStates[i].pHe, manager.engine.tissueStates[i].pHe, accuracy: 0.0001,
                           "Tissue \(i) pHe should match")
        }

        // Verify other state
        XCTAssertEqual(state.gasMix, .ean32)
        XCTAssertEqual(state.gfLow, 0.30, accuracy: 0.001)
        XCTAssertEqual(state.gfHigh, 0.70, accuracy: 0.001)
        XCTAssertEqual(state.maxDepth, manager.maxDepth, accuracy: 0.01)
        XCTAssertEqual(state.currentDepth, manager.currentDepth, accuracy: 0.01)
        XCTAssertEqual(state.cnsPercent, manager.cnsPercent, accuracy: 0.001)
        XCTAssertEqual(state.otuTotal, manager.otuTotal, accuracy: 0.001)
    }

    // MARK: - hasInterruptedSession

    func testHasInterruptedSessionDescending() {
        let manager = DiveSessionManager()
        manager.startDive()
        manager.updateDepth(5.0)
        TissueStatePersistence.persist(manager: manager)

        XCTAssertTrue(TissueStatePersistence.hasInterruptedSession(),
                      "Descending phase should count as interrupted")
    }

    func testHasInterruptedSessionAtDepth() {
        let manager = DiveSessionManager()
        manager.startDive()
        // Go deep then stay level to get atDepth phase
        manager.updateDepth(15.0)
        manager.updateDepth(15.0)
        manager.updateDepth(15.0)
        TissueStatePersistence.persist(manager: manager)

        XCTAssertTrue(TissueStatePersistence.hasInterruptedSession(),
                      "AtDepth phase should count as interrupted")
    }

    func testHasInterruptedSessionAscending() {
        let manager = DiveSessionManager()
        manager.startDive()
        manager.updateDepth(20.0)
        manager.updateDepth(15.0)
        TissueStatePersistence.persist(manager: manager)

        XCTAssertTrue(TissueStatePersistence.hasInterruptedSession(),
                      "Ascending phase should count as interrupted")
    }

    func testHasInterruptedSessionReturnsFalseWhenNoPersistedState() {
        TissueStatePersistence.clearPersistedState()
        XCTAssertFalse(TissueStatePersistence.hasInterruptedSession(),
                       "Should return false when no persisted state exists")
    }

    func testHasInterruptedSessionReturnsFalseForSurfaceInterval() {
        let manager = DiveSessionManager()
        manager.startDive()
        manager.endDive()
        // endDive clears persisted state, so persist manually with surfaceInterval phase
        // We need to manually construct and save state for this test
        // Actually endDive() calls clearPersistedState(), so there won't be any file
        XCTAssertFalse(TissueStatePersistence.hasInterruptedSession(),
                       "Surface interval should not count as interrupted (no file after endDive)")
    }

    // MARK: - clearPersistedState

    func testClearPersistedStateRemovesFile() {
        let manager = DiveSessionManager()
        manager.startDive()
        manager.updateDepth(10.0)
        TissueStatePersistence.persist(manager: manager)

        XCTAssertTrue(TissueStatePersistence.hasInterruptedSession(), "Should have interrupted session before clear")

        TissueStatePersistence.clearPersistedState()

        XCTAssertFalse(TissueStatePersistence.hasInterruptedSession(), "Should not have interrupted session after clear")
    }

    func testClearPersistedStateThenLoadReturnsNil() {
        let manager = DiveSessionManager()
        manager.startDive()
        manager.updateDepth(10.0)
        TissueStatePersistence.persist(manager: manager)

        TissueStatePersistence.clearPersistedState()

        XCTAssertNil(TissueStatePersistence.loadPersistedState(),
                     "loadPersistedState should return nil after clear")
    }

    // MARK: - restore

    func testRestoreCreatesManagerWithCorrectTissueStates() {
        let manager = DiveSessionManager(gasMix: .ean36, gfLow: 0.35, gfHigh: 0.75)
        manager.startDive()
        manager.updateDepth(12.0)
        manager.updateDepth(18.0)
        manager.updateDepth(25.0)
        manager.updateTemperature(20.0)

        TissueStatePersistence.persist(manager: manager)

        guard let state = TissueStatePersistence.loadPersistedState() else {
            XCTFail("Failed to load persisted state")
            return
        }

        let restored = TissueStatePersistence.restore(from: state)

        // Verify tissue states match
        for i in 0..<16 {
            XCTAssertEqual(restored.engine.tissueStates[i].pN2, manager.engine.tissueStates[i].pN2,
                           accuracy: 0.0001, "Restored tissue \(i) pN2 should match")
            XCTAssertEqual(restored.engine.tissueStates[i].pHe, manager.engine.tissueStates[i].pHe,
                           accuracy: 0.0001, "Restored tissue \(i) pHe should match")
        }

        // Verify GF settings
        XCTAssertEqual(restored.engine.gfLow, 0.35, accuracy: 0.001)
        XCTAssertEqual(restored.engine.gfHigh, 0.75, accuracy: 0.001)

        // Verify gas mix
        XCTAssertEqual(restored.gasMix, .ean36)

        // Verify session state
        XCTAssertEqual(restored.maxDepth, manager.maxDepth, accuracy: 0.01)
        XCTAssertEqual(restored.currentDepth, manager.currentDepth, accuracy: 0.01)
        XCTAssertEqual(restored.temperature, manager.temperature, accuracy: 0.01)
        XCTAssertEqual(restored.minTemperature, manager.minTemperature, accuracy: 0.01)
        XCTAssertEqual(restored.cnsPercent, manager.cnsPercent, accuracy: 0.001)
        XCTAssertEqual(restored.otuTotal, manager.otuTotal, accuracy: 0.001)
    }

    func testRestorePreservesPhase() {
        let manager = DiveSessionManager()
        manager.startDive()
        manager.updateDepth(15.0)
        manager.updateDepth(10.0) // ascending

        TissueStatePersistence.persist(manager: manager)

        guard let state = TissueStatePersistence.loadPersistedState() else {
            XCTFail("Failed to load persisted state")
            return
        }

        let restored = TissueStatePersistence.restore(from: state)
        XCTAssertEqual(restored.phase.rawValue, state.phase,
                       "Restored manager phase should match persisted phase")
    }

    func testRestorePreservesElapsedTime() {
        let manager = DiveSessionManager()
        manager.startDive()
        manager.updateDepth(10.0)
        manager.updateDepth(15.0)

        TissueStatePersistence.persist(manager: manager)

        guard let state = TissueStatePersistence.loadPersistedState() else {
            XCTFail("Failed to load persisted state")
            return
        }

        let restored = TissueStatePersistence.restore(from: state)
        XCTAssertEqual(restored.elapsedTime, state.elapsedTime, accuracy: 1.0,
                       "Elapsed time should be restored approximately")
    }

    // MARK: - loadPersistedState when no file

    func testLoadPersistedStateReturnsNilWhenNoFile() {
        TissueStatePersistence.clearPersistedState()
        XCTAssertNil(TissueStatePersistence.loadPersistedState(),
                     "Should return nil when no file exists")
    }

    // MARK: - PersistedDiveState Codable

    func testPersistedDiveStateCodableRoundTrip() throws {
        let state = TissueStatePersistence.PersistedDiveState(
            tissueStates: (0..<16).map { _ in TissueStatePersistence.PersistedTissueState(pN2: 0.79, pHe: 0.0) },
            gasMix: .air,
            gfLow: 0.40,
            gfHigh: 0.85,
            phase: "descending",
            elapsedTime: 120.0,
            maxDepth: 18.0,
            avgDepth: 12.0,
            currentDepth: 18.0,
            temperature: 24.0,
            minTemperature: 22.0,
            cnsPercent: 1.5,
            otuTotal: 2.3,
            lastUpdateTimestamp: Date(),
            healthLog: [DiveHealthEvent(eventType: .phaseTransition, detail: "test")]
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(TissueStatePersistence.PersistedDiveState.self, from: data)

        XCTAssertEqual(decoded.tissueStates.count, 16)
        XCTAssertEqual(decoded.gasMix, .air)
        XCTAssertEqual(decoded.gfLow, 0.40, accuracy: 0.001)
        XCTAssertEqual(decoded.gfHigh, 0.85, accuracy: 0.001)
        XCTAssertEqual(decoded.phase, "descending")
        XCTAssertEqual(decoded.elapsedTime, 120.0, accuracy: 0.01)
        XCTAssertEqual(decoded.maxDepth, 18.0, accuracy: 0.01)
        XCTAssertEqual(decoded.cnsPercent, 1.5, accuracy: 0.01)
        XCTAssertEqual(decoded.healthLog.count, 1)
    }
}
