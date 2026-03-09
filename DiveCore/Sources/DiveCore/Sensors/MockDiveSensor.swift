import Foundation

public class MockDiveSensor: DiveSensorProtocol {
    public weak var delegate: DiveSensorDelegate?
    public var isAvailable: Bool = true

    private var timer: Timer?
    private var elapsedTime: TimeInterval = 0

    // Scripted profile: (time in seconds, depth in meters)
    private let profilePoints: [(time: TimeInterval, depth: Double)] = [
        (0, 0),        // surface
        (120, 18),     // descent over 2 min at 9m/min
        (1320, 18),    // bottom time 20 min
        (1380, 12),    // begin ascent
        (1440, 5),     // safety stop depth
        (1620, 5),     // safety stop 3 min
        (1680, 0),     // surface
    ]

    public init() {
        #if SIMULATE_DIVE
        startMonitoring()
        #endif
    }

    public func startMonitoring() {
        elapsedTime = 0
        delegate?.didChangeSubmersionState(true)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        delegate?.didChangeSubmersionState(false)
    }

    private func tick() {
        elapsedTime += 1.0
        let depth = interpolatedDepth(at: elapsedTime)
        let temperature = simulatedTemperature(at: depth)

        delegate?.didUpdateDepth(depth, temperature: temperature)

        // End after profile completes
        if let lastPoint = profilePoints.last, elapsedTime >= lastPoint.time {
            stopMonitoring()
        }
    }

    func interpolatedDepth(at time: TimeInterval) -> Double {
        if time <= profilePoints.first!.time {
            return profilePoints.first!.depth
        }
        if time >= profilePoints.last!.time {
            return profilePoints.last!.depth
        }

        for i in 0..<(profilePoints.count - 1) {
            let p1 = profilePoints[i]
            let p2 = profilePoints[i + 1]

            if time >= p1.time && time <= p2.time {
                let fraction = (time - p1.time) / (p2.time - p1.time)
                return p1.depth + (p2.depth - p1.depth) * fraction
            }
        }

        return 0.0
    }

    func simulatedTemperature(at depth: Double) -> Double {
        // 28°C at surface, declining to 22°C at 18m (linear with depth)
        let surfaceTemp = 28.0
        let tempDropPerMeter = 6.0 / 18.0
        return surfaceTemp - depth * tempDropPerMeter
    }
}
