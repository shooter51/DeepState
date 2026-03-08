import Foundation

public protocol DiveSensorDelegate: AnyObject {
    func didUpdateDepth(_ depth: Double, temperature: Double?)
    func didChangeSubmersionState(_ submerged: Bool)
    func didEncounterError(_ error: Error)
}

public protocol DiveSensorProtocol: AnyObject {
    var delegate: DiveSensorDelegate? { get set }
    var isAvailable: Bool { get }
    func startMonitoring()
    func stopMonitoring()
}
