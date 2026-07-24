// Push/Auth/AuthViewModel.swift
import Foundation

/// Screens the production auth gate can show.
enum AuthGateScreen: Equatable {
    case welcome
    case signUpProfile
    case signUpCredentials
    case signIn
    case checkEmail
    case forgotPassword
    case setNewPassword

    /// In-frame back chevron (lab shell). Welcome / done-style destinations hide it.
    var showsBackButton: Bool {
        switch self {
        case .welcome, .checkEmail:
            return false
        case .signUpProfile, .signUpCredentials, .signIn, .forgotPassword, .setNewPassword:
            return true
        }
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""
    @Published var handle = ""
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var isBusy = false
    /// True while decoding/compressing a picked profile photo on the sign-up step.
    @Published private(set) var isPhotoBusy = false
    @Published var photoErrorMessage: String?
    /// JPEG ready for Storage upload after the live session is prepared.
    @Published private(set) var pendingProfilePhotoJPEG: Data?
    @Published private(set) var authedUser: AuthedUser?
    @Published private(set) var screen: AuthGateScreen = .welcome
    /// True after a recovery deep link until password is updated or the user leaves the flow.
    @Published private(set) var pendingPasswordRecovery = false

    private let auth: AuthService
    init(auth: AuthService) { self.auth = auth }

    // MARK: - Validation

    private enum Validation {
        static let minPasswordLength = 8
        static let handleMinLength = 3
        static let handleMaxLength = 20
        static let handleAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
    }

    var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedDisplayName: String { displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedHandle: String { handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    var isEmailValid: Bool {
        let value = trimmedEmail
        guard let at = value.firstIndex(of: "@"), at > value.startIndex else { return false }
        let domain = value[value.index(after: at)...]
        return domain.contains(".") && domain.count >= 3
    }

    var isPasswordNonEmpty: Bool { !password.isEmpty }

    var isPasswordStrongEnough: Bool {
        password.count >= Validation.minPasswordLength
    }

    var isDisplayNameValid: Bool { !trimmedDisplayName.isEmpty }

    var isHandleValid: Bool {
        let value = trimmedHandle
        guard value.count >= Validation.handleMinLength,
              value.count <= Validation.handleMaxLength else { return false }
        return value.unicodeScalars.allSatisfy { Validation.handleAllowed.contains($0) }
    }

    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    var canSubmitSignIn: Bool {
        isEmailValid && isPasswordNonEmpty && !isBusy
    }

    /// Profile step only — name + handle before collecting credentials.
    /// Photo is optional.
    var canContinueSignUpProfile: Bool {
        isDisplayNameValid && isHandleValid && !isBusy && !isPhotoBusy
    }

    var canSubmitSignUp: Bool {
        isDisplayNameValid && isHandleValid && isEmailValid && isPasswordStrongEnough && !isBusy
    }

    var canSubmitForgotPassword: Bool {
        isEmailValid && !isBusy
    }

    var canSubmitNewPassword: Bool {
        isPasswordStrongEnough && passwordsMatch && !isBusy
    }

    var hasPendingProfilePhoto: Bool { pendingProfilePhotoJPEG != nil }

    /// Sign-in form binding (AuthFormModel).
    var canSubmit: Bool { canSubmitSignIn }

    // MARK: - Session

    func restore() async { authedUser = await auth.restoreSession() }

    /// Called after a real sign-out so the gate is ready for a fresh session.
    /// `authedUser` must go back to nil: `AuthGateView` re-authenticates via
    /// `onChange(of: authedUser)`, and signing back in as the same user would
    /// otherwise look like no change and never fire.
    func signOutReset() {
        authedUser = nil
        clearAllFields()
        errorMessage = nil
        infoMessage = nil
        photoErrorMessage = nil
        pendingPasswordRecovery = false
        screen = .welcome
    }

    // MARK: - Profile photo (sign-up)

    /// Decode + compress picker bytes; upload happens after live prepare.
    func applyPickedProfilePhoto(rawData: Data) {
        guard !isPhotoBusy else { return }
        isPhotoBusy = true
        photoErrorMessage = nil
        defer { isPhotoBusy = false }
        guard let jpeg = ProfilePhotoProcessor.jpegData(from: rawData) else {
            photoErrorMessage = "Couldn't process that photo. Try another one."
            return
        }
        pendingProfilePhotoJPEG = jpeg
    }

    func clearPendingProfilePhoto() {
        pendingProfilePhotoJPEG = nil
        photoErrorMessage = nil
    }

    /// Takes ownership of the pending JPEG for post-prepare upload (nil if none).
    func consumePendingProfilePhoto() -> Data? {
        let data = pendingProfilePhotoJPEG
        pendingProfilePhotoJPEG = nil
        return data
    }

    // MARK: - Actions

    func submitSignIn() async {
        guard canSubmitSignIn else { return }
        await run(context: .signIn) {
            self.authedUser = try await self.auth.signIn(
                email: self.trimmedEmail,
                password: self.password
            )
        }
    }

    func signInWithGoogle() async {
        await runSocial {
            self.authedUser = try await self.auth.signInWithGoogle()
        }
    }

    func submitSignUp() async {
        guard canSubmitSignUp else { return }
        errorMessage = nil
        infoMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await auth.signUp(
                email: trimmedEmail,
                password: password,
                displayName: trimmedDisplayName,
                handle: trimmedHandle
            )
            switch result {
            case .authenticated(let user):
                // Keep pending photo for RootView prepare → Storage upload.
                authedUser = user
            case .confirmationRequired(let email):
                // Account created but no session yet — hold photo until first sign-in.
                self.email = email
                screen = .checkEmail
            }
        } catch {
            errorMessage = AuthUserMessage.message(for: error, context: .signUp)
        }
    }

    func submitForgotPassword() async {
        guard canSubmitForgotPassword else { return }
        errorMessage = nil
        infoMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await auth.resetPasswordRequest(email: trimmedEmail)
            infoMessage = AuthUserMessage.resetSent
        } catch {
            errorMessage = AuthUserMessage.message(for: error, context: .resetRequest)
        }
    }

    func submitNewPassword() async {
        guard canSubmitNewPassword else { return }
        await run(context: .updatePassword) {
            let user = try await self.auth.updatePassword(newPassword: self.password)
            self.pendingPasswordRecovery = false
            self.authedUser = user
        }
    }

    /// Returns true when the URL was handled as recovery or social/OAuth session.
    @discardableResult
    func handleOpenURL(_ url: URL) async -> Bool {
        errorMessage = nil
        infoMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await auth.handleAuthURL(url) {
            case .passwordRecovery:
                // Keep the recovery session on the service; clear VM identity so
                // the gate does not immediately enter the app before a new password.
                authedUser = nil
                password = ""
                confirmPassword = ""
                pendingPasswordRecovery = true
                screen = .setNewPassword
                return true
            case .signedIn(let user):
                pendingPasswordRecovery = false
                authedUser = user
                return true
            case .ignored:
                return false
            }
        } catch {
            errorMessage = AuthUserMessage.message(for: error, context: .openURL)
            pendingPasswordRecovery = false
            // Only force forgot-password for recovery-shaped links.
            if isLikelyRecoveryURL(url) {
                screen = .forgotPassword
            }
            return true
        }
    }

