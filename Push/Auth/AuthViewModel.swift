// Push/Auth/AuthViewModel.swift
import Foundation

/// Screens the production auth gate can show.
enum AuthGateScreen: Equatable {
    case welcome
    case signUp
    case signIn
    case checkEmail
    case forgotPassword
    case setNewPassword
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

    var canSubmitSignUp: Bool {
        isDisplayNameValid && isHandleValid && isEmailValid && isPasswordStrongEnough && !isBusy
    }

    var canSubmitForgotPassword: Bool {
        isEmailValid && !isBusy
    }

    var canSubmitNewPassword: Bool {
        isPasswordStrongEnough && passwordsMatch && !isBusy
    }

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
        pendingPasswordRecovery = false
        screen = .welcome
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
                authedUser = user
            case .confirmationRequired(let email):
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

    /// Returns true when the URL was handled as a password-recovery callback
    /// so the root can force the auth gate if the user was already in-app.
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
        screen = .signIn
    }

    func showSignUp() {
        clearCredentialFields()
        displayName = ""
        handle = ""
        errorMessage = nil
        infoMessage = nil
        screen = .signUp
    }

    func showWelcome() {
        clearAllFields()
        errorMessage = nil
        infoMessage = nil
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
        screen = .signIn
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
    }
}
