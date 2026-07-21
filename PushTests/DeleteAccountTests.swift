import XCTest
@testable import Push

@MainActor
final class DeleteAccountTests: XCTestCase {
    func testFakeDeleteAccountSuccessClearsCurrentUser() async throws {
        let auth = FakeAuthService()
        _ = try await auth.signIn(email: "a@push.test", password: "x")
        XCTAssertNotNil(auth.currentUser)

        try await auth.deleteAccount()

        XCTAssertNil(auth.currentUser)
    }

    func testFakeDeleteAccountFailureLeavesCurrentUser() async {
        let auth = FakeAuthService()
        _ = try? await auth.signIn(email: "a@push.test", password: "x")
        auth.deleteAccountResult = .failure(URLError(.notConnectedToInternet))

        do {
            try await auth.deleteAccount()
            XCTFail("expected deleteAccount to throw")
        } catch {
            XCTAssertNotNil(auth.currentUser)
        }
    }

    func testDeleteAccountUserMessage() {
        let message = AuthUserMessage.message(
            for: URLError(.timedOut),
            context: .deleteAccount
        )
        XCTAssertEqual(message, AuthUserMessage.deleteFailed)
    }

    func testDeleteAccountActionUnavailableByDefault() {
        XCTAssertFalse(DeleteAccountAction().isAvailable)
    }

    func testDeleteAccountActionInvokesHandler() async throws {
        var called = false
        let action = DeleteAccountAction {
            called = true
        }
        XCTAssertTrue(action.isAvailable)
        try await action()
        XCTAssertTrue(called)
    }

    func testDeleteAccountActionPropagatesFailure() async {
        let action = DeleteAccountAction {
            throw URLError(.notConnectedToInternet)
        }
        do {
            try await action()
            XCTFail("expected throw")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
}
