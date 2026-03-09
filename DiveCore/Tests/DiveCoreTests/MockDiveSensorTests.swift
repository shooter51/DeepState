import XCTest
@testable import DiveCore

/// Mock delegate to capture sensor callbacks
private class TestSensorDelegate: DiveSensorDelegate {
    var depthUpdates: [(depth: Double, temperature: Double?)] = []
    var submersionChanges: [Bool] = []
    var errors: [Error] = []

    var depthExpectation: XCTestExpectation?
    var submersionExpectation: XCTestExpectation?

    /// Track how many fulfills are expected so we don't over-fulfill
    private var submersionFulfillCount = 0
    private var submersionMaxFulfills = 1

    func setSubmersionExpectation(_ exp: XCTestExpectation, maxFulfills: Int = 1) {
        submersionExpectation = exp
        submersionFulfillCount = 0
        submersionMaxFulfills = maxFulfills
    }

    func didUpdateDepth(_ depth: Double, temperature: Double?) {
        depthUpdates.append((depth: depth, temperature: temperature))
        depthExpectation?.fulfill()
    }

    func didChangeSubmersionState(_ submerged: Bool) {
        submersionChanges.append(submerged)
        if submersionFulfillCount < submersionMaxFulfills {
            submersionExpectation?.fulfill()
            submersionFulfillCount += 1
        }
    }

    func didEncounterError(_ error: Error) {
        errors.append(error)
    }
}

final class MockDiveSensorTests: XCTestCase {

    func testIsAvailable() {
        let sensor = MockDiveSensor()
        XCTAssertTrue(sensor.isAvailable, "MockDiveSensor should always be available")
    }

    func testDelegateReceivesSubmersionOnStart() {
        let sensor = MockDiveSensor()
        let delegate = TestSensorDelegate()
        let expectation = self.expectation(description: "Submersion state change")
        expectation.assertForOverFulfill = false
        delegate.setSubmersionExpectation(expectation, maxFulfills: 1)

        sensor.delegate = delegate
        sensor.startMonitoring()

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(delegate.submersionChanges.first, true,
                       "Starting monitoring should report submerged = true")

        sensor.stopMonitoring()
    }

    func testDelegateReceivesDepthUpdates() {
        let sensor = MockDiveSensor()
        let delegate = TestSensorDelegate()
        let expectation = self.expectation(description: "Depth updates")
        expectation.expectedFulfillmentCount = 3

        delegate.depthExpectation = expectation
        sensor.delegate = delegate
        sensor.startMonitoring()

        wait(for: [expectation], timeout: 5.0)

        XCTAssertGreaterThanOrEqual(delegate.depthUpdates.count, 3,
                                     "Should receive at least 3 depth updates")

        sensor.stopMonitoring()
    }

    func testDepthInterpolationAtTimeZero() {
        // At time 0, depth should be 0 (surface)
        // We can verify indirectly: on first tick (1s), depth should be very small
        let sensor = MockDiveSensor()
        let delegate = TestSensorDelegate()
        let expectation = self.expectation(description: "First depth update")
        delegate.depthExpectation = expectation

        sensor.delegate = delegate
        sensor.startMonitoring()

        wait(for: [expectation], timeout: 3.0)

        // At t=1s, interpolating between (0,0) and (120,18): depth = 18 * 1/120 = 0.15m
        if let first = delegate.depthUpdates.first {
            XCTAssertLessThan(first.depth, 1.0,
                              "Depth at ~1s should be very small (near surface)")
            XCTAssertGreaterThanOrEqual(first.depth, 0.0,
                                         "Depth should not be negative")
        }

        sensor.stopMonitoring()
    }

    func testTemperatureAtSurface() {
        // At very shallow depth (~0m), temperature should be near 28 degrees
        let sensor = MockDiveSensor()
        let delegate = TestSensorDelegate()
        let expectation = self.expectation(description: "Temp at surface")
        delegate.depthExpectation = expectation

        sensor.delegate = delegate
        sensor.startMonitoring()

        wait(for: [expectation], timeout: 3.0)

        if let first = delegate.depthUpdates.first, let temp = first.temperature {
            // At ~0.15m depth, temp should be very close to 28
            XCTAssertGreaterThan(temp, 27.0, "Temperature near surface should be close to 28")
            XCTAssertLessThanOrEqual(temp, 28.0, "Temperature should not exceed 28 at surface")
        }

        sensor.stopMonitoring()
    }

    func testStopMonitoringCallsSubmersionFalse() {
        let sensor = MockDiveSensor()
        let delegate = TestSensorDelegate()

        // First expect the start submersion
        let startExpectation = self.expectation(description: "Start submersion")
        delegate.setSubmersionExpectation(startExpectation, maxFulfills: 1)
        sensor.delegate = delegate
        sensor.startMonitoring()
        wait(for: [startExpectation], timeout: 1.0)

        // Now expect the stop submersion
        let stopExpectation = self.expectation(description: "Stop submersion")
        delegate.setSubmersionExpectation(stopExpectation, maxFulfills: 1)
        sensor.stopMonitoring()
        wait(for: [stopExpectation], timeout: 1.0)

        XCTAssertEqual(delegate.submersionChanges.last, false,
                       "Stopping monitoring should report submerged = false")
    }

