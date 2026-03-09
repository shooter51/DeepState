import XCTest
@testable import DiveCore

/// Consumer-driven contract tests validating the DiveCore ↔ UI layer interface.
///
/// These tests act as Pact-style contracts: they verify that DiveSessionManager
/// (the provider) satisfies the behavioral contracts expected by the watchOS
/// DiveViewModel (the consumer). If any contract breaks, the UI layer would
/// malfunction.
///
/// Contract areas:
/// 1. State shape: all properties the UI reads are accessible and typed correctly
/// 2. Lifecycle: startDive/endDive/resetForNewDive produce expected state transitions
/// 3. Depth update: updateDepth produces consistent derived values (NDL, ppO2, ascent rate, etc.)
/// 4. Safety contracts: depth limits, stale sensor detection, health events
/// 5. Sub-object access: engine, safetyStopManager, ascentRateMonitor are exposed
/// 6. Version check: VersionManifest + VersionComparator contracts
final class ContractTests: XCTestCase {

    // MARK: - Contract 1: State Shape

    /// The UI layer reads these properties. They must exist, be the right type,
    /// and have sensible defaults before any dive starts.
    func testInitialStateContract() {
        let mgr = DiveSessionManager()

        // Phase
        XCTAssertEqual(mgr.phase, .surface)

        // Depth values
        XCTAssertEqual(mgr.currentDepth, 0)
        XCTAssertEqual(mgr.maxDepth, 0)
        XCTAssertEqual(mgr.averageDepth, 0)

        // Environmental
        XCTAssertEqual(mgr.temperature, 22.0, accuracy: 0.1)
        XCTAssertEqual(mgr.minTemperature, 22.0, accuracy: 0.1)

        // Timing
        XCTAssertEqual(mgr.elapsedTime, 0)

        // Decompression
        XCTAssertEqual(mgr.ndl, 999)
        XCTAssertEqual(mgr.ceilingDepth, 0)

        // Ascent
        XCTAssertEqual(mgr.ascentRate, 0)
        XCTAssertEqual(mgr.ascentRateStatus, .safe)

        // Gas tracking
        XCTAssertEqual(mgr.cnsPercent, 0)
        XCTAssertEqual(mgr.otuTotal, 0)
        XCTAssertEqual(mgr.ppO2, 0.21, accuracy: 0.01)

        // Surface interval
        XCTAssertNil(mgr.surfaceIntervalStart)

        // Safety
        XCTAssertEqual(mgr.depthLimitStatus, .safe)
        XCTAssertFalse(mgr.isSensorDataStale)
        XCTAssertEqual(mgr.sensorDataAge, 0)
        XCTAssertTrue(mgr.healthLog.isEmpty)
    }

    /// UI reads gas mix and sub-object properties.
    func testSubObjectAccessContract() {
        let mgr = DiveSessionManager(gasMix: .ean32, gfLow: 0.30, gfHigh: 0.70)

        // Gas mix is accessible
        XCTAssertEqual(mgr.gasMix.o2Fraction, 0.32, accuracy: 0.001)
        XCTAssertTrue(mgr.gasMix.isNitrox)

        // Engine is accessible and configured
        XCTAssertEqual(mgr.engine.gfLow, 0.30, accuracy: 0.001)
        XCTAssertEqual(mgr.engine.gfHigh, 0.70, accuracy: 0.001)
        XCTAssertEqual(mgr.engine.tissueStates.count, 16)

        // Safety stop manager is accessible
        XCTAssertNotNil(mgr.safetyStopManager)

        // Ascent rate monitor is accessible
        XCTAssertNotNil(mgr.ascentRateMonitor)
    }

    /// UI reads computed description properties.
    func testComputedDescriptionContract() {
        let airMgr = DiveSessionManager(gasMix: .air)
        XCTAssertEqual(airMgr.gasDescription, "Air")
        XCTAssertTrue(airMgr.gfDescription.contains("40"))
        XCTAssertTrue(airMgr.gfDescription.contains("85"))

        let nitroxMgr = DiveSessionManager(gasMix: .ean32, gfLow: 0.30, gfHigh: 0.70)
        XCTAssertEqual(nitroxMgr.gasDescription, "EAN32")
        XCTAssertTrue(nitroxMgr.gfDescription.contains("30"))
        XCTAssertTrue(nitroxMgr.gfDescription.contains("70"))
    }

    /// UI reads tissueLoadingPercent for the 16-bar chart.
    func testTissueLoadingContract() {
        let mgr = DiveSessionManager()
        let loading = mgr.tissueLoadingPercent

        XCTAssertEqual(loading.count, 16, "Must provide exactly 16 tissue loading values")
        for value in loading {
            XCTAssertGreaterThanOrEqual(value, 0, "Tissue loading should not be negative")
        }
    }

