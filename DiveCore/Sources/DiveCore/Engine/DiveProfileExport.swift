import Foundation

/// A complete dive profile export containing inputs, outputs, and configuration.
/// Used for e2e test generation: record a dive, export the profile, replay in tests.
public struct DiveProfileExport: Codable, Sendable {

    /// Dive configuration at start
    public let config: DiveConfig

    /// Every recorded sample during the dive
    public let samples: [ProfileSample]

    /// Summary statistics computed at end of dive
    public let summary: DiveSummary

    /// Metadata
    public let exportVersion: String
    public let exportDate: Date

    /// Current schema version for dive profile exports.
    /// Increment when the export format changes (e.g., fields added/removed/renamed).
    public static let currentSchemaVersion = "1.0.0"

    public init(config: DiveConfig, samples: [ProfileSample], summary: DiveSummary, exportDate: Date = Date()) {
        self.config = config
        self.samples = samples
        self.summary = summary
        self.exportVersion = DiveProfileExport.currentSchemaVersion
        self.exportDate = exportDate
    }

    // MARK: - Config

    public struct DiveConfig: Codable, Sendable {
        public let gasMix: GasMix
        public let gfLow: Double
        public let gfHigh: Double

        public init(gasMix: GasMix, gfLow: Double, gfHigh: Double) {
            self.gasMix = gasMix
            self.gfLow = gfLow
            self.gfHigh = gfHigh
        }
    }

    // MARK: - Sample

    /// A single point-in-time snapshot of inputs and expected outputs.
    public struct ProfileSample: Codable, Sendable {
        // Inputs (what was fed into the system)
        public let sampleIndex: Int
        public let inputDepth: Double
        public let inputTemperature: Double?

        // Outputs (what the system computed)
        public let phase: String
        public let currentDepth: Double
        public let maxDepth: Double
        public let averageDepth: Double
        public let elapsedTime: TimeInterval
        public let ndl: Int
        public let ceilingDepth: Double
        public let ascentRate: Double
        public let ascentRateStatus: String
        public let ppO2: Double
        public let cnsPercent: Double
        public let otuTotal: Double
        public let depthLimitStatus: String
        public let safetyStopState: String
        public let temperature: Double
        public let minTemperature: Double

        public init(
            sampleIndex: Int,
            inputDepth: Double,
            inputTemperature: Double?,
            phase: String,
            currentDepth: Double,
            maxDepth: Double,
            averageDepth: Double,
            elapsedTime: TimeInterval,
            ndl: Int,
            ceilingDepth: Double,
            ascentRate: Double,
            ascentRateStatus: String,
            ppO2: Double,
            cnsPercent: Double,
            otuTotal: Double,
            depthLimitStatus: String,
            safetyStopState: String,
            temperature: Double,
            minTemperature: Double
        ) {
            self.sampleIndex = sampleIndex
            self.inputDepth = inputDepth
            self.inputTemperature = inputTemperature
            self.phase = phase
            self.currentDepth = currentDepth
            self.maxDepth = maxDepth
            self.averageDepth = averageDepth
            self.elapsedTime = elapsedTime
            self.ndl = ndl
            self.ceilingDepth = ceilingDepth
            self.ascentRate = ascentRate
            self.ascentRateStatus = ascentRateStatus
            self.ppO2 = ppO2
            self.cnsPercent = cnsPercent
            self.otuTotal = otuTotal
            self.depthLimitStatus = depthLimitStatus
            self.safetyStopState = safetyStopState
            self.temperature = temperature
            self.minTemperature = minTemperature
        }
    }

    // MARK: - Summary

    public struct DiveSummary: Codable, Sendable {
        public let maxDepth: Double
        public let averageDepth: Double
        public let duration: TimeInterval
        public let finalCNS: Double
        public let finalOTU: Double
        public let finalPhase: String
        public let tissueLoading: [Double]
        public let healthEventCount: Int
        public let sampleCount: Int

        public init(
            maxDepth: Double,
            averageDepth: Double,
            duration: TimeInterval,
            finalCNS: Double,
            finalOTU: Double,
            finalPhase: String,
            tissueLoading: [Double],
            healthEventCount: Int,
            sampleCount: Int
        ) {
            self.maxDepth = maxDepth
            self.averageDepth = averageDepth
            self.duration = duration
            self.finalCNS = finalCNS
            self.finalOTU = finalOTU
            self.finalPhase = finalPhase
            self.tissueLoading = tissueLoading
            self.healthEventCount = healthEventCount
            self.sampleCount = sampleCount
        }
    }
}

// MARK: - JSON Convenience

extension DiveProfileExport {

    /// Encode to pretty-printed JSON Data
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Decode from JSON Data
    public static func fromJSON(_ data: Data) throws -> DiveProfileExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiveProfileExport.self, from: data)
    }

    /// Write to file
    public func write(to url: URL) throws {
        let data = try toJSON()
        try data.write(to: url, options: .atomic)
    }

    /// Read from file
    public static func read(from url: URL) throws -> DiveProfileExport {
        let data = try Data(contentsOf: url)
        return try fromJSON(data)
    }
}