    func testStopMonitoringStopsDepthUpdates() {
        let sensor = MockDiveSensor()
        let delegate = TestSensorDelegate()
        let expectation = self.expectation(description: "Initial depth updates")
        expectation.expectedFulfillmentCount = 2
        delegate.depthExpectation = expectation

        sensor.delegate = delegate
        sensor.startMonitoring()
        wait(for: [expectation], timeout: 5.0)

        let countBeforeStop = delegate.depthUpdates.count
        sensor.stopMonitoring()

        // Wait a bit to ensure no more updates come
        let noMoreExpectation = self.expectation(description: "No more updates")
        noMoreExpectation.isInverted = true
        delegate.depthExpectation = noMoreExpectation
        wait(for: [noMoreExpectation], timeout: 2.0)

        XCTAssertEqual(delegate.depthUpdates.count, countBeforeStop,
                       "No more depth updates should arrive after stopMonitoring")
    }

    func testDelegateIsWeak() {
        let sensor = MockDiveSensor()
        var delegate: TestSensorDelegate? = TestSensorDelegate()
        sensor.delegate = delegate
        XCTAssertNotNil(sensor.delegate)

        delegate = nil
        XCTAssertNil(sensor.delegate, "Delegate should be weak and nil when deallocated")
    }

    func testMultipleStartStopCycles() {
        let sensor = MockDiveSensor()
        let delegate = TestSensorDelegate()
        sensor.delegate = delegate

        // First cycle
        let exp1 = self.expectation(description: "First start")
        delegate.setSubmersionExpectation(exp1, maxFulfills: 1)
        sensor.startMonitoring()
        wait(for: [exp1], timeout: 1.0)

        let exp2 = self.expectation(description: "First stop")
        delegate.setSubmersionExpectation(exp2, maxFulfills: 1)
        sensor.stopMonitoring()
        wait(for: [exp2], timeout: 1.0)

        // Second cycle
        let exp3 = self.expectation(description: "Second start")
        delegate.setSubmersionExpectation(exp3, maxFulfills: 1)
        sensor.startMonitoring()
        wait(for: [exp3], timeout: 1.0)

        let exp4 = self.expectation(description: "Second stop")
        delegate.setSubmersionExpectation(exp4, maxFulfills: 1)
        sensor.stopMonitoring()
        wait(for: [exp4], timeout: 1.0)

        // Should have: true, false, true, false
        XCTAssertEqual(delegate.submersionChanges, [true, false, true, false])
    }

    // MARK: - Interpolation edge cases

    func testInterpolatedDepthAtTimeZero() {
        let sensor = MockDiveSensor()
        let depth = sensor.interpolatedDepth(at: 0)
        XCTAssertEqual(depth, 0.0, accuracy: 0.001, "Depth at t=0 should be 0 (surface)")
    }

    func testInterpolatedDepthBeforeStart() {
        let sensor = MockDiveSensor()
        let depth = sensor.interpolatedDepth(at: -5.0)
        XCTAssertEqual(depth, 0.0, accuracy: 0.001, "Depth before t=0 should be 0")
    }

    func testInterpolatedDepthAtProfileEnd() {
        let sensor = MockDiveSensor()
        let depth = sensor.interpolatedDepth(at: 1680)
        XCTAssertEqual(depth, 0.0, accuracy: 0.001, "Depth at profile end should be 0")
    }

    func testInterpolatedDepthPastProfileEnd() {
        let sensor = MockDiveSensor()
        let depth = sensor.interpolatedDepth(at: 2000)
        XCTAssertEqual(depth, 0.0, accuracy: 0.001, "Depth past profile end should be 0")
    }

    func testInterpolatedDepthAtBottomTime() {
        let sensor = MockDiveSensor()
        let depth = sensor.interpolatedDepth(at: 500)
        XCTAssertEqual(depth, 18.0, accuracy: 0.001, "Depth during bottom time should be 18m")
    }

    func testSimulatedTemperatureAtSurfaceDepth() {
        let sensor = MockDiveSensor()
        let temp = sensor.simulatedTemperature(at: 0)
        XCTAssertEqual(temp, 28.0, accuracy: 0.01, "Surface temp should be 28°C")
    }

    func testSimulatedTemperatureAt18m() {
        let sensor = MockDiveSensor()
        let temp = sensor.simulatedTemperature(at: 18.0)
        XCTAssertEqual(temp, 22.0, accuracy: 0.01, "Temp at 18m should be 22°C")
    }

    func testSimulatedTemperatureAt9m() {
        let sensor = MockDiveSensor()
        let temp = sensor.simulatedTemperature(at: 9.0)
        XCTAssertEqual(temp, 25.0, accuracy: 0.01, "Temp at 9m should be 25°C (midpoint)")
    }
}