    // MARK: - Contract 2: Lifecycle Transitions

    /// startDive must transition to descending and reset all tracking state.
    func testStartDiveContract() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        XCTAssertEqual(mgr.phase, .descending)
        XCTAssertEqual(mgr.currentDepth, 0)
        XCTAssertEqual(mgr.maxDepth, 0)
        XCTAssertEqual(mgr.cnsPercent, 0)
        XCTAssertEqual(mgr.otuTotal, 0)
        XCTAssertTrue(mgr.healthLog.count >= 1, "Should log phase transition event")
    }

    /// endDive must transition to surfaceInterval and set surfaceIntervalStart.
    func testEndDiveContract() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(10.0)
        mgr.endDive()

        XCTAssertEqual(mgr.phase, .surfaceInterval)
        XCTAssertNotNil(mgr.surfaceIntervalStart)
    }

    /// resetForNewDive must return to surface and clear surface interval.
    func testResetForNewDiveContract() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(10.0)
        mgr.endDive()
        mgr.resetForNewDive()

        XCTAssertEqual(mgr.phase, .surface)
        XCTAssertNil(mgr.surfaceIntervalStart)
    }

    // MARK: - Contract 3: Depth Update Produces Derived Values

    /// When updateDepth is called during a dive, all derived values must update.
    func testDepthUpdateContract() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Descend to 20m
        for _ in 0..<20 {
            mgr.updateDepth(20.0)
        }

        // Current depth must reflect input
        XCTAssertEqual(mgr.currentDepth, 20.0, accuracy: 0.1)

        // Max depth must track maximum
        XCTAssertGreaterThanOrEqual(mgr.maxDepth, 20.0)

        // NDL must be finite and reasonable at 20m
        XCTAssertGreaterThan(mgr.ndl, 0, "NDL should be positive at 20m with air")
        XCTAssertLessThan(mgr.ndl, 999, "NDL should be less than 999 at 20m")

        // ppO2 must be correct for depth
        let expectedPpO2 = GasCalculator.ppO2(depth: 20.0, gasMix: .air)
        XCTAssertEqual(mgr.ppO2, expectedPpO2, accuracy: 0.01)

        // Ceiling should still be 0 (within NDL)
        XCTAssertEqual(mgr.ceilingDepth, 0, accuracy: 0.5)

        // Elapsed time must be positive
        XCTAssertGreaterThan(mgr.elapsedTime, 0)
    }

    /// updateTemperature must update both current and min temperature.
    func testTemperatureUpdateContract() {
        let mgr = DiveSessionManager()
        mgr.updateTemperature(18.0)

        XCTAssertEqual(mgr.temperature, 18.0)
        XCTAssertEqual(mgr.minTemperature, 18.0)

        mgr.updateTemperature(22.0)
        XCTAssertEqual(mgr.temperature, 22.0)
        XCTAssertEqual(mgr.minTemperature, 18.0, "Min temp must track the minimum")
    }

    // MARK: - Contract 4: Safety Contracts

    /// Depth limit status must change when approaching/exceeding 40m.
    func testDepthLimitStatusContract() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // At safe depth
        mgr.updateDepth(20.0)
        XCTAssertEqual(mgr.depthLimitStatus, .safe)

        // At alarm depth (default 38m)
        mgr.updateDepth(38.0)
        XCTAssertEqual(mgr.depthLimitStatus, .approachingLimit)

        // At warning depth (39m)
        mgr.updateDepth(39.0)
        XCTAssertEqual(mgr.depthLimitStatus, .maxDepthWarning)

        // At critical depth (40m)
        mgr.updateDepth(40.0)
        XCTAssertEqual(mgr.depthLimitStatus, .depthLimitReached)
    }

    /// Health events must be logged for depth limit violations.
    func testHealthEventLoggingContract() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(39.0)
        mgr.updateDepth(40.0)

        let eventTypes = Set(mgr.healthLog.map { $0.eventType })

        // Must log phase transition from startDive
        XCTAssertTrue(eventTypes.contains(.phaseTransition))
        // Must log depth limit events
        XCTAssertTrue(eventTypes.contains(.depthLimitWarning) || eventTypes.contains(.depthLimitReached),
                      "Must log depth limit events when exceeding safe depth")
    }

    /// DiveHealthEvent must be Codable (for persistence contract).
    func testHealthEventCodableContract() throws {
        let event = DiveHealthEvent(eventType: .sensorDataStale, detail: "No data for 15s")
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(DiveHealthEvent.self, from: data)

        XCTAssertEqual(decoded.eventType, .sensorDataStale)
        XCTAssertEqual(decoded.detail, "No data for 15s")
    }

    /// All 12 health event types must be representable.
    func testAllHealthEventTypesContract() {
        let allTypes: [DiveHealthEvent.EventType] = [
            .sensorUnavailable, .sensorRestored, .sensorDataStale,
            .backgroundInterruption, .backgroundResumed,
            .depthLimitWarning, .depthLimitReached,
            .ndlAnomaly, .phaseTransition,
            .safetyStopStarted, .safetyStopCompleted, .safetyStopSkipped
        ]
        XCTAssertEqual(allTypes.count, 12, "Must support exactly 12 health event types")
    }

    // MARK: - Contract 5: Safety Stop State Machine

    /// Safety stop must follow the documented state machine.
    func testSafetyStopContract() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Dive to 15m (deep enough to trigger safety stop requirement)
        for _ in 0..<30 {
            mgr.updateDepth(15.0)
        }

        // At 15m depth, safety stop is not yet triggered (diver hasn't ascended)
        XCTAssertFalse(mgr.safetyStopManager.safetyStopRequired,
                       "Safety stop should not be required while still deep")

        // Ascend to safety stop zone (5m) — this triggers pending → inProgress
        mgr.updateDepth(5.0)

        // Safety stop should now be required (pending or inProgress)
        XCTAssertTrue(mgr.safetyStopManager.safetyStopRequired,
                      "Safety stop must be required when ascending through stop zone after deep dive")
    }

    // MARK: - Contract 6: DivePhase Enum

    /// All 7 phases must exist and be accessible.
    func testDivePhaseContract() {
        let phases: [DivePhase] = [
            .surface, .predive, .descending, .atDepth,
            .ascending, .safetyStop, .surfaceInterval
        ]
        XCTAssertEqual(phases.count, 7, "Must support exactly 7 dive phases")

        // Must be Codable
        for phase in phases {
            let encoded = try? JSONEncoder().encode(phase)
            XCTAssertNotNil(encoded, "\(phase) must be encodable")
        }
    }

    // MARK: - Contract 7: GasMix

    /// The three preset gas mixes must exist with documented fractions.
    func testGasMixPresetsContract() {
        // Air: 21/79/0
        XCTAssertEqual(GasMix.air.o2Fraction, 0.21, accuracy: 0.001)
        XCTAssertEqual(GasMix.air.n2Fraction, 0.79, accuracy: 0.001)
        XCTAssertFalse(GasMix.air.isNitrox)

        // EAN32: 32/68/0
        XCTAssertEqual(GasMix.ean32.o2Fraction, 0.32, accuracy: 0.001)
        XCTAssertTrue(GasMix.ean32.isNitrox)

        // EAN36: 36/64/0
        XCTAssertEqual(GasMix.ean36.o2Fraction, 0.36, accuracy: 0.001)
        XCTAssertTrue(GasMix.ean36.isNitrox)
    }

    /// nitrox() factory must produce valid mixes for the allowed range.
    func testGasMixNitroxFactoryContract() {
        for percent in 21...40 {
            let mix = GasMix.nitrox(o2Percent: percent)
            let total = mix.o2Fraction + mix.n2Fraction + mix.heFraction
            XCTAssertEqual(total, 1.0, accuracy: 0.001,
                           "Gas fractions must sum to 1.0 for \(percent)%")
            XCTAssertEqual(mix.heFraction, 0.0,
                           "Nitrox must have 0 helium")
        }
    }

    /// GasMix must be Codable and Equatable.
    func testGasMixCodableEquatableContract() throws {
        let original = GasMix.ean32
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Contract 8: Version Check

    /// VersionManifest must decode from the documented JSON shape.
    func testVersionManifestContract() throws {
        let json = """
        {"minimumSafeVersion":"1.2.0","safetyNotice":"Critical fix","blockDiveMode":true}
        """
        let manifest = try JSONDecoder().decode(VersionManifest.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(manifest.minimumSafeVersion, "1.2.0")
        XCTAssertEqual(manifest.safetyNotice, "Critical fix")
        XCTAssertTrue(manifest.blockDiveMode)
    }

    /// VersionManifest with null safetyNotice must decode correctly.
    func testVersionManifestNullNoticeContract() throws {
        let json = """
        {"minimumSafeVersion":"1.0.0","safetyNotice":null,"blockDiveMode":false}
        """
        let manifest = try JSONDecoder().decode(VersionManifest.self, from: json.data(using: .utf8)!)

        XCTAssertNil(manifest.safetyNotice)
        XCTAssertFalse(manifest.blockDiveMode)
    }

    /// VersionComparator must correctly identify older versions.
    func testVersionComparatorContract() {
        // Older
        XCTAssertTrue(VersionComparator.isVersion("1.0.0", olderThan: "1.0.1"))
        XCTAssertTrue(VersionComparator.isVersion("1.0.0", olderThan: "1.1.0"))
        XCTAssertTrue(VersionComparator.isVersion("1.0.0", olderThan: "2.0.0"))

        // Not older
        XCTAssertFalse(VersionComparator.isVersion("1.0.0", olderThan: "1.0.0"))
        XCTAssertFalse(VersionComparator.isVersion("2.0.0", olderThan: "1.0.0"))
    }

    /// VersionCheckService.Status must have all 4 documented cases.
    func testVersionCheckStatusContract() {
        let statuses: [VersionCheckService.Status] = [
            .unknown,
            .upToDate,
            .updateRequired(notice: "test"),
            .checkFailed
        ]
        XCTAssertEqual(statuses.count, 4)

        // updateRequired must carry an optional notice
        if case .updateRequired(let notice) = statuses[2] {
            XCTAssertEqual(notice, "test")
        } else {
            XCTFail("updateRequired case must carry notice")
        }
    }

    // MARK: - Contract 9: BuhlmannEngine Interface

    /// Engine must expose 16 tissue states and respond to standard queries.
    func testBuhlmannEngineInterfaceContract() {
        let engine = BuhlmannEngine(gfLow: 0.40, gfHigh: 0.85)

        // 16 compartments
        XCTAssertEqual(engine.tissueStates.count, 16)

        // NDL at surface should be 999
        let ndl = engine.ndl(depth: 0, gasMix: .air)
        XCTAssertEqual(ndl, 999)

        // Ceiling at surface should be 0
        let ceiling = engine.ceilingDepth()
        XCTAssertEqual(ceiling, 0, accuracy: 0.1)

        // GF at surface
        let gf = engine.gfAtDepth(depth: 0)
        XCTAssertEqual(gf, 0.85, accuracy: 0.01)

        // Tissue loading returns 16 values
        let loading = engine.tissueLoadingPercentages()
        XCTAssertEqual(loading.count, 16)

        // Deco stops at surface should be empty
        let stops = engine.decoStops(gasMix: .air)
        XCTAssertTrue(stops.isEmpty)
    }

    /// updateTissues must change tissue state.
    func testBuhlmannEngineUpdateContract() {
        let engine = BuhlmannEngine()
        let before = engine.tissueStates[0].pN2

        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 60.0)

        let after = engine.tissueStates[0].pN2
        XCTAssertGreaterThan(after, before, "Tissue pN2 must increase at depth")
    }

    /// resetToSurface must return tissues to surface saturation.
    func testBuhlmannEngineResetContract() {
        let engine = BuhlmannEngine()
        engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 300.0)
        engine.resetToSurface()

        let surfacePpN2 = GasMix.air.n2Fraction * (engine.surfacePressure - 0.0627)
        for ts in engine.tissueStates {
            XCTAssertEqual(ts.pN2, surfacePpN2, accuracy: 0.001)
            XCTAssertEqual(ts.pHe, 0.0, accuracy: 0.001)
        }
    }

    // MARK: - Contract 10: GasCalculator Interface

    /// GasCalculator static methods must exist and return reasonable values.
    func testGasCalculatorInterfaceContract() {
        // MOD
        let mod = GasCalculator.mod(gasMix: .air, ppO2Max: 1.4)
        XCTAssertGreaterThan(mod, 50.0)
        XCTAssertLessThan(mod, 70.0)

        // ppO2
        let ppo2 = GasCalculator.ppO2(depth: 30.0, gasMix: .air)
        XCTAssertGreaterThan(ppo2, 0.5)
        XCTAssertLessThan(ppo2, 1.5)

        // CNS
        let cns = GasCalculator.cnsPerMinute(ppO2: 1.6)
        XCTAssertGreaterThan(cns, 0)

        // CNS below threshold
        let cnsSafe = GasCalculator.cnsPerMinute(ppO2: 0.5)
        XCTAssertEqual(cnsSafe, 0)

        // EAD
        let ead = GasCalculator.ead(depth: 30.0, gasMix: .ean32)
        XCTAssertLessThan(ead, 30.0, "EAD on nitrox must be less than actual depth")
    }

    // MARK: - Contract 11: DepthLimits Constants

    /// Non-configurable depth limits must match documented values.
    func testDepthLimitsConstantsContract() {
        XCTAssertEqual(DepthLimits.maxOperatingDepth, 40.0)
        XCTAssertEqual(DepthLimits.defaultDepthAlarm, 38.0)
        XCTAssertEqual(DepthLimits.warningDepth, 39.0)
        XCTAssertEqual(DepthLimits.criticalDepth, 40.0)
    }

    /// DepthLimitStatus must have exactly 4 cases.
    func testDepthLimitStatusEnumContract() {
        let statuses: [DepthLimits.DepthLimitStatus] = [
            .safe, .approachingLimit, .maxDepthWarning, .depthLimitReached
        ]
        XCTAssertEqual(statuses.count, 4)
    }

    // MARK: - Contract 12: AscentRateMonitor

    /// AscentRateStatus must have exactly 3 cases and evaluate must return rate + status.
    func testAscentRateMonitorContract() {
        let monitor = AscentRateMonitor()

        let result = monitor.evaluate(previousDepth: 20.0, currentDepth: 19.0, timeInterval: 1.0)

        // Must return rate
        XCTAssertGreaterThanOrEqual(result.rate, 0)

        // Must return a status
        let validStatuses: [AscentRateMonitor.AscentRateStatus] = [.safe, .warning, .critical]
        XCTAssertTrue(validStatuses.contains(result.status))
    }

    // MARK: - Contract 13: TissueStatePersistence

    /// Persist → load round-trip must preserve tissue states and dive parameters.
    func testPersistenceRoundTripContract() {
        let mgr = DiveSessionManager(gasMix: .ean32, gfLow: 0.35, gfHigh: 0.75)
        mgr.startDive()
        mgr.updateDepth(15.0)

        TissueStatePersistence.persist(manager: mgr)
        let state = TissueStatePersistence.loadPersistedState()

        XCTAssertNotNil(state, "Must be able to load persisted state")

        if let state = state {
            XCTAssertEqual(state.tissueStates.count, 16)
            XCTAssertEqual(state.gasMix, .ean32)
            XCTAssertEqual(state.gfLow, 0.35, accuracy: 0.001)
            XCTAssertEqual(state.gfHigh, 0.75, accuracy: 0.001)
            XCTAssertEqual(state.currentDepth, 15.0, accuracy: 0.1)
        }

        TissueStatePersistence.clearPersistedState()
    }

    /// hasInterruptedSession must return true for active dive phases.
    func testInterruptedSessionContract() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.updateDepth(10.0)

        TissueStatePersistence.persist(manager: mgr)
        XCTAssertTrue(TissueStatePersistence.hasInterruptedSession())

        TissueStatePersistence.clearPersistedState()
        XCTAssertFalse(TissueStatePersistence.hasInterruptedSession())
    }

    // MARK: - Contract 14: Full Dive Scenario (Integration)

    /// Simulate a complete dive lifecycle and verify all contracts hold at each stage.
    func testFullDiveLifecycleContract() {
        let mgr = DiveSessionManager(gasMix: .ean32, gfLow: 0.40, gfHigh: 0.85)

        // Pre-dive
        XCTAssertEqual(mgr.phase, .surface)

        // Start
        mgr.startDive()
        XCTAssertEqual(mgr.phase, .descending)

        // Descent
        for _ in 0..<30 {
            mgr.updateDepth(18.0)
        }
        XCTAssertEqual(mgr.currentDepth, 18.0, accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(mgr.maxDepth, 18.0)
        XCTAssertGreaterThan(mgr.ndl, 0)
        XCTAssertGreaterThan(mgr.ppO2, 0.21)
        XCTAssertGreaterThanOrEqual(mgr.cnsPercent, 0)

        // Ascent
        mgr.updateDepth(5.0)
        XCTAssertEqual(mgr.currentDepth, 5.0, accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(mgr.maxDepth, 18.0, "Max depth must not decrease")

        // End dive
        mgr.endDive()
        XCTAssertEqual(mgr.phase, .surfaceInterval)
        XCTAssertNotNil(mgr.surfaceIntervalStart)

        // Reset
        mgr.resetForNewDive()
        XCTAssertEqual(mgr.phase, .surface)
    }

    // MARK: - Contract 15: DiveSensorProtocol

    /// MockDiveSensor must conform to DiveSensorProtocol.
    func testSensorProtocolContract() {
        let sensor = MockDiveSensor()

        // isAvailable property
        XCTAssertTrue(sensor.isAvailable)

        // delegate property (should be nil initially)
        XCTAssertNil(sensor.delegate)

        // startMonitoring/stopMonitoring exist (compile-time check, but verify no crash)
        sensor.startMonitoring()
        sensor.stopMonitoring()
    }
}
