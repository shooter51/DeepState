import Foundation
import DiveCore
import Combine

@Observable
final class DiveSensorBridge: DiveSensorDelegate {

    var depth: Double = 0
    var temperature: Double = 22.0
    var isSubmerged: Bool = false
    var isSensorAvailable: Bool = true

    var onSubmerged: (() -> Void)?
    var onSurfaced: (() -> Void)?

    private let sensor: DiveSensorProtocol

    init() {
        // TODO: When real CMWaterSubmersionManager integration is ready,
        // conditionally use it here instead of MockDiveSensor.
        #if SIMULATE_DIVE
        let mock = MockDiveSensor()
        self.sensor = mock
        #else
        // Intentionally using MockDiveSensor in non-simulated builds as well.
        // Real CMWaterSubmersionManager integration is blocked until Apple grants the
        // com.apple.developer.coremotion.water-submersion entitlement.
        // See CLAUDE.md "Known Gaps" item 8.
        let mock = MockDiveSensor()
        self.sensor = mock
        #endif

        sensor.delegate = self
    }

    func startMonitoring() {
        sensor.startMonitoring()
    }

    func stopMonitoring() {
        sensor.stopMonitoring()
    }

    // MARK: - DiveSensorDelegate

    func didUpdateDepth(_ depth: Double, temperature: Double?) {
        self.depth = depth
        self.isSensorAvailable = true
        if let temperature {
            self.temperature = temperature
        }
    }

    func didChangeSubmersionState(_ submerged: Bool) {
        isSubmerged = submerged
        if submerged {
            onSubmerged?()
        } else {
            onSurfaced?()
        }
    }

    func didEncounterError(_ error: Error) {
        isSensorAvailable = false
    }
}
