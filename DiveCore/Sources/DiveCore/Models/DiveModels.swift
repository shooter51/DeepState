import Foundation
import SwiftData

@Model
public final class DiveSettings {
    public var unitSystem: String = "metric"
    public var defaultO2Percent: Int = 21
    public var gfLow: Double = 0.40
    public var gfHigh: Double = 0.85
    public var ppO2Max: Double = 1.4
    public var ascentRateWarning: Double = 12.0
    public var ascentRateCritical: Double = 18.0
    public var targetAscentRate: Double = 9.0

    public init(
        unitSystem: String = "metric",
        defaultO2Percent: Int = 21,
        gfLow: Double = 0.40,
        gfHigh: Double = 0.85,
        ppO2Max: Double = 1.4,
        ascentRateWarning: Double = 12.0,
        ascentRateCritical: Double = 18.0,
        targetAscentRate: Double = 9.0
    ) {
        self.unitSystem = unitSystem
        self.defaultO2Percent = defaultO2Percent
        self.gfLow = gfLow
        self.gfHigh = gfHigh
        self.ppO2Max = ppO2Max
        self.ascentRateWarning = ascentRateWarning
        self.ascentRateCritical = ascentRateCritical
        self.targetAscentRate = targetAscentRate
    }
}

@Model
public final class DepthSample {
    public var timestamp: Date
    public var depth: Double
    public var temperature: Double?
    public var ndl: Int?
    public var ceilingDepth: Double?
    public var ascentRate: Double?
    public var diveSession: DiveSession?

    public init(
        timestamp: Date,
        depth: Double,
        temperature: Double? = nil,
        ndl: Int? = nil,
        ceilingDepth: Double? = nil,
        ascentRate: Double? = nil
    ) {
        self.timestamp = timestamp
        self.depth = depth
        self.temperature = temperature
        self.ndl = ndl
        self.ceilingDepth = ceilingDepth
        self.ascentRate = ascentRate
    }
}

@Model
public final class DiveSession {
    public var id: UUID = UUID()
    public var startDate: Date
    public var endDate: Date?
    public var maxDepth: Double = 0
    public var avgDepth: Double = 0
    public var duration: TimeInterval = 0
    public var minTemp: Double?
    public var maxTemp: Double?
    public var o2Percent: Int = 21
    public var gfLow: Double = 0.40
    public var gfHigh: Double = 0.85
    public var phaseHistory: [String] = []
    @Relationship(deleteRule: .cascade, inverse: \DepthSample.diveSession)
    public var depthSamples: [DepthSample]?
    public var tissueLoadingAtEnd: [Double] = []
    public var cnsPercent: Double = 0
    public var otuTotal: Double = 0

    public init(
        startDate: Date,
        endDate: Date? = nil,
        maxDepth: Double = 0,
        avgDepth: Double = 0,
        duration: TimeInterval = 0,
        minTemp: Double? = nil,
        maxTemp: Double? = nil,
        o2Percent: Int = 21,
        gfLow: Double = 0.40,
        gfHigh: Double = 0.85
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.maxDepth = maxDepth
        self.avgDepth = avgDepth
        self.duration = duration
        self.minTemp = minTemp
        self.maxTemp = maxTemp
        self.o2Percent = o2Percent
        self.gfLow = gfLow
        self.gfHigh = gfHigh
    }
}
