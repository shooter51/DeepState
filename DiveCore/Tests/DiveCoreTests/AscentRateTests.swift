import XCTest
@testable import DiveCore

final class AscentRateTests: XCTestCase {

    func testNormalAscentRate() {
        let monitor = AscentRateMonitor()
        // 9m/min = ascending 9m in 60 seconds
        let result = monitor.evaluate(previousDepth: 20.0, currentDepth: 11.0, timeInterval: 60.0)
        XCTAssertEqual(result.rate, 9.0, accuracy: 0.1)
        XCTAssertEqual(result.status, .safe, "9m/min should be safe")
    }

    func testWarningAscentRate() {
        let monitor = AscentRateMonitor()
        // 12m/min = ascending 12m in 60 seconds
        let result = monitor.evaluate(previousDepth: 30.0, currentDepth: 18.0, timeInterval: 60.0)
        XCTAssertEqual(result.rate, 12.0, accuracy: 0.1)
        XCTAssertEqual(result.status, .warning, "12m/min should be warning")
    }

    func testCriticalAscentRate() {
        let monitor = AscentRateMonitor()
        // 18m/min = ascending 18m in 60 seconds
        let result = monitor.evaluate(previousDepth: 30.0, currentDepth: 12.0, timeInterval: 60.0)
        XCTAssertEqual(result.rate, 18.0, accuracy: 0.1)
        XCTAssertEqual(result.status, .critical, "18m/min should be critical")
    }

    func testDescentIsSafe() {
        let monitor = AscentRateMonitor()
        // Descending 15m in 60 seconds
        let result = monitor.evaluate(previousDepth: 10.0, currentDepth: 25.0, timeInterval: 60.0)
        XCTAssertEqual(result.status, .safe, "Descending should always be safe")
    }

    func testZeroTimeIntervalIsSafe() {
        let monitor = AscentRateMonitor()
        let result = monitor.evaluate(previousDepth: 20.0, currentDepth: 10.0, timeInterval: 0.0)
        XCTAssertEqual(result.rate, 0.0)
        XCTAssertEqual(result.status, .safe)
    }
}
