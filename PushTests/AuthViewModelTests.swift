// PushTests/AuthViewModelTests.swift
import XCTest
@testable import Push

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testSuccessfulSignInPublishesUser() async {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.email = "alice@push.test"; vm.password = "push-test-alice"
        XCTAssertTrue(vm.canSubmitSignIn)
        await vm.submitSignIn()
        XCTAssertEqual(vm.authedUser?.email, "alice@push.test")
        XCTAssertNil(vm.errorMessage)
    }

    func testFailedSignInSurfacesError() async {
        let fake = FakeAuthService()
        fake.signInResult = .failure(NSError(domain: "auth", code: 401))
        let vm = AuthViewModel(auth: fake)
        vm.email = "x@push.test"; vm.password = "badpassword"
        await vm.submitSignIn()
        XCTAssertNil(vm.authedUser)
        XCTAssertEqual(vm.errorMessage, AuthUserMessage.generic)
    }

    func testCannotSubmitSignInWithEmptyFields() {
        let vm = AuthViewModel(auth: FakeAuthService())
        XCTAssertFalse(vm.canSubmitSignIn)
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

    func testShowSignUpNavigatesAndClearsFields() {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.email = "x@push.test"
        vm.showSignUp()
        XCTAssertEqual(vm.screen, .signUp)
        XCTAssertEqual(vm.email, "")
        XCTAssertEqual(vm.displayName, "")
        XCTAssertEqual(vm.handle, "")
    }

    func testShowWelcomeClearsFieldsAndError() async {
        let fake = FakeAuthService()
        fake.signInResult = .failure(NSError(domain: "auth", code: 401))
        let vm = AuthViewModel(auth: fake)
        vm.email = "x@push.test"; vm.password = "badpassword"
        await vm.submitSignIn()
        XCTAssertNotNil(vm.errorMessage)

        vm.showWelcome()

        XCTAssertEqual(vm.screen, .welcome)
        XCTAssertEqual(vm.email, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertNil(vm.errorMessage)
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
        XCTAssertFalse(vm.pendingPasswordRecovery)
    }

    // MARK: Sign-up

    func testSignUpRequiresStrongPasswordAndHandle() {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.displayName = "Alice"
        vm.handle = "al"
        vm.email = "alice@push.test"
        vm.password = "short"
        XCTAssertFalse(vm.canSubmitSignUp)

        vm.handle = "alice"
        vm.password = "longenough"
        XCTAssertTrue(vm.canSubmitSignUp)
    }

    func testSuccessfulSignUpPublishesUser() async {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.displayName = "Alice"
        vm.handle = "alice"
        vm.email = "alice@push.test"
        vm.password = "longenough"
        await vm.submitSignUp()
        XCTAssertEqual(vm.authedUser?.email, "alice@push.test")
        XCTAssertNil(vm.errorMessage)
    }

    func testSignUpConfirmationRequiredShowsCheckEmail() async {
        let fake = FakeAuthService()
        fake.signUpResult = .success(.confirmationRequired(email: "new@push.test"))
        let vm = AuthViewModel(auth: fake)
        vm.displayName = "New"
        vm.handle = "newbie"
        vm.email = "new@push.test"
        vm.password = "longenough"
        await vm.submitSignUp()
        XCTAssertNil(vm.authedUser)
        XCTAssertEqual(vm.screen, .checkEmail)
        XCTAssertEqual(vm.email, "new@push.test")
    }

    func testFailedSignUpSurfacesMappedError() async {
        let fake = FakeAuthService()
        fake.signUpResult = .failure(NSError(domain: "auth", code: 1))
        let vm = AuthViewModel(auth: fake)
        vm.displayName = "Alice"
        vm.handle = "alice"
        vm.email = "alice@push.test"
        vm.password = "longenough"
        await vm.submitSignUp()
        XCTAssertNil(vm.authedUser)
        XCTAssertEqual(vm.errorMessage, AuthUserMessage.generic)
    }

    // MARK: Forgot / reset

    func testForgotPasswordShowsNonEnumeratingSuccess() async {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.email = "alice@push.test"
        await vm.submitForgotPassword()
        XCTAssertEqual(vm.infoMessage, AuthUserMessage.resetSent)
        XCTAssertNil(vm.errorMessage)
    }

    func testForgotPasswordSurfacesNetworkError() async {
        let fake = FakeAuthService()
        fake.resetPasswordResult = .failure(NSError(domain: "net", code: -1))
        let vm = AuthViewModel(auth: fake)
        vm.email = "alice@push.test"
        await vm.submitForgotPassword()
        XCTAssertEqual(vm.errorMessage, AuthUserMessage.generic)
        XCTAssertNil(vm.infoMessage)
    }

    func testHandleOpenURLPasswordRecoveryDoesNotPublishUserYet() async {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.email = "alice@push.test"
        vm.password = "oldpassword"
        await vm.submitSignIn()
        XCTAssertNotNil(vm.authedUser)

        let handled = await vm.handleOpenURL(URL(string: "pushapp://auth/reset")!)
        XCTAssertTrue(handled)
        XCTAssertNil(vm.authedUser)
        XCTAssertEqual(vm.screen, .setNewPassword)
        XCTAssertTrue(vm.pendingPasswordRecovery)
        XCTAssertEqual(vm.password, "")
    }

    func testSubmitNewPasswordPublishesUserAndClearsRecoveryFlag() async {
        let fake = FakeAuthService()
        let vm = AuthViewModel(auth: fake)
        _ = await vm.handleOpenURL(URL(string: "pushapp://auth/reset")!)
        vm.password = "brandnewpass"
        vm.confirmPassword = "brandnewpass"
        XCTAssertTrue(vm.canSubmitNewPassword)
        await vm.submitNewPassword()
        XCTAssertNotNil(vm.authedUser)
        XCTAssertFalse(vm.pendingPasswordRecovery)
        XCTAssertNil(vm.errorMessage)
    }

    func testNewPasswordRequiresMatch() {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.password = "brandnewpass"
        vm.confirmPassword = "different1"
        XCTAssertFalse(vm.canSubmitNewPassword)
        vm.confirmPassword = "brandnewpass"
        XCTAssertTrue(vm.canSubmitNewPassword)
    }

    func testExpiredRecoveryLinkSurfacesErrorAndForgotScreen() async {
        let fake = FakeAuthService()
        fake.authURLResult = .failure(NSError(domain: "auth", code: 0))
        let vm = AuthViewModel(auth: fake)
        let handled = await vm.handleOpenURL(URL(string: "pushapp://auth/reset")!)
        XCTAssertTrue(handled)
        XCTAssertEqual(vm.screen, .forgotPassword)
        XCTAssertEqual(vm.errorMessage, AuthUserMessage.generic)
        XCTAssertFalse(vm.pendingPasswordRecovery)
    }

    func testHandleIgnoredURLReturnsFalse() async {
        let fake = FakeAuthService()
        fake.authURLResult = .success(.ignored)
        let vm = AuthViewModel(auth: fake)
        let handled = await vm.handleOpenURL(URL(string: "pushapp://other")!)
        XCTAssertFalse(handled)
        XCTAssertEqual(vm.screen, .welcome)
    }

    // MARK: Social providers

    func testSignInWithGooglePublishesUser() async {
        let vm = AuthViewModel(auth: FakeAuthService())
        await vm.signInWithGoogle()
        XCTAssertEqual(vm.authedUser?.id, "google-user")
        XCTAssertNil(vm.errorMessage)
    }

    func testSocialSignInCancellationLeavesNoError() async {
        let fake = FakeAuthService()
        fake.signInWithGoogleResult = .failure(SocialAuthError.cancelled)
        let vm = AuthViewModel(auth: fake)
        await vm.signInWithGoogle()
        XCTAssertNil(vm.authedUser)
        XCTAssertNil(vm.errorMessage)
    }

    func testSocialSignInFailureSurfacesCalmCopy() async {
        let fake = FakeAuthService()
        fake.signInWithGoogleResult = .failure(NSError(domain: "auth", code: 1))
        let vm = AuthViewModel(auth: fake)
        await vm.signInWithGoogle()
        XCTAssertNil(vm.authedUser)
        XCTAssertEqual(vm.errorMessage, AuthUserMessage.socialFailed)
    }

    func testOAuthCallbackPublishesSignedInUser() async {
        let fake = FakeAuthService()
        let user = AuthedUser(id: "oauth-user", email: "o@push.test")
        fake.authURLResult = .success(.signedIn(user))
        let vm = AuthViewModel(auth: fake)
        let handled = await vm.handleOpenURL(URL(string: "pushapp://auth/callback?code=abc")!)
        XCTAssertTrue(handled)
        XCTAssertEqual(vm.authedUser?.id, "oauth-user")
        XCTAssertFalse(vm.pendingPasswordRecovery)
        XCTAssertEqual(vm.screen, .welcome)
    }
}
