import XCTest
@testable import DiveCore

final class DiveModelsTests: XCTestCase {

    // MARK: - DiveSettings

    func testDiveSettingsDefaults() {
        let settings = DiveSettings()
        XCTAssertEqual(settings.unitSystem, "metric")
        XCTAssertEqual(settings.defaultO2Percent, 21)
        XCTAssertEqual(settings.gfLow, 0.40, accuracy: 0.001)
        XCTAssertEqual(settings.gfHigh, 0.85, accuracy: 0.001)
        XCTAssertEqual(settings.ppO2Max, 1.4, accuracy: 0.001)
        XCTAssertEqual(settings.ascentRateWarning, 12.0, accuracy: 0.001)
        XCTAssertEqual(settings.ascentRateCritical, 18.0, accuracy: 0.001)
        XCTAssertEqual(settings.targetAscentRate, 9.0, accuracy: 0.001)
    }

    func testDiveSettingsCustomInit() {
        let settings = DiveSettings(
            unitSystem: "imperial",
            defaultO2Percent: 32,
            gfLow: 0.30,
            gfHigh: 0.70,
            ppO2Max: 1.2,
            ascentRateWarning: 10.0,
            ascentRateCritical: 15.0,
            targetAscentRate: 8.0
        )
        XCTAssertEqual(settings.unitSystem, "imperial")
        XCTAssertEqual(settings.defaultO2Percent, 32)
        XCTAssertEqual(settings.gfLow, 0.30, accuracy: 0.001)
        XCTAssertEqual(settings.gfHigh, 0.70, accuracy: 0.001)
        XCTAssertEqual(settings.ppO2Max, 1.2, accuracy: 0.001)
        XCTAssertEqual(settings.ascentRateWarning, 10.0, accuracy: 0.001)
        XCTAssertEqual(settings.ascentRateCritical, 15.0, accuracy: 0.001)
        XCTAssertEqual(settings.targetAscentRate, 8.0, accuracy: 0.001)
    }

    func testDiveSettingsMutable() {
        let settings = DiveSettings()
        settings.unitSystem = "imperial"
        settings.defaultO2Percent = 36
        settings.gfLow = 0.25
        XCTAssertEqual(settings.unitSystem, "imperial")
        XCTAssertEqual(settings.defaultO2Percent, 36)
        XCTAssertEqual(settings.gfLow, 0.25, accuracy: 0.001)
    }

    // MARK: - DepthSample

    func testDepthSampleDefaults() {
        let now = Date()
        let sample = DepthSample(timestamp: now, depth: 15.0)
        XCTAssertEqual(sample.timestamp, now)
        XCTAssertEqual(sample.depth, 15.0, accuracy: 0.001)
        XCTAssertNil(sample.temperature)
        XCTAssertNil(sample.ndl)
        XCTAssertNil(sample.ceilingDepth)
        XCTAssertNil(sample.ascentRate)
        XCTAssertNil(sample.diveSession)
    }

    func testDepthSampleFullInit() {
        let now = Date()
        let sample = DepthSample(
            timestamp: now,
            depth: 30.0,
            temperature: 22.5,
            ndl: 15,
            ceilingDepth: 3.0,
            ascentRate: 9.0
        )
        XCTAssertEqual(sample.depth, 30.0, accuracy: 0.001)
        XCTAssertEqual(sample.temperature, 22.5)
        XCTAssertEqual(sample.ndl, 15)
        XCTAssertEqual(sample.ceilingDepth, 3.0)
        XCTAssertEqual(sample.ascentRate, 9.0)
    }

    func testDepthSampleMutable() {
        let sample = DepthSample(timestamp: Date(), depth: 10.0)
        sample.depth = 20.0
        sample.temperature = 18.0
        sample.ndl = 42
        XCTAssertEqual(sample.depth, 20.0, accuracy: 0.001)
        XCTAssertEqual(sample.temperature, 18.0)
        XCTAssertEqual(sample.ndl, 42)
    }

    // MARK: - DiveSession

    func testDiveSessionDefaults() {
        let now = Date()
        let session = DiveSession(startDate: now)
        XCTAssertEqual(session.startDate, now)
        XCTAssertNil(session.endDate)
        XCTAssertEqual(session.maxDepth, 0)
        XCTAssertEqual(session.avgDepth, 0)
        XCTAssertEqual(session.duration, 0)
        XCTAssertNil(session.minTemp)
        XCTAssertNil(session.maxTemp)
        XCTAssertEqual(session.o2Percent, 21)
        XCTAssertEqual(session.gfLow, 0.40, accuracy: 0.001)
        XCTAssertEqual(session.gfHigh, 0.85, accuracy: 0.001)
        XCTAssertTrue(session.phaseHistory.isEmpty)
        XCTAssertTrue(session.tissueLoadingAtEnd.isEmpty)
        XCTAssertEqual(session.cnsPercent, 0)
        XCTAssertEqual(session.otuTotal, 0)
        XCTAssertNotNil(session.id)
    }

    func testDiveSessionCustomInit() {
        let start = Date()
        let end = Date().addingTimeInterval(3600)
        let session = DiveSession(
            startDate: start,
            endDate: end,
            maxDepth: 30.0,
            avgDepth: 18.0,
            duration: 3600,
            minTemp: 20.0,
            maxTemp: 28.0,
            o2Percent: 32,
            gfLow: 0.30,
            gfHigh: 0.70
        )
        XCTAssertEqual(session.startDate, start)
        XCTAssertEqual(session.endDate, end)
        XCTAssertEqual(session.maxDepth, 30.0, accuracy: 0.001)
        XCTAssertEqual(session.avgDepth, 18.0, accuracy: 0.001)
        XCTAssertEqual(session.duration, 3600, accuracy: 0.001)
        XCTAssertEqual(session.minTemp, 20.0)
        XCTAssertEqual(session.maxTemp, 28.0)
        XCTAssertEqual(session.o2Percent, 32)
        XCTAssertEqual(session.gfLow, 0.30, accuracy: 0.001)
        XCTAssertEqual(session.gfHigh, 0.70, accuracy: 0.001)
    }

    func testDiveSessionMutable() {
        let session = DiveSession(startDate: Date())
        session.maxDepth = 25.0
        session.phaseHistory = ["surface", "descending", "atDepth"]
        session.tissueLoadingAtEnd = Array(repeating: 50.0, count: 16)
        session.cnsPercent = 12.5
        session.otuTotal = 45.0

        XCTAssertEqual(session.maxDepth, 25.0, accuracy: 0.001)
        XCTAssertEqual(session.phaseHistory.count, 3)
        XCTAssertEqual(session.tissueLoadingAtEnd.count, 16)
        XCTAssertEqual(session.cnsPercent, 12.5, accuracy: 0.001)
        XCTAssertEqual(session.otuTotal, 45.0, accuracy: 0.001)
    }

    func testDiveSessionUniqueIDs() {
        let s1 = DiveSession(startDate: Date())
        let s2 = DiveSession(startDate: Date())
        XCTAssertNotEqual(s1.id, s2.id, "Each session should have a unique ID")
    }
}
