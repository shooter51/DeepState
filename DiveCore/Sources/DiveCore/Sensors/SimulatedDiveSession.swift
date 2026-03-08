import Foundation
import Combine

public class SimulatedDiveSession: ObservableObject, DiveSensorDelegate {
    @Published public var depth: Double = 0.0
    @Published public var temperature: Double? = nil
    @Published public var isSubmerged: Bool = false

    private let sensor: MockDiveSensor

    public init() {
        self.sensor = MockDiveSensor()
        self.sensor.delegate = self
    }

    public func start() {
        sensor.startMonitoring()
    }

    public func stop() {
        sensor.stopMonitoring()
    }

    // MARK: - DiveSensorDelegate

    public func didUpdateDepth(_ depth: Double, temperature: Double?) {
        self.depth = depth
        self.temperature = temperature
    }

    public func didChangeSubmersionState(_ submerged: Bool) {
        self.isSubmerged = submerged
    }

    public func didEncounterError(_ error: Error) {
        // No-op for simulation
    }
}
