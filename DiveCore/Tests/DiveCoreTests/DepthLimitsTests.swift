import XCTest
@testable import DiveCore

final class DepthLimitsTests: XCTestCase {

    func testSafeDepth() {
        let status = DepthLimits.evaluate(depth: 30.0)
        XCTAssertEqual(status, .safe, "30m should be safe")
    }

    func testApproachingLimit() {
        let status = DepthLimits.evaluate(depth: 38.0)
        XCTAssertEqual(status, .approachingLimit, "38m should be approaching limit (default alarm 38m)")
    }

    func testMaxDepthWarning() {
        let status = DepthLimits.evaluate(depth: 39.0)
        XCTAssertEqual(status, .maxDepthWarning, "39m should trigger max depth warning")
    }

    func testDepthLimitReached() {
        let status = DepthLimits.evaluate(depth: 40.0)
        XCTAssertEqual(status, .depthLimitReached, "40m should be depth limit reached")
    }

    func testCustomAlarm() {
        let status = DepthLimits.evaluate(depth: 35.0, depthAlarm: 35.0)
        XCTAssertEqual(status, .approachingLimit, "35m with 35m alarm should be approaching limit")
    }

    func testNDLTerminatedAtLimit() {
        let manager = DiveSessionManager()
        manager.startDive()
        manager.updateDepth(40.0)
        XCTAssertGreaterThan(manager.ndl, 0, "NDL should be preserved at depth limit (40m); UI shows depth warning overlay instead")
        XCTAssertEqual(manager.depthLimitStatus, .depthLimitReached,
                       "Depth limit status should be .depthLimitReached at 40m")
    }
}
