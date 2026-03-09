import XCTest
@testable import DiveCore

final class DiveProfileE2ETests: XCTestCase {

    // MARK: - Profile Recording

    /// Record a standard dive profile and verify the export is complete.
    func testRecordStandardDiveProfile() {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .air,
            gfLow: 0.40,
            gfHigh: 0.85,
            waypoints: [
                (0, 0),
                (120, 18),
                (1320, 18),
                (1380, 12),
                (1440, 5),
                (1620, 5),
                (1680, 0),
            ],
            temperatureAt: { depth in 28.0 - depth * (6.0 / 18.0) }
        )

        // Config
        XCTAssertEqual(profile.config.gasMix, .air)
        XCTAssertEqual(profile.config.gfLow, 0.40, accuracy: 0.001)
        XCTAssertEqual(profile.config.gfHigh, 0.85, accuracy: 0.001)

        // Samples
        XCTAssertEqual(profile.samples.count, 1680, "Should have one sample per second")
        XCTAssertEqual(profile.summary.sampleCount, 1680)

        // Summary
        XCTAssertEqual(profile.summary.maxDepth, 18.0, accuracy: 0.5)
        XCTAssertGreaterThan(profile.summary.duration, 0)
        XCTAssertEqual(profile.summary.finalPhase, "surfaceInterval")
        XCTAssertEqual(profile.summary.tissueLoading.count, 16)
    }

    /// Verify NDL behavior during the dive.
    func testNDLProgressionDuringDive() {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .air,
            waypoints: [
                (0, 0),
                (60, 18),
                (600, 18),
                (660, 0),
            ]
        )

        // At the bottom (after descent), NDL should be finite
        let bottomSamples = profile.samples.filter { $0.inputDepth >= 17.0 }
        XCTAssertFalse(bottomSamples.isEmpty)

        if let firstBottom = bottomSamples.first, let lastBottom = bottomSamples.last {
            // NDL should decrease over time at depth
            XCTAssertGreaterThanOrEqual(firstBottom.ndl, lastBottom.ndl,
                                         "NDL should decrease or stay the same over time at depth")
            // NDL at 18m with air should be around 50-60 min
            XCTAssertGreaterThan(firstBottom.ndl, 30)
            XCTAssertLessThan(firstBottom.ndl, 80)
        }
    }

    /// Verify ppO2 is correct at depth.
    func testPpO2AtDepth() {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .ean32,
            waypoints: [
                (0, 0),
                (60, 30),
                (300, 30),
                (360, 0),
            ]
        )

        // At 30m with EAN32: ppO2 = 0.32 * (1.013 + 30/10) = 0.32 * 4.013 ≈ 1.284
        let deepSamples = profile.samples.filter { $0.inputDepth >= 29.0 }
        XCTAssertFalse(deepSamples.isEmpty)

        if let sample = deepSamples.first {
            XCTAssertEqual(sample.ppO2, 1.284, accuracy: 0.05)
        }
    }

    /// Verify CNS accumulates at high ppO2.
    func testCNSAccumulation() {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .ean32,
            waypoints: [
                (0, 0),
                (30, 30),
                (600, 30),
                (630, 0),
            ]
        )

        // CNS should increase during time at depth with ppO2 > 0.6
        XCTAssertGreaterThan(profile.summary.finalCNS, 0, "CNS should accumulate at high ppO2")

        // Should be modest for a 10-min dive at ~1.28 ppO2
        XCTAssertLessThan(profile.summary.finalCNS, 10, "CNS should be modest for a short dive")
    }

    /// Verify depth limit status triggers at correct depths.
    func testDepthLimitProgression() {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .air,
            waypoints: [
                (0, 0),
                (60, 38),
                (120, 39),
                (180, 40),
                (240, 20),
                (300, 0),
            ]
        )

        // Find samples at each depth threshold (use currentDepth which reflects what the manager sees)
        let at38 = profile.samples.first { $0.currentDepth >= 38.0 && $0.currentDepth < 39.0 }
        let at39 = profile.samples.first { $0.currentDepth >= 39.0 && $0.currentDepth < 40.0 }
        let at40 = profile.samples.first { $0.currentDepth >= 40.0 }

        XCTAssertEqual(at38?.depthLimitStatus, "approachingLimit")
        XCTAssertEqual(at39?.depthLimitStatus, "maxDepthWarning")
        XCTAssertEqual(at40?.depthLimitStatus, "depthLimitReached")
    }

    /// Verify safety stop triggers after a deep dive.
    func testSafetyStopTriggered() {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .air,
            waypoints: [
                (0, 0),
                (60, 20),
                (600, 20),
                (660, 5),
                (840, 5),
                (900, 0),
            ]
        )

        // At 5m after diving to 20m, safety stop should be pending or in progress
        let safetyStopSamples = profile.samples.filter {
            $0.inputDepth >= 3.5 && $0.inputDepth <= 6.5 && $0.sampleIndex > 660
        }
        XCTAssertFalse(safetyStopSamples.isEmpty)

        let stopStates = Set(safetyStopSamples.map { $0.safetyStopState })
        let hasStopActivity = stopStates.contains("pending") ||
                              stopStates.contains(where: { $0.hasPrefix("inProgress") }) ||
                              stopStates.contains("completed")
        XCTAssertTrue(hasStopActivity, "Safety stop should be active at 5m after a 20m dive. States: \(stopStates)")
    }

    // MARK: - JSON Round-Trip

    /// Export → JSON → re-import must produce identical data.
    func testJSONRoundTrip() throws {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .air,
            waypoints: [
                (0, 0),
                (30, 10),
                (120, 10),
                (150, 0),
            ]
        )

        let json = try profile.toJSON()
        let reimported = try DiveProfileExport.fromJSON(json)

        XCTAssertEqual(reimported.samples.count, profile.samples.count)
        XCTAssertEqual(reimported.config.gasMix, profile.config.gasMix)
        XCTAssertEqual(reimported.summary.maxDepth, profile.summary.maxDepth, accuracy: 0.001)
        XCTAssertEqual(reimported.exportVersion, "1.0.0")
    }

    /// Verify JSON can be written to and read from disk.
    func testFileRoundTrip() throws {
        let profile = DiveProfileRecorder.recordDive(
            gasMix: .ean36,
            gfLow: 0.30,
            gfHigh: 0.70,
            waypoints: [
                (0, 0),
                (30, 15),
                (300, 15),
                (330, 0),
            ]
        )

        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepstate_profile_test_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        try profile.write(to: tmpFile)
        let loaded = try DiveProfileExport.read(from: tmpFile)

        XCTAssertEqual(loaded.samples.count, profile.samples.count)
        XCTAssertEqual(loaded.config.gfLow, 0.30, accuracy: 0.001)
        XCTAssertEqual(loaded.config.gfHigh, 0.70, accuracy: 0.001)
    }

    // MARK: - Replay: E2E Regression Test

    /// Record a profile, then replay the inputs through a fresh DiveSessionManager
    /// and verify outputs match the recorded profile within tolerance.
    func testReplayProfileMatchesRecording() throws {
        // Step 1: Record a reference profile
        let reference = DiveProfileRecorder.recordDive(
            gasMix: .ean32,
            gfLow: 0.40,
            gfHigh: 0.85,
            waypoints: [
                (0, 0),
                (60, 18),
                (600, 18),
                (660, 5),
                (840, 5),
                (900, 0),
            ],
            temperatureAt: { depth in 28.0 - depth * 0.333 }
        )

        // Step 2: Serialize and deserialize (simulates loading a saved profile)
        let json = try reference.toJSON()
        let loaded = try DiveProfileExport.fromJSON(json)

        // Step 3: Replay through a fresh manager
        let manager = DiveSessionManager(
            gasMix: loaded.config.gasMix,
            gfLow: loaded.config.gfLow,
            gfHigh: loaded.config.gfHigh
        )
        manager.startDive()

        for sample in loaded.samples {
            manager.updateDepth(sample.inputDepth)
            if let temp = sample.inputTemperature {
                manager.updateTemperature(temp)
            }
        }

        // Step 4: Verify summary-level outputs match
        XCTAssertEqual(manager.maxDepth, loaded.summary.maxDepth, accuracy: 0.5)
        XCTAssertEqual(manager.cnsPercent, loaded.summary.finalCNS, accuracy: 1.0)
        XCTAssertEqual(manager.otuTotal, loaded.summary.finalOTU, accuracy: 1.0)

        // Step 5: Verify last sample outputs match
        if let lastRecorded = loaded.samples.last {
            XCTAssertEqual(manager.currentDepth, lastRecorded.currentDepth, accuracy: 0.5)
            XCTAssertEqual(manager.ndl, lastRecorded.ndl, accuracy: 5)
            XCTAssertEqual(manager.ppO2, lastRecorded.ppO2, accuracy: 0.05)
        }
    }

    // MARK: - Recorder API

    /// Verify manual recorder usage (not using the convenience method).
    func testManualRecorderUsage() {
        let manager = DiveSessionManager(gasMix: .air)
        let recorder = DiveProfileRecorder(manager: manager)

        manager.startDive()

        manager.updateDepth(5.0)
        manager.updateTemperature(26.0)
        recorder.recordSample(inputDepth: 5.0, inputTemperature: 26.0)

        manager.updateDepth(10.0)
        manager.updateTemperature(24.0)
        recorder.recordSample(inputDepth: 10.0, inputTemperature: 24.0)

        manager.updateDepth(15.0)
        recorder.recordSample(inputDepth: 15.0, inputTemperature: nil)

        let profile = recorder.export()

        XCTAssertEqual(profile.samples.count, 3)
        XCTAssertEqual(profile.samples[0].sampleIndex, 0)
        XCTAssertEqual(profile.samples[1].sampleIndex, 1)
        XCTAssertEqual(profile.samples[2].sampleIndex, 2)
        XCTAssertEqual(profile.samples[0].inputDepth, 5.0)
        XCTAssertEqual(profile.samples[1].inputDepth, 10.0)
        XCTAssertEqual(profile.samples[2].inputDepth, 15.0)
        XCTAssertEqual(profile.samples[0].inputTemperature, 26.0)
        XCTAssertNil(profile.samples[2].inputTemperature)
        XCTAssertEqual(profile.config.gasMix, .air)
    }

    /// Verify recorder reset clears samples.
    func testRecorderReset() {
        let manager = DiveSessionManager()
        let recorder = DiveProfileRecorder(manager: manager)

        manager.startDive()
        manager.updateDepth(10.0)
        recorder.recordSample(inputDepth: 10.0, inputTemperature: nil)

        XCTAssertEqual(recorder.export().samples.count, 1)

        recorder.reset()
        XCTAssertEqual(recorder.export().samples.count, 0)
    }

    // MARK: - Nitrox vs Air Comparison

    /// Verify that EAN32 produces longer NDL than air at the same depth.
    func testNitroxProducesLongerNDL() {
        let airProfile = DiveProfileRecorder.recordDive(
            gasMix: .air,
            waypoints: [
                (0, 0),
                (60, 30),
                (300, 30),
                (360, 0),
            ]
        )

        let nitroxProfile = DiveProfileRecorder.recordDive(
            gasMix: .ean32,
            waypoints: [
                (0, 0),
                (60, 30),
                (300, 30),
                (360, 0),
            ]
        )

        // Compare NDL at similar depth points during bottom time
        let airBottom = airProfile.samples.filter { $0.inputDepth >= 29.0 }
        let nitroxBottom = nitroxProfile.samples.filter { $0.inputDepth >= 29.0 }

        guard let airNDL = airBottom.first?.ndl, let nitroxNDL = nitroxBottom.first?.ndl else {
            XCTFail("Should have bottom samples")
            return
        }

        XCTAssertGreaterThan(nitroxNDL, airNDL,
                             "Nitrox should produce longer NDL than air at 30m")
    }

    /// Verify conservative GF produces shorter NDL.
    func testConservativeGFProducesShorterNDL() {
        let defaultProfile = DiveProfileRecorder.recordDive(
            gfLow: 0.40,
            gfHigh: 0.85,
            waypoints: [
                (0, 0),
                (60, 30),
                (300, 30),
                (360, 0),
            ]
        )

        let conservativeProfile = DiveProfileRecorder.recordDive(
            gfLow: 0.30,
            gfHigh: 0.70,
            waypoints: [
                (0, 0),
                (60, 30),
                (300, 30),
                (360, 0),
            ]
        )

        let defaultNDL = defaultProfile.samples.filter { $0.inputDepth >= 29.0 }.first?.ndl ?? 0
        let conservativeNDL = conservativeProfile.samples.filter { $0.inputDepth >= 29.0 }.first?.ndl ?? 0

        XCTAssertGreaterThan(defaultNDL, conservativeNDL,
                             "Default GF should produce longer NDL than conservative")
    }
}

// MARK: - XCTAssertEqual for Int with accuracy

private func XCTAssertEqual(_ a: Int, _ b: Int, accuracy: Int, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(abs(a - b) <= accuracy,
                  "\(a) and \(b) differ by more than \(accuracy)",
                  file: file, line: line)
}
