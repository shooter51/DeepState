import Foundation
import DiveCore
import Observation

@Observable
final class DiveViewModel {

    // MARK: - Observable State (mirrored from DiveSessionManager)

    private(set) var phase: DivePhase = .surface
    private(set) var currentDepth: Double = 0
    private(set) var maxDepth: Double = 0
    private(set) var averageDepth: Double = 0
    private(set) var temperature: Double = 22.0
    private(set) var minTemperature: Double = 22.0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var ndl: Int = 999
    private(set) var ceilingDepth: Double = 0
    private(set) var ascentRate: Double = 0
    private(set) var ascentRateStatus: AscentRateMonitor.AscentRateStatus = .safe
    private(set) var cnsPercent: Double = 0
    private(set) var otuTotal: Double = 0
    private(set) var ppO2: Double = 0.21
    private(set) var surfaceIntervalStart: Date?

    private(set) var safetyStopIsActive: Bool = false
    private(set) var safetyStopRemainingTime: TimeInterval = 0
    private(set) var safetyStopDuration: TimeInterval = 180.0

    private(set) var tissueLoadingPercent: [Double] = []
    private(set) var gasDescription: String = "Air"
    private(set) var gfDescription: String = "40/85"

    // MARK: - Underlying Manager

    private(set) var manager: DiveSessionManager

    // MARK: - Init

    init(gasMix: GasMix = .air, gfLow: Double = 0.40, gfHigh: Double = 0.85) {
        self.manager = DiveSessionManager(gasMix: gasMix, gfLow: gfLow, gfHigh: gfHigh)
    }

    // MARK: - Dive Control

    func startDive() {
        manager.startDive()
        syncState()
    }

    func endDive() {
        manager.endDive()
        syncState()
    }

    func resetForNewDive() {
        manager.resetForNewDive()
        syncState()
    }

    func reconfigure(gasMix: GasMix, gfLow: Double, gfHigh: Double) {
        manager = DiveSessionManager(gasMix: gasMix, gfLow: gfLow, gfHigh: gfHigh)
        syncState()
    }

    // MARK: - Sensor Updates

    func updateDepth(_ depth: Double) {
        manager.updateDepth(depth)
        syncState()
    }

    func updateTemperature(_ temp: Double) {
        manager.updateTemperature(temp)
        syncState()
    }

    // MARK: - State Sync

    private func syncState() {
        phase = manager.phase
        currentDepth = manager.currentDepth
        maxDepth = manager.maxDepth
        averageDepth = manager.averageDepth
        temperature = manager.temperature
        minTemperature = manager.minTemperature
        elapsedTime = manager.elapsedTime
        ndl = manager.ndl
        ceilingDepth = manager.ceilingDepth
        ascentRate = manager.ascentRate
        ascentRateStatus = manager.ascentRateStatus
        cnsPercent = manager.cnsPercent
        otuTotal = manager.otuTotal
        ppO2 = manager.ppO2
        surfaceIntervalStart = manager.surfaceIntervalStart

        safetyStopIsActive = manager.safetyStopManager.isAtSafetyStop
        safetyStopRemainingTime = manager.safetyStopManager.remainingTime
        safetyStopDuration = manager.safetyStopManager.safetyStopDuration

        tissueLoadingPercent = manager.tissueLoadingPercent
        gasDescription = manager.gasDescription
        gfDescription = manager.gfDescription
    }

    // MARK: - Passthrough for save

    var gasMix: GasMix { manager.gasMix }
    var engine: BuhlmannEngine { manager.engine }
}
