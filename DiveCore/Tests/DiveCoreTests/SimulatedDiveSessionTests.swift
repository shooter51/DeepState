import XCTest
@testable import DiveCore

final class SimulatedDiveSessionTests: XCTestCase {

    func testInitialState() {
        let session = SimulatedDiveSession()
        XCTAssertEqual(session.depth, 0.0)
        XCTAssertNil(session.temperature)
        XCTAssertFalse(session.isSubmerged)
    }

    func testStartSetsSubmerged() {
        let session = SimulatedDiveSession()
        session.start()

        // startMonitoring synchronously calls didChangeSubmersionState(true)
        XCTAssertTrue(session.isSubmerged)

        session.stop()
    }

    func testStopClearsSubmerged() {
        let session = SimulatedDiveSession()
        session.start()
        session.stop()

        XCTAssertFalse(session.isSubmerged)
    }

    func testDepthUpdatesAfterStart() {
        let session = SimulatedDiveSession()
        session.start()

        let expectation = self.expectation(description: "Depth updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        XCTAssertGreaterThan(session.depth, 0, "Depth should increase after starting")
        XCTAssertNotNil(session.temperature, "Temperature should be provided")

        session.stop()
    }

    func testDidUpdateDepthSetsProperties() {
        let session = SimulatedDiveSession()
        // Call delegate method directly
        session.didUpdateDepth(15.0, temperature: 24.5)

        XCTAssertEqual(session.depth, 15.0, accuracy: 0.001)
        XCTAssertEqual(session.temperature, 24.5)
    }

    func testDidChangeSubmersionState() {
        let session = SimulatedDiveSession()
        session.didChangeSubmersionState(true)
        XCTAssertTrue(session.isSubmerged)

        session.didChangeSubmersionState(false)
        XCTAssertFalse(session.isSubmerged)
    }

    func testDidEncounterErrorNoOp() {
        let session = SimulatedDiveSession()
        // Should not crash
        session.didEncounterError(NSError(domain: "test", code: 1))
        XCTAssertEqual(session.depth, 0.0, "Error should not change state")
    }
}
