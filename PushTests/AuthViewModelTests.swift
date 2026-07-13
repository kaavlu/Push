// PushTests/AuthViewModelTests.swift
import XCTest
@testable import Push

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testSuccessfulSignInPublishesUser() async {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.email = "alice@push.test"; vm.password = "push-test-alice"
        XCTAssertTrue(vm.canSubmit)
        await vm.submitSignIn()
        XCTAssertEqual(vm.authedUser?.email, "alice@push.test")
        XCTAssertNil(vm.errorMessage)
    }

    func testFailedSignInSurfacesError() async {
        let fake = FakeAuthService()
        fake.signInResult = .failure(NSError(domain: "auth", code: 401))
        let vm = AuthViewModel(auth: fake)
        vm.email = "x@push.test"; vm.password = "bad"
        await vm.submitSignIn()
        XCTAssertNil(vm.authedUser)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testCannotSubmitWithEmptyFields() {
        let vm = AuthViewModel(auth: FakeAuthService())
        XCTAssertFalse(vm.canSubmit)
    }

    func testRestoreAdoptsPersistedUser() async {
        let vm = AuthViewModel(auth: FakeAuthService(restorable: AuthedUser(id: "u1", email: "a@b.c")))
        await vm.restore()
        XCTAssertEqual(vm.authedUser?.id, "u1")
    }
}
