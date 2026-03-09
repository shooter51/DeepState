import XCTest
@testable import DiveCore

final class VersionCheckTests: XCTestCase {

    func testSameVersionNotOlder() {
        XCTAssertFalse(VersionComparator.isVersion("1.0.0", olderThan: "1.0.0"))
    }

    func testOlderPatch() {
        XCTAssertTrue(VersionComparator.isVersion("1.0.0", olderThan: "1.0.1"))
    }

    func testOlderMinor() {
        XCTAssertTrue(VersionComparator.isVersion("1.0.0", olderThan: "1.1.0"))
    }

    func testOlderMajor() {
        XCTAssertTrue(VersionComparator.isVersion("1.0.0", olderThan: "2.0.0"))
    }

    func testNewerVersionNotOlder() {
        XCTAssertFalse(VersionComparator.isVersion("2.0.0", olderThan: "1.0.0"))
    }

    func testNewerPatchNotOlder() {
        XCTAssertFalse(VersionComparator.isVersion("1.0.2", olderThan: "1.0.1"))
    }

    func testManifestDecoding() throws {
        let json = """
        {"minimumSafeVersion":"1.0.1","safetyNotice":"Critical NDL fix","blockDiveMode":true}
        """
        let manifest = try JSONDecoder().decode(VersionManifest.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(manifest.minimumSafeVersion, "1.0.1")
        XCTAssertEqual(manifest.safetyNotice, "Critical NDL fix")
        XCTAssertTrue(manifest.blockDiveMode)
    }

    func testManifestDecodingNoNotice() throws {
        let json = """
        {"minimumSafeVersion":"1.0.0","safetyNotice":null,"blockDiveMode":false}
        """
        let manifest = try JSONDecoder().decode(VersionManifest.self, from: json.data(using: .utf8)!)
        XCTAssertNil(manifest.safetyNotice)
        XCTAssertFalse(manifest.blockDiveMode)
    }

    // MARK: - Manifest Encoding

    func testManifestEncodingRoundTrip() throws {
        let original = VersionManifest(minimumSafeVersion: "2.1.0", safetyNotice: "Update now", blockDiveMode: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VersionManifest.self, from: data)
        XCTAssertEqual(decoded.minimumSafeVersion, "2.1.0")
        XCTAssertEqual(decoded.safetyNotice, "Update now")
        XCTAssertTrue(decoded.blockDiveMode)
    }

    func testManifestEncodingNilNotice() throws {
        let original = VersionManifest(minimumSafeVersion: "1.0.0", safetyNotice: nil, blockDiveMode: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VersionManifest.self, from: data)
        XCTAssertEqual(decoded.minimumSafeVersion, "1.0.0")
        XCTAssertNil(decoded.safetyNotice)
        XCTAssertFalse(decoded.blockDiveMode)
    }

    // MARK: - Version Edge Cases

    func testShorterVersionString() {
        // "1.0" should be treated as "1.0.0"
        XCTAssertFalse(VersionComparator.isVersion("1.0", olderThan: "1.0.0"),
                       "1.0 should equal 1.0.0")
        XCTAssertFalse(VersionComparator.isVersion("1.0.0", olderThan: "1.0"),
                       "1.0.0 should equal 1.0")
    }

    func testShorterVersionOlder() {
        XCTAssertTrue(VersionComparator.isVersion("1.0", olderThan: "1.0.1"),
                      "1.0 should be older than 1.0.1")
    }

    func testZeroNineNineOlderThanOneZeroZero() {
        XCTAssertTrue(VersionComparator.isVersion("0.9.9", olderThan: "1.0.0"),
                      "0.9.9 should be older than 1.0.0")
    }

    func testOneZeroZeroNotOlderThanZeroNineNine() {
        XCTAssertFalse(VersionComparator.isVersion("1.0.0", olderThan: "0.9.9"),
                       "1.0.0 should not be older than 0.9.9")
    }

    func testDoubleDigitMinorVersion() {
        XCTAssertFalse(VersionComparator.isVersion("1.10.0", olderThan: "1.9.0"),
                       "1.10.0 should not be older than 1.9.0")
        XCTAssertTrue(VersionComparator.isVersion("1.9.0", olderThan: "1.10.0"),
                      "1.9.0 should be older than 1.10.0")
    }

    func testDoubleDigitPatchVersion() {
        XCTAssertTrue(VersionComparator.isVersion("1.0.9", olderThan: "1.0.10"),
                      "1.0.9 should be older than 1.0.10")
        XCTAssertFalse(VersionComparator.isVersion("1.0.10", olderThan: "1.0.9"),
                       "1.0.10 should not be older than 1.0.9")
    }

    func testSingleComponentVersion() {
        XCTAssertTrue(VersionComparator.isVersion("1", olderThan: "2"),
                      "1 should be older than 2")
        XCTAssertFalse(VersionComparator.isVersion("2", olderThan: "1"),
                       "2 should not be older than 1")
    }

    func testManifestInitDefaults() {
        let manifest = VersionManifest(minimumSafeVersion: "1.0.0")
        XCTAssertNil(manifest.safetyNotice, "Default safetyNotice should be nil")
        XCTAssertTrue(manifest.blockDiveMode, "Default blockDiveMode should be true")
    }

    // MARK: - VersionCheckService

    func testCheckServiceInitDefaults() {
        let service = VersionCheckService()
        // Just verify it can be instantiated without crashing
        XCTAssertNotNil(service)
    }

    func testCheckServiceCustomInit() {
        let url = URL(string: "https://example.com/version.json")!
        let service = VersionCheckService(endpoint: url, currentVersion: "2.0.0")
        XCTAssertNotNil(service)
    }

    func testCheckServiceDefaultEndpoint() {
        XCTAssertEqual(
            VersionCheckService.defaultEndpoint.absoluteString,
            "https://deepstate.divestreams.com/version.json"
        )
    }

    func testCheckServiceReturnsCheckFailedForInvalidURL() async {
        let badURL = URL(string: "file:///tmp/nonexistent_deepstate_version_\(UUID().uuidString).json")!
        let service = VersionCheckService(endpoint: badURL, currentVersion: "1.0.0")
        let status = await service.check()
        XCTAssertEqual(status, .checkFailed)
    }

    // MARK: - VersionCheckService with injected fetcher

    private func makeHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    func testCheckReturnsUpToDateWhenVersionMatches() async {
        let json = """
        {"minimumSafeVersion":"1.0.0","safetyNotice":null,"blockDiveMode":false}
        """.data(using: .utf8)!
        let url = URL(string: "https://example.com/v.json")!

        let service = VersionCheckService(endpoint: url, currentVersion: "1.0.0") { reqURL in
            (json, self.makeHTTPResponse(url: reqURL, statusCode: 200))
        }
        let status = await service.check()
        XCTAssertEqual(status, .upToDate)
    }

    func testCheckReturnsUpToDateWhenVersionNewer() async {
        let json = """
        {"minimumSafeVersion":"1.0.0","safetyNotice":null,"blockDiveMode":true}
        """.data(using: .utf8)!
        let url = URL(string: "https://example.com/v.json")!

        let service = VersionCheckService(endpoint: url, currentVersion: "2.0.0") { reqURL in
            (json, self.makeHTTPResponse(url: reqURL, statusCode: 200))
        }
        let status = await service.check()
        XCTAssertEqual(status, .upToDate)
    }

    func testCheckReturnsUpdateRequiredWhenOlder() async {
        let json = """
        {"minimumSafeVersion":"2.0.0","safetyNotice":"Critical fix","blockDiveMode":true}
        """.data(using: .utf8)!
        let url = URL(string: "https://example.com/v.json")!

        let service = VersionCheckService(endpoint: url, currentVersion: "1.0.0") { reqURL in
            (json, self.makeHTTPResponse(url: reqURL, statusCode: 200))
        }
        let status = await service.check()
        XCTAssertEqual(status, .updateRequired(notice: "Critical fix"))
    }

    func testCheckReturnsUpdateRequiredWithNilNotice() async {
        let json = """
        {"minimumSafeVersion":"2.0.0","safetyNotice":null,"blockDiveMode":true}
        """.data(using: .utf8)!
        let url = URL(string: "https://example.com/v.json")!

        let service = VersionCheckService(endpoint: url, currentVersion: "1.0.0") { reqURL in
            (json, self.makeHTTPResponse(url: reqURL, statusCode: 200))
        }
        let status = await service.check()
        XCTAssertEqual(status, .updateRequired(notice: nil))
    }

    func testCheckReturnsCheckFailedForNon200() async {
        let json = "{}".data(using: .utf8)!
        let url = URL(string: "https://example.com/v.json")!

        let service = VersionCheckService(endpoint: url, currentVersion: "1.0.0") { reqURL in
            (json, self.makeHTTPResponse(url: reqURL, statusCode: 500))
        }
        let status = await service.check()
        XCTAssertEqual(status, .checkFailed)
    }

    func testCheckReturnsCheckFailedForMalformedJSON() async {
        let bad = "not json".data(using: .utf8)!
        let url = URL(string: "https://example.com/v.json")!

        let service = VersionCheckService(endpoint: url, currentVersion: "1.0.0") { reqURL in
            (bad, self.makeHTTPResponse(url: reqURL, statusCode: 200))
        }
        let status = await service.check()
        XCTAssertEqual(status, .checkFailed)
    }

    func testCheckReturnsCheckFailedForNetworkError() async {
        let url = URL(string: "https://example.com/v.json")!

        let service = VersionCheckService(endpoint: url, currentVersion: "1.0.0") { _ in
            throw URLError(.notConnectedToInternet)
        }
        let status = await service.check()
        XCTAssertEqual(status, .checkFailed)
    }

    // MARK: - Status Equatable

    func testStatusEquatable() {
        XCTAssertEqual(VersionCheckService.Status.unknown, .unknown)
        XCTAssertEqual(VersionCheckService.Status.upToDate, .upToDate)
        XCTAssertEqual(VersionCheckService.Status.checkFailed, .checkFailed)
        XCTAssertEqual(VersionCheckService.Status.updateRequired(notice: "x"), .updateRequired(notice: "x"))
        XCTAssertNotEqual(VersionCheckService.Status.updateRequired(notice: "a"), .updateRequired(notice: "b"))
        XCTAssertNotEqual(VersionCheckService.Status.upToDate, .checkFailed)
    }
}
