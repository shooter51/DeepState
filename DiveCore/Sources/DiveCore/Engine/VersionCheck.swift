import Foundation

/// Remote version manifest for safety update enforcement
public struct VersionManifest: Codable, Sendable {
    /// Minimum version allowed to enter dive mode
    public let minimumSafeVersion: String
    /// Optional safety notice displayed to all users below this version
    public let safetyNotice: String?
    /// If true, versions below minimumSafeVersion are completely blocked from dive mode
    public let blockDiveMode: Bool

    public init(minimumSafeVersion: String, safetyNotice: String? = nil, blockDiveMode: Bool = true) {
        self.minimumSafeVersion = minimumSafeVersion
        self.safetyNotice = safetyNotice
        self.blockDiveMode = blockDiveMode
    }
}

/// Compares semantic version strings (e.g. "1.0.0" < "1.0.1")
public enum VersionComparator {

    public static func isVersion(_ current: String, olderThan minimum: String) -> Bool {
        // Strip pre-release suffixes (anything after "-") before parsing
        let currentBase = current.split(separator: "-").first.map(String.init) ?? current
        let minimumBase = minimum.split(separator: "-").first.map(String.init) ?? minimum
        let currentParts = currentBase.split(separator: ".").compactMap { Int($0) }
        let minimumParts = minimumBase.split(separator: ".").compactMap { Int($0) }

        let count = max(currentParts.count, minimumParts.count)
        for i in 0..<count {
            let c = i < currentParts.count ? currentParts[i] : 0
            let m = i < minimumParts.count ? minimumParts[i] : 0
            if c < m { return true }
            if c > m { return false }
        }
        return false // equal
    }
}

/// Checks app version against a remote manifest
public actor VersionCheckService {

    public enum Status: Sendable, Equatable {
        case unknown
        case upToDate
        case updateRequired(notice: String?)
        case checkFailed
    }

    /// Default endpoint — host this JSON file statically
    public static let defaultEndpoint = URL(string: "https://deepstate.divestreams.com/version.json")!

    private let endpoint: URL
    private let currentVersion: String
    private let dataFetcher: @Sendable (URL) async throws -> (Data, URLResponse)

    public init(endpoint: URL = defaultEndpoint, currentVersion: String = "1.0.0") {
        self.endpoint = endpoint
        self.currentVersion = currentVersion
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config)
        self.dataFetcher = { url in try await session.data(from: url) }
    }

    /// Test-only initializer allowing injection of a custom data fetcher
    public init(
        endpoint: URL = defaultEndpoint,
        currentVersion: String = "1.0.0",
        dataFetcher: @escaping @Sendable (URL) async throws -> (Data, URLResponse)
    ) {
        self.endpoint = endpoint
        self.currentVersion = currentVersion
        self.dataFetcher = dataFetcher
    }

    public func check() async -> Status {
        do {
            let (data, response) = try await dataFetcher(endpoint)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .checkFailed
            }
            let manifest = try JSONDecoder().decode(VersionManifest.self, from: data)

            if VersionComparator.isVersion(currentVersion, olderThan: manifest.minimumSafeVersion) {
                return .updateRequired(notice: manifest.safetyNotice)
            }
            return .upToDate
        } catch {
            return .checkFailed
        }
    }
}
