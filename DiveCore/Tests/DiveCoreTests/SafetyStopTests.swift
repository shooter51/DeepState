import XCTest
@testable import DiveCore

final class SafetyStopTests: XCTestCase {

    func testSafetyStopRequiredAfterDeepDive() {
        let manager = SafetyStopManager()

        // Simulate ascending from a dive deeper than 10m
        // First trigger: maxDepth >= minimumDepthForStop and depth enters stop zone
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)

        XCTAssertTrue(manager.safetyStopRequired,
                      "Safety stop should be required after dive > 10m")
    }

    func testSafetyStopNotRequiredShallowDive() {
        let manager = SafetyStopManager()

        manager.update(currentDepth: 5.0, maxDepth: 8.0, timeInterval: 1.0)

        XCTAssertFalse(manager.safetyStopRequired,
                       "Safety stop should not be required for shallow dive < 10m")
    }

    func testSafetyStopCountdown() {
        let manager = SafetyStopManager()

        // First update: notRequired -> pending
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)

        // Second update: pending -> inProgress (starts the timer at full duration)
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)

        XCTAssertTrue(manager.isAtSafetyStop, "Should be at safety stop")

        // Third update: inProgress, counting down
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 10.0)

        XCTAssertTrue(manager.isAtSafetyStop, "Should still be at safety stop")
        XCTAssertLessThan(manager.remainingTime, 180.0,
                          "Timer should be counting down")
    }

    func testSafetyStopPausesWhenTooDeep() {
        let manager = SafetyStopManager()

        // First: notRequired -> pending
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)
        // Second: pending -> inProgress
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)

        XCTAssertTrue(manager.isAtSafetyStop, "Should be at safety stop initially")

        // Go too deep (beyond tolerance)
        manager.update(currentDepth: 8.0, maxDepth: 20.0, timeInterval: 5.0)

        XCTAssertFalse(manager.isAtSafetyStop,
                       "Should not be at safety stop when too deep")
    }

    func testSafetyStopCompletion() {
        let manager = SafetyStopManager()

        // First update: notRequired -> pending
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)

        // Second update: pending -> inProgress
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 1.0)

        // Third update: stay at 5m for full duration
        manager.update(currentDepth: 5.0, maxDepth: 20.0, timeInterval: 180.0)

        if case .completed = manager.state {
            // Expected
        } else {
            XCTFail("Safety stop should be completed after 180 seconds at 5m, got state: \(manager.state)")
        }
    }
}