    // MARK: - Navigation

    func showSignIn() {
        clearCredentialFields()
        errorMessage = nil
        infoMessage = nil
        // Leaving sign-up for returning-user path: drop pending photo.
        clearPendingProfilePhoto()
        screen = .signIn
    }

    /// Email sign-up step 1: name + handle (+ optional photo).
    func showSignUp() {
        clearCredentialFields()
        displayName = ""
        handle = ""
        clearPendingProfilePhoto()
        errorMessage = nil
        infoMessage = nil
        screen = .signUpProfile
    }

    func continueSignUpProfile() {
        guard canContinueSignUpProfile else { return }
        errorMessage = nil
        infoMessage = nil
        // Fresh credentials when advancing; name/handle/photo stay.
        clearCredentialFields()
        screen = .signUpCredentials
    }

    /// Handle is lowercased and restricted to the production allow-set.
    func setHandle(_ raw: String) {
        handle = String(raw.lowercased().unicodeScalars.filter { Validation.handleAllowed.contains($0) })
    }

    func showWelcome() {
        clearAllFields()
        errorMessage = nil
        infoMessage = nil
        photoErrorMessage = nil
        pendingPasswordRecovery = false
        screen = .welcome
    }

    func showForgotPassword() {
        password = ""
        confirmPassword = ""
        errorMessage = nil
        infoMessage = nil
        screen = .forgotPassword
    }

    func showSignInFromCheckEmail() {
        password = ""
        errorMessage = nil
        infoMessage = nil
        // Keep pending photo so first sign-in after confirm can still upload it.
        screen = .signIn
    }

    /// Lab-style top-chrome back: deterministic parent, not a free history stack.
    func goBack() {
        errorMessage = nil
        infoMessage = nil
        switch screen {
        case .signUpProfile, .signIn:
            showWelcome()
        case .signUpCredentials:
            // Keep name/handle/photo; drop password so the user re-enters on return.
            clearCredentialFields()
            screen = .signUpProfile
        case .forgotPassword:
            showSignIn()
        case .setNewPassword:
            pendingPasswordRecovery = false
            showForgotPassword()
        case .welcome, .checkEmail:
            break
        }
    }

    // MARK: - Private

    private func run(context: AuthFailureContext, _ action: @escaping () async throws -> Void) async {
        errorMessage = nil
        infoMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
        } catch {
            errorMessage = AuthUserMessage.message(for: error, context: context)
        }
    }

    private func runSocial(_ action: @escaping () async throws -> Void) async {
        guard !isBusy else { return }
        errorMessage = nil
        infoMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
        } catch {
            if SocialAuthCancellation.isCancellation(error) { return }
            let message = AuthUserMessage.message(for: error, context: .socialSignIn)
            if !message.isEmpty {
                errorMessage = message
            }
        }
    }

    private func isLikelyRecoveryURL(_ url: URL) -> Bool {
        let lower = url.absoluteString.lowercased()
        return lower.contains("type=recovery")
            || url.path.lowercased().contains("reset")
            || (url.host?.lowercased() == "auth" && url.path.lowercased().contains("reset"))
    }

    private func clearCredentialFields() {
        email = ""
        password = ""
        confirmPassword = ""
    }

    private func clearAllFields() {
        clearCredentialFields()
        displayName = ""
        handle = ""
        clearPendingProfilePhoto()
    }
}
