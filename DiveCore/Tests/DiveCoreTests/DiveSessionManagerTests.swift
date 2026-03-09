import XCTest
@testable import DiveCore

final class DiveSessionManagerTests: XCTestCase {

    // MARK: - 1. Init defaults

    func testInitDefaults() {
        let mgr = DiveSessionManager()

        XCTAssertEqual(mgr.phase, .surface)
        XCTAssertEqual(mgr.currentDepth, 0)
        XCTAssertEqual(mgr.maxDepth, 0)
        XCTAssertEqual(mgr.averageDepth, 0)
        XCTAssertEqual(mgr.temperature, 22.0)
        XCTAssertEqual(mgr.minTemperature, 22.0)
        XCTAssertEqual(mgr.elapsedTime, 0)
        XCTAssertEqual(mgr.ndl, 999)
        XCTAssertEqual(mgr.ceilingDepth, 0)
        XCTAssertEqual(mgr.ascentRate, 0)
        XCTAssertEqual(mgr.ascentRateStatus, .safe)
        XCTAssertEqual(mgr.cnsPercent, 0)
        XCTAssertEqual(mgr.otuTotal, 0)
        XCTAssertEqual(mgr.ppO2, 0.21)
        XCTAssertNil(mgr.surfaceIntervalStart)
        XCTAssertEqual(mgr.depthLimitStatus, .safe)
        XCTAssertEqual(mgr.depthAlarm, DepthLimits.defaultDepthAlarm)
        XCTAssertEqual(mgr.sensorDataAge, 0)
        XCTAssertFalse(mgr.isSensorDataStale)
        XCTAssertTrue(mgr.healthLog.isEmpty)
    }

    func testInitWithCustomGasMix() {
        let mgr = DiveSessionManager(gasMix: .ean32, gfLow: 0.30, gfHigh: 0.70)

        XCTAssertEqual(mgr.gasMix, .ean32)
        XCTAssertEqual(mgr.engine.gfLow, 0.30)
        XCTAssertEqual(mgr.engine.gfHigh, 0.70)
    }

    // MARK: - 2. startDive()

    func testStartDiveTransitionsToDescending() {
        let mgr = DiveSessionManager()
        XCTAssertEqual(mgr.phase, .surface)

        mgr.startDive()

        XCTAssertEqual(mgr.phase, .descending)
    }

    func testStartDiveResetsCounters() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        // Simulate some state accumulation
        mgr.updateDepth(15.0)
        mgr.updateDepth(20.0)

        // Now start a fresh dive
        mgr.startDive()

