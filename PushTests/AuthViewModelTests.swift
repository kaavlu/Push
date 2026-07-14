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

    func testGateStartsOnWelcomeScreen() {
        let vm = AuthViewModel(auth: FakeAuthService())
        XCTAssertEqual(vm.screen, .welcome)
    }

    func testShowSignInNavigatesToSignInScreen() {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.showSignIn()
        XCTAssertEqual(vm.screen, .signIn)
    }

    func testShowWelcomeClearsFieldsAndError() async {
        let fake = FakeAuthService()
        fake.signInResult = .failure(NSError(domain: "auth", code: 401))
        let vm = AuthViewModel(auth: fake)
        vm.email = "x@push.test"; vm.password = "bad"
        await vm.submitSignIn()
        XCTAssertNotNil(vm.errorMessage)

        vm.showWelcome()

        XCTAssertEqual(vm.screen, .welcome)
        XCTAssertEqual(vm.email, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertNil(vm.errorMessage)
    }

    func testRequestUnavailableSurfacesComingSoon() {
        let vm = AuthViewModel(auth: FakeAuthService())
        XCTAssertFalse(vm.showingComingSoon)
        vm.requestUnavailable()
        XCTAssertTrue(vm.showingComingSoon)
    }

    func testSignOutResetClearsSessionAndReturnsToWelcome() async {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.email = "alice@push.test"; vm.password = "push-test-alice"
        await vm.submitSignIn()
        vm.showSignIn()
        XCTAssertNotNil(vm.authedUser)

        vm.signOutReset()

        XCTAssertNil(vm.authedUser)
        XCTAssertEqual(vm.email, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.screen, .welcome)
    }
}
