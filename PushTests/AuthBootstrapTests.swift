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
    func testLiveWithRestoredSessionPreparesData() {
        let u = AuthedUser(id: "u1", email: "a@b.c")
        XCTAssertEqual(BootstrapState.initial(mode: .live, restored: u), .preparing(u))
    }

    func testPreparationFailureRetainsUserForRetryOrSignOut() {
        let u = AuthedUser(id: "u1", email: "a@b.c")
        XCTAssertEqual(BootstrapState.preparationFailed(u, "offline"), .preparationFailed(u, "offline"))
    }
}