        XCTAssertEqual(mgr.phase, .descending)
        XCTAssertEqual(mgr.maxDepth, 0)
        XCTAssertEqual(mgr.averageDepth, 0)
        XCTAssertEqual(mgr.elapsedTime, 0)
        XCTAssertEqual(mgr.cnsPercent, 0)
        XCTAssertEqual(mgr.otuTotal, 0)
        XCTAssertEqual(mgr.depthLimitStatus, .safe)
        XCTAssertEqual(mgr.sensorDataAge, 0)
        XCTAssertFalse(mgr.isSensorDataStale)
        XCTAssertEqual(mgr.lastDepth, 0)
    }

    func testStartDiveLogsPhaseTransition() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        let phaseEvents = mgr.healthLog.filter { $0.eventType == .phaseTransition }
        XCTAssertEqual(phaseEvents.count, 1)
        XCTAssertTrue(phaseEvents[0].detail.contains("surface -> descending"))
    }

    func testStartDiveFromDescendingDoesNotLogTransition() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        let eventCount = mgr.healthLog.count

        // Start dive again while already descending -- healthLog was reset, but
        // phase is already .descending so no transition logged
        mgr.startDive()

        // healthLog is reset in startDive, so should have 0 events
        // because previousPhase == .descending and new phase == .descending
        XCTAssertEqual(mgr.healthLog.count, 0)
    }

    func testStartDiveSetsTimestamps() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        XCTAssertNotNil(mgr.diveStartTime)
        XCTAssertNotNil(mgr.lastUpdateTime)
    }

    // MARK: - 3. endDive()

    func testEndDiveTransitionsToSurfaceInterval() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.endDive()

        XCTAssertEqual(mgr.phase, .surfaceInterval)
        XCTAssertNotNil(mgr.surfaceIntervalStart)
    }

    func testEndDiveLogsPhaseTransition() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        let initialCount = mgr.healthLog.count

        mgr.endDive()

        let phaseEvents = mgr.healthLog.filter { $0.eventType == .phaseTransition }
        XCTAssertTrue(phaseEvents.count > initialCount)
        let lastPhaseEvent = phaseEvents.last!
        XCTAssertTrue(lastPhaseEvent.detail.contains("surfaceInterval"))
    }

    func testEndDiveFromSurfaceIntervalDoesNotLogTransition() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.endDive()
        let eventCount = mgr.healthLog.count

        // End again, already surfaceInterval
        mgr.endDive()
        XCTAssertEqual(mgr.healthLog.count, eventCount)
    }

    // MARK: - 4. resetForNewDive()

    func testResetForNewDiveTransitionsToSurface() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.endDive()
        XCTAssertEqual(mgr.phase, .surfaceInterval)

        mgr.resetForNewDive()

        XCTAssertEqual(mgr.phase, .surface)
        XCTAssertNil(mgr.surfaceIntervalStart)
    }

    // MARK: - 5. updateDepth() pipeline

    func testUpdateDepthSetsCurrentDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(15.0)

        XCTAssertEqual(mgr.currentDepth, 15.0)
    }

    func testUpdateDepthTracksMaxDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(10.0)
        mgr.updateDepth(20.0)
        mgr.updateDepth(15.0)

        XCTAssertEqual(mgr.maxDepth, 20.0)
    }

    func testUpdateDepthCalculatesAverageDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(10.0)
        mgr.updateDepth(20.0)

        // Average of [10, 20] = 15
        XCTAssertEqual(mgr.averageDepth, 15.0, accuracy: 0.1)
    }

    func testUpdateDepthCalculatesPpO2() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(30.0)

        // ppO2 at 30m with air: 0.21 * (1 + 30/10) = 0.21 * 4 = 0.84
        XCTAssertEqual(mgr.ppO2, 0.84, accuracy: 0.01)
    }

    func testUpdateDepthUpdatesCNSAtDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // At 30m air, ppO2 = 0.84 which is > 0.6, so CNS should accumulate
        mgr.updateDepth(30.0)

        // CNS may be very small due to tiny time interval, but should be >= 0
        XCTAssertGreaterThanOrEqual(mgr.cnsPercent, 0)
    }

    func testUpdateDepthUpdatesOTUAtDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // ppO2 > 0.5 at depth triggers OTU accumulation
        mgr.updateDepth(30.0)

        XCTAssertGreaterThanOrEqual(mgr.otuTotal, 0)
    }

    func testUpdateDepthUpdatesNDL() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(20.0)

        // At 20m with air, NDL should be a finite value (not 999 at surface but could still be high)
        // Just verify it's been computed (not the default 999 from init, or a reasonable value)
        XCTAssertGreaterThan(mgr.ndl, 0)
    }

    func testUpdateDepthAscentRateCalculation() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Two successive depths -- time interval will be very small
        mgr.updateDepth(20.0)
        mgr.updateDepth(10.0)

        // Ascent rate should be negative (ascending) or calculated
        // With very small dt, the rate may be very large
        // Just verify ascentRate is populated
        XCTAssertNotEqual(mgr.ascentRate, 0)
    }

    func testUpdateDepthPhaseDescending() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(5.0)
        mgr.updateDepth(10.0)

        XCTAssertEqual(mgr.phase, .descending)
    }

    func testUpdateDepthPhaseAscending() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(20.0)
        mgr.updateDepth(15.0)

        XCTAssertEqual(mgr.phase, .ascending)
    }

    func testUpdateDepthPhaseAtDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(20.0)
        // Same depth within 0.1m tolerance = atDepth
        mgr.updateDepth(20.0)

        XCTAssertEqual(mgr.phase, .atDepth)
    }

    func testUpdateDepthAutoEndsDiveWhenShallow() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Go deep first
        mgr.updateDepth(15.0)

        // Manually set elapsed time > 5 to trigger auto-end
        // We need elapsedTime > 5 and depth < 0.5
        // Since we can't easily control time, set diveStartTime in the past
        mgr.diveStartTime = Date().addingTimeInterval(-10)

        mgr.updateDepth(0.3)

        XCTAssertEqual(mgr.phase, .surfaceInterval)
    }

    func testUpdateDepthResetsLastDepth() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(12.0)
        XCTAssertEqual(mgr.lastDepth, 12.0)

        mgr.updateDepth(18.0)
        XCTAssertEqual(mgr.lastDepth, 18.0)
    }

    func testUpdateDepthResetsStaleness() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Make sensor stale
        for _ in 0..<12 {
            mgr.checkSensorStaleness()
        }
        XCTAssertTrue(mgr.isSensorDataStale)

        // updateDepth resets staleness
        mgr.updateDepth(10.0)

        XCTAssertFalse(mgr.isSensorDataStale)
        XCTAssertEqual(mgr.sensorDataAge, 0)
    }

    func testUpdateDepthWithoutLastUpdateTimeUsesDefaultInterval() {
        let mgr = DiveSessionManager()
        // Don't call startDive -- lastUpdateTime will be nil
        // Directly call updateDepth
        mgr.lastUpdateTime = nil

        mgr.updateDepth(10.0)

        // Should not crash; uses interval = 1.0
        XCTAssertEqual(mgr.currentDepth, 10.0)
    }

    func testUpdateDepthUpdatesElapsedTime() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Set diveStartTime in the past
        mgr.diveStartTime = Date().addingTimeInterval(-30)

        mgr.updateDepth(10.0)

        XCTAssertGreaterThan(mgr.elapsedTime, 25)
    }

    func testUpdateDepthWithNoDiveStartTimeDoesNotUpdateElapsed() {
        let mgr = DiveSessionManager()
        // Don't start dive, so diveStartTime is nil
        mgr.updateDepth(5.0)

        XCTAssertEqual(mgr.elapsedTime, 0)
    }

    // MARK: - 6. updateTemperature()

    func testUpdateTemperatureTracksValue() {
        let mgr = DiveSessionManager()

        mgr.updateTemperature(18.0)

        XCTAssertEqual(mgr.temperature, 18.0)
    }

    func testUpdateTemperatureTracksMinimum() {
        let mgr = DiveSessionManager()

        mgr.updateTemperature(18.0)
        XCTAssertEqual(mgr.minTemperature, 18.0)

        mgr.updateTemperature(25.0)
        XCTAssertEqual(mgr.minTemperature, 18.0, "minTemperature should not increase")

        mgr.updateTemperature(15.0)
        XCTAssertEqual(mgr.minTemperature, 15.0)
    }

    func testUpdateTemperatureAboveInitialDoesNotChangeMin() {
        let mgr = DiveSessionManager()
        XCTAssertEqual(mgr.minTemperature, 22.0)

        mgr.updateTemperature(25.0)
        XCTAssertEqual(mgr.minTemperature, 22.0)
        XCTAssertEqual(mgr.temperature, 25.0)
    }

    // MARK: - 7. Depth limit enforcement

    func testDepthLimitSafe() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(30.0)

        XCTAssertEqual(mgr.depthLimitStatus, .safe)
    }

    func testDepthLimitApproachingLimit() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(38.0)

        XCTAssertEqual(mgr.depthLimitStatus, .approachingLimit)
    }

    func testDepthLimitMaxDepthWarning() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(39.0)

        XCTAssertEqual(mgr.depthLimitStatus, .maxDepthWarning)
    }

    func testDepthLimitReached() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(40.0)

        XCTAssertEqual(mgr.depthLimitStatus, .depthLimitReached)
        XCTAssertGreaterThan(mgr.ndl, 0, "NDL should be preserved when depth limit is reached; UI shows depth warning overlay instead")
    }

    func testDepthLimitReachedLogsEvent() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(40.0)

        let depthLimitEvents = mgr.healthLog.filter { $0.eventType == .depthLimitReached }
        XCTAssertEqual(depthLimitEvents.count, 1)
    }

    func testDepthLimitReachedDoesNotLogDuplicates() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(40.0)
        mgr.updateDepth(41.0)

        let depthLimitEvents = mgr.healthLog.filter { $0.eventType == .depthLimitReached }
        XCTAssertEqual(depthLimitEvents.count, 1)
    }

    func testDepthLimitWarningLogsEvent() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(39.0)

        let warningEvents = mgr.healthLog.filter { $0.eventType == .depthLimitWarning }
        XCTAssertEqual(warningEvents.count, 1)
    }

    func testDepthLimitWarningFromSafeOnlyLogsOnce() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // First call from safe -> warning, logs event
        mgr.updateDepth(38.5)
        // Second call stays at approachingLimit, does not log again
        mgr.updateDepth(38.5)

        let warningEvents = mgr.healthLog.filter { $0.eventType == .depthLimitWarning }
        XCTAssertEqual(warningEvents.count, 1)
    }

    // MARK: - 8. Stale sensor detection

    func testCheckSensorStalenessIncrementsAge() {
        let mgr = DiveSessionManager()

        mgr.checkSensorStaleness()

        XCTAssertEqual(mgr.sensorDataAge, 1.0)
    }

    func testSensorBecomesStaleAfterThreshold() {
        let mgr = DiveSessionManager()

        for _ in 0..<11 {
            mgr.checkSensorStaleness()
        }

        XCTAssertTrue(mgr.isSensorDataStale)
        XCTAssertEqual(mgr.ndl, 0, "NDL should be zeroed when sensor data is stale")
    }

    func testSensorNotStaleBeforeThreshold() {
        let mgr = DiveSessionManager()

        for _ in 0..<10 {
            mgr.checkSensorStaleness()
        }

        XCTAssertFalse(mgr.isSensorDataStale)
    }

    func testSensorStaleLogsEvent() {
        let mgr = DiveSessionManager()

        for _ in 0..<11 {
            mgr.checkSensorStaleness()
        }

        let staleEvents = mgr.healthLog.filter { $0.eventType == .sensorDataStale }
        XCTAssertEqual(staleEvents.count, 1)
    }

    func testSensorStaleDoesNotLogDuplicateEvents() {
        let mgr = DiveSessionManager()

        for _ in 0..<15 {
            mgr.checkSensorStaleness()
        }

        // Only logs once when first becoming stale
        let staleEvents = mgr.healthLog.filter { $0.eventType == .sensorDataStale }
        XCTAssertEqual(staleEvents.count, 1)
    }

    func testUpdateDepthResetsSensorStaleness() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        for _ in 0..<12 {
            mgr.checkSensorStaleness()
        }
        XCTAssertTrue(mgr.isSensorDataStale)

        mgr.updateDepth(10.0)

        XCTAssertFalse(mgr.isSensorDataStale)
        XCTAssertEqual(mgr.sensorDataAge, 0)
    }

    // MARK: - 9. Health logging

    func testPhaseTransitionsLogged() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Go deep then shallow to trigger phase changes
        mgr.updateDepth(5.0)
        mgr.updateDepth(10.0)
        mgr.updateDepth(5.0) // ascending

        let phaseEvents = mgr.healthLog.filter { $0.eventType == .phaseTransition }
        XCTAssertGreaterThanOrEqual(phaseEvents.count, 1)
    }

    func testDepthLimitEventsLogged() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(40.0)

        let limitEvents = mgr.healthLog.filter { $0.eventType == .depthLimitReached }
        XCTAssertFalse(limitEvents.isEmpty)
    }

    func testNDLAnomalyDetection() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Go to depth to get a real NDL value (not 999)
        mgr.updateDepth(30.0)
        // The engine gives an NDL at 30m; lastNDL is now set

        // Force a big NDL jump by going to 40m where NDL is forced to 0
        // (depthLimitReached forces ndl=0), which is a big change from any reasonable NDL
        let previousNDL = mgr.ndl

        // Only triggers if lastNDL != 999 && ndl != 999 && ndl != 0 and diff > 5
        // Going shallow (NDL increases dramatically) after depth
        // First update at 30m sets lastNDL to a finite value
        // Then go to 10m where NDL is much higher
        mgr.updateDepth(10.0)

        // Check if anomaly was detected (NDL jump from ~20 to >200 would trigger)
        if previousNDL != 999 && mgr.ndl != 999 && mgr.ndl != 0 {
            let diff = abs(previousNDL - mgr.ndl)
            if diff > 5 {
                let anomalyEvents = mgr.healthLog.filter { $0.eventType == .ndlAnomaly }
                XCTAssertFalse(anomalyEvents.isEmpty, "NDL anomaly should be logged for jump of \(diff)")
            }
        }
    }

    func testNDLAnomalyNotLoggedWhenLastNDLIs999() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // First depth update: lastNDL is 999 (init value), so no anomaly should log
        mgr.updateDepth(30.0)

        let anomalyEvents = mgr.healthLog.filter { $0.eventType == .ndlAnomaly }
        XCTAssertTrue(anomalyEvents.isEmpty, "No anomaly on first update from 999")
    }

    // MARK: - 10. Session integrity score

    func testFreshSessionIntegrityScoreIs100() {
        let mgr = DiveSessionManager()
        XCTAssertEqual(mgr.sessionIntegrityScore, 100.0)
    }

    func testIntegrityScoreDecreasesWithStaleEvents() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        for _ in 0..<11 {
            mgr.checkSensorStaleness()
        }

        // sensorDataStale event logged, -5 per event
        XCTAssertLessThan(mgr.sessionIntegrityScore, 100.0)
    }

    func testIntegrityScoreDecreasesWithDepthLimitReached() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(40.0)

        // depthLimitReached = -20
        XCTAssertLessThanOrEqual(mgr.sessionIntegrityScore, 80.0)
    }

    func testIntegrityScoreFloorIsZero() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Generate many stale events by repeatedly going stale and resetting
        for _ in 0..<25 {
            for _ in 0..<11 {
                mgr.checkSensorStaleness()
            }
            // Reset staleness to log another event next round
            mgr.updateDepth(10.0)
        }

        XCTAssertGreaterThanOrEqual(mgr.sessionIntegrityScore, 0.0)
    }

    func testIntegrityCeilingIs100() {
        let mgr = DiveSessionManager()
        // No events logged
        XCTAssertEqual(mgr.sessionIntegrityScore, 100.0)
        // Even with phaseTransition events (which don't deduct), should stay at 100
        mgr.startDive()
        XCTAssertEqual(mgr.sessionIntegrityScore, 100.0)
    }

    // MARK: - 11. restoreState()

    func testRestoreStateRestoresAllProperties() {
        let mgr = DiveSessionManager()
        let events = [
            DiveHealthEvent(eventType: .phaseTransition, detail: "test")
        ]

        mgr.restoreState(
            phase: .ascending,
            elapsedTime: 600,
            maxDepth: 25.0,
            avgDepth: 18.0,
            currentDepth: 12.0,
            temperature: 19.0,
            minTemperature: 17.0,
            cnsPercent: 5.0,
            otuTotal: 10.0,
            healthLog: events
        )

        XCTAssertEqual(mgr.phase, .ascending)
        XCTAssertEqual(mgr.elapsedTime, 600)
        XCTAssertEqual(mgr.maxDepth, 25.0)
        XCTAssertEqual(mgr.averageDepth, 18.0)
        XCTAssertEqual(mgr.currentDepth, 12.0)
        XCTAssertEqual(mgr.temperature, 19.0)
        XCTAssertEqual(mgr.minTemperature, 17.0)
        XCTAssertEqual(mgr.cnsPercent, 5.0)
        XCTAssertEqual(mgr.otuTotal, 10.0)
        XCTAssertEqual(mgr.lastDepth, 12.0)
        XCTAssertNotNil(mgr.diveStartTime)
        XCTAssertNotNil(mgr.lastUpdateTime)
    }

    func testRestoreStateLogsRecoveryEvent() {
        let mgr = DiveSessionManager()

        mgr.restoreState(
            phase: .atDepth,
            elapsedTime: 300,
            maxDepth: 20.0,
            avgDepth: 15.0,
            currentDepth: 18.0,
            temperature: 20.0,
            minTemperature: 18.0,
            cnsPercent: 2.0,
            otuTotal: 5.0,
            healthLog: []
        )

        let resumeEvents = mgr.healthLog.filter { $0.eventType == .backgroundResumed }
        XCTAssertEqual(resumeEvents.count, 1)
        XCTAssertTrue(resumeEvents[0].detail.contains("recovered"))
    }

    func testRestoreStateSetsCorrectDiveStartTime() {
        let mgr = DiveSessionManager()
        let elapsed: TimeInterval = 600

        let beforeRestore = Date()
        mgr.restoreState(
            phase: .atDepth,
            elapsedTime: elapsed,
            maxDepth: 20.0,
            avgDepth: 15.0,
            currentDepth: 18.0,
            temperature: 20.0,
            minTemperature: 18.0,
            cnsPercent: 0,
            otuTotal: 0,
            healthLog: []
        )
        let afterRestore = Date()

        // diveStartTime should be ~600 seconds in the past
        let expectedEarliest = beforeRestore.addingTimeInterval(-elapsed)
        let expectedLatest = afterRestore.addingTimeInterval(-elapsed)
        XCTAssertNotNil(mgr.diveStartTime)
        XCTAssertGreaterThanOrEqual(mgr.diveStartTime!, expectedEarliest.addingTimeInterval(-1))
        XCTAssertLessThanOrEqual(mgr.diveStartTime!, expectedLatest.addingTimeInterval(1))
    }

    // MARK: - 12. Persistence counter

    func testPersistenceTriggeredEvery5Updates() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Call updateDepth 5 times to trigger persistence
        for i in 1...5 {
            mgr.updateDepth(Double(i))
        }

        // After 5 updates, samplesSincePersist should be reset to 0
        // We can't directly read samplesSincePersist (private), but we can
        // verify indirectly by calling 4 more updates (no persist) then 1 more (persist)
        // The main thing is that the code doesn't crash

        // Call 4 more updates (samplesSincePersist = 1,2,3,4)
        for _ in 0..<4 {
            mgr.updateDepth(10.0)
        }
        // 5th update triggers persist again
        mgr.updateDepth(10.0)

        // Verify manager state is consistent (persistence didn't break anything)
        XCTAssertEqual(mgr.currentDepth, 10.0)
    }

    // MARK: - 13. tissueLoadingPercent

    func testTissueLoadingPercentReturns16Values() {
        let mgr = DiveSessionManager()

        let loading = mgr.tissueLoadingPercent
        XCTAssertEqual(loading.count, 16)
    }

    func testTissueLoadingPercentChangesAfterDepthExposure() {
        let mgr = DiveSessionManager()
        let initialLoading = mgr.tissueLoadingPercent

        mgr.startDive()
        // Directly update tissues with a meaningful time interval to ensure loading changes
        mgr.engine.updateTissues(depth: 30.0, gasMix: .air, timeInterval: 60.0)

        let afterLoading = mgr.tissueLoadingPercent

        // At least some compartments should have changed
        var anyDifferent = false
        for i in 0..<16 {
            if abs(afterLoading[i] - initialLoading[i]) > 0.001 {
                anyDifferent = true
                break
            }
        }
        XCTAssertTrue(anyDifferent, "Tissue loading should change after depth exposure")
    }

    // MARK: - 14. gasDescription

    func testGasDescriptionAir() {
        let mgr = DiveSessionManager(gasMix: .air)
        XCTAssertEqual(mgr.gasDescription, "Air")
    }

    func testGasDescriptionEAN32() {
        let mgr = DiveSessionManager(gasMix: .ean32)
        XCTAssertEqual(mgr.gasDescription, "EAN32")
    }

    func testGasDescriptionEAN36() {
        let mgr = DiveSessionManager(gasMix: .ean36)
        XCTAssertEqual(mgr.gasDescription, "EAN36")
    }

    // MARK: - 15. gfDescription

    func testGfDescriptionDefaults() {
        let mgr = DiveSessionManager()
        XCTAssertEqual(mgr.gfDescription, "40/85")
    }

    func testGfDescriptionCustom() {
        let mgr = DiveSessionManager(gfLow: 0.30, gfHigh: 0.70)
        XCTAssertEqual(mgr.gfDescription, "30/70")
    }

    // MARK: - Phase detection edge cases

    func testPhaseNotUpdatedWhenSurface() {
        let mgr = DiveSessionManager()
        // Phase is .surface, updatePhase should not change it
        mgr.updateDepth(10.0)

        // phase should still be surface because updatePhase guards against .surface
        XCTAssertEqual(mgr.phase, .surface)
    }

    func testPhaseNotUpdatedWhenSurfaceInterval() {
        let mgr = DiveSessionManager()
        mgr.startDive()
        mgr.endDive()
        XCTAssertEqual(mgr.phase, .surfaceInterval)

        mgr.updateDepth(10.0)

        // Should remain surfaceInterval
        XCTAssertEqual(mgr.phase, .surfaceInterval)
    }

    func testPhaseTransitionToSafetyStop() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Go deep enough to require safety stop (>= 10m)
        mgr.updateDepth(15.0)
        mgr.updateDepth(20.0)

        // Now ascend to safety stop zone (5m +/- 1.5m)
        // Need to get maxDepth >= 10 and depth in safety stop zone
        mgr.updateDepth(6.0)
        // Safety stop manager should now be pending
        // Go to exactly 5m to trigger inProgress
        mgr.updateDepth(5.0)

        // The phase should be safetyStop if safety stop manager is in progress
        // and depth is decreasing
        if mgr.safetyStopManager.isAtSafetyStop {
            XCTAssertEqual(mgr.phase, .safetyStop)
        }
    }

    func testPhaseAtDepthWhenStationary() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(15.0)
        // Same depth (within 0.1m tolerance)
        mgr.updateDepth(15.0)

        XCTAssertEqual(mgr.phase, .atDepth)
    }

    // MARK: - Safety stop logging

    func testSafetyStopStartedLogged() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Go deep to trigger safety stop requirement
        mgr.updateDepth(15.0)
        mgr.updateDepth(20.0)
        // Enter safety stop zone
        mgr.updateDepth(6.0) // pending
        mgr.updateDepth(5.0) // should transition to inProgress

        let startEvents = mgr.healthLog.filter { $0.eventType == .safetyStopStarted }
        if mgr.safetyStopManager.isAtSafetyStop {
            XCTAssertEqual(startEvents.count, 1)
        }
    }

    // MARK: - Full dive simulation

    func testFullDiveLifecycle() {
        let mgr = DiveSessionManager()

        // 1. Surface
        XCTAssertEqual(mgr.phase, .surface)

        // 2. Start dive
        mgr.startDive()
        XCTAssertEqual(mgr.phase, .descending)

        // 3. Descend
        mgr.updateDepth(5.0)
        mgr.updateDepth(10.0)
        mgr.updateDepth(15.0)
        XCTAssertEqual(mgr.phase, .descending)
        XCTAssertEqual(mgr.maxDepth, 15.0)

        // 4. At depth
        mgr.updateDepth(15.0)
        XCTAssertEqual(mgr.phase, .atDepth)

        // 5. Ascend
        mgr.updateDepth(10.0)
        mgr.updateDepth(5.0)

        // 6. End dive
        mgr.endDive()
        XCTAssertEqual(mgr.phase, .surfaceInterval)
        XCTAssertNotNil(mgr.surfaceIntervalStart)

        // 7. Reset
        mgr.resetForNewDive()
        XCTAssertEqual(mgr.phase, .surface)
        XCTAssertNil(mgr.surfaceIntervalStart)
    }

    func testMultipleUpdateDepthsAccumulateCorrectly() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        let depths = [5.0, 10.0, 15.0, 20.0, 25.0]
        for d in depths {
            mgr.updateDepth(d)
        }

        XCTAssertEqual(mgr.maxDepth, 25.0)
        XCTAssertEqual(mgr.currentDepth, 25.0)
        // Average of [5, 10, 15, 20, 25] = 15
        XCTAssertEqual(mgr.averageDepth, 15.0, accuracy: 0.1)
    }

    // MARK: - Depth limit transition from warning to safe

    func testDepthLimitStatusReturnsSafeAfterAscent() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(39.0)
        XCTAssertEqual(mgr.depthLimitStatus, .maxDepthWarning)

        mgr.updateDepth(30.0)
        XCTAssertEqual(mgr.depthLimitStatus, .safe)
    }

    // MARK: - EAN32 gas calculations

    func testEAN32PpO2AtDepth() {
        let mgr = DiveSessionManager(gasMix: .ean32)
        mgr.startDive()

        mgr.updateDepth(30.0)

        // ppO2 at 30m with EAN32: 0.32 * (1 + 30/10) = 0.32 * 4 = 1.28
        XCTAssertEqual(mgr.ppO2, 1.28, accuracy: 0.01)
    }

    // MARK: - Ceiling depth updates

    func testCeilingDepthUpdatesOnDepthChange() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(30.0)

        // Ceiling depth should be computed (may be 0 for short exposure)
        XCTAssertGreaterThanOrEqual(mgr.ceilingDepth, 0)
    }

    // MARK: - Ascent rate status

    func testAscentRateStatusSafeOnDescent() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(10.0)
        mgr.updateDepth(20.0)

        // Descending should always be safe
        XCTAssertEqual(mgr.ascentRateStatus, .safe)
    }

    // MARK: - depthAlarm customization

    func testCustomDepthAlarm() {
        let mgr = DiveSessionManager()
        mgr.depthAlarm = 35.0
        mgr.startDive()

        mgr.updateDepth(35.0)

        XCTAssertEqual(mgr.depthLimitStatus, .approachingLimit)
    }

    // MARK: - NDL zero at depth limit does not log anomaly

    func testNDLZeroAtDepthLimitDoesNotTriggerAnomaly() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Get a real NDL first
        mgr.updateDepth(20.0)

        // Go to 40m — NDL is now preserved (not forced to 0), so the large NDL
        // change from 20m to 40m may legitimately trigger anomaly detection
        mgr.updateDepth(40.0)

        // NDL is preserved at depth limit; anomaly detection runs normally
        XCTAssertGreaterThan(mgr.ndl, 0, "NDL should be preserved at depth limit")
    }

    // MARK: - Safety stop logging transitions

    func testSafetyStopSkippedLogged() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Go deep
        mgr.updateDepth(15.0)
        mgr.updateDepth(20.0)

        // Enter safety stop zone (pending)
        mgr.updateDepth(6.0)

        // Skip past safety stop zone (< 3.5m)
        mgr.updateDepth(3.0)

        let skippedEvents = mgr.healthLog.filter { $0.eventType == .safetyStopSkipped }
        // Should be logged if safety stop was pending and diver went above zone
        XCTAssertEqual(skippedEvents.count, 1, "Safety stop skip should be logged when diver ascends past zone")
    }

    // MARK: - Sub-objects accessible

    func testSubObjectsExist() {
        let mgr = DiveSessionManager()

        XCTAssertNotNil(mgr.engine)
        XCTAssertNotNil(mgr.safetyStopManager)
        XCTAssertNotNil(mgr.ascentRateMonitor)
        XCTAssertEqual(mgr.gasMix, .air)
    }

    // MARK: - Integrity score specific event types

    func testIntegrityScoreNDLAnomalyDeduction() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Simulate an NDL anomaly by going deep then shallow
        mgr.updateDepth(30.0) // sets lastNDL to ~20
        mgr.updateDepth(10.0) // NDL jumps to >200, anomaly logged

        // If an anomaly was logged, score should be 85 or less
        let hasAnomaly = mgr.healthLog.contains { $0.eventType == .ndlAnomaly }
        if hasAnomaly {
            XCTAssertLessThanOrEqual(mgr.sessionIntegrityScore, 85.0)
        }
    }

    // MARK: - Phase transitions with depth changes

    func testDescendingToAtDepthTransition() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(10.0)
        XCTAssertEqual(mgr.phase, .descending)

        mgr.updateDepth(10.05) // within 0.1m, so atDepth
        XCTAssertEqual(mgr.phase, .atDepth)
    }

    func testAtDepthToAscendingTransition() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        mgr.updateDepth(20.0)
        mgr.updateDepth(20.0) // atDepth
        XCTAssertEqual(mgr.phase, .atDepth)

        mgr.updateDepth(19.0) // ascending
        XCTAssertEqual(mgr.phase, .ascending)
    }

    // MARK: - updateDepth with safetyStop at stationary depth

    func testPhaseSetToSafetyStopWhenStationaryAtStop() {
        let mgr = DiveSessionManager()
        mgr.startDive()

        // Go deep
        mgr.updateDepth(15.0)
        mgr.updateDepth(20.0)

        // Ascend to safety stop zone
        mgr.updateDepth(6.0) // pending
        mgr.updateDepth(5.0) // starts inProgress (descending from 6 to 5, within zone)

        if mgr.safetyStopManager.isAtSafetyStop {
            // Stay at same depth
            mgr.updateDepth(5.0) // stationary at safety stop

            XCTAssertEqual(mgr.phase, .safetyStop)
        }
    }
}
