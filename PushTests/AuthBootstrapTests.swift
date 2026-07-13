import XCTest
@testable import Push

@MainActor
final class AuthBootstrapTests: XCTestCase {
    func testMockModeSkipsAuthGate() {
        XCTAssertEqual(BootstrapState.initial(mode: .mock, restored: nil), .app(nil))
    }
    func testLiveWithNoSessionShowsGate() {
        XCTAssertEqual(BootstrapState.initial(mode: .live, restored: nil), .gate)
    }
    func testLiveWithRestoredSessionShowsApp() {
        let u = AuthedUser(id: "u1", email: "a@b.c")
        XCTAssertEqual(BootstrapState.initial(mode: .live, restored: u), .app(u))
    }
}
