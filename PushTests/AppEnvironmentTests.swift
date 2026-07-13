import XCTest
@testable import Push

final class AppEnvironmentTests: XCTestCase {
    func testDebugDefaultsToMock() {
        XCTAssertEqual(AppEnvironment.resolve(isDebugBuild: true, arguments: []), .mock)
    }
    func testDebugOptsIntoLiveWithFlag() {
        XCTAssertEqual(AppEnvironment.resolve(isDebugBuild: true, arguments: ["--live"]), .live)
    }
    func testReleaseAlwaysLive() {
        XCTAssertEqual(AppEnvironment.resolve(isDebugBuild: false, arguments: []), .live)
        XCTAssertEqual(AppEnvironment.resolve(isDebugBuild: false, arguments: ["--live"]), .live)
    }
}
