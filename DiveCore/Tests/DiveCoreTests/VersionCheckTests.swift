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
}
