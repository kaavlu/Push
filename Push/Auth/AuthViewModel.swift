// Push/Auth/AuthViewModel.swift
import Foundation

/// The two screens the production auth gate can show. Mirrors the DEBUG
/// onboarding lab's welcome ⇄ signIn split (`OnboardingScreen`), but scoped
/// to only what's live-wired today.
enum AuthGateScreen: Equatable {
    case welcome
    case signIn
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isBusy = false
    @Published private(set) var authedUser: AuthedUser?
    @Published private(set) var screen: AuthGateScreen = .welcome
    @Published var showingComingSoon = false

    private let auth: AuthService
    init(auth: AuthService) { self.auth = auth }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isBusy
    }

    func restore() async { authedUser = await auth.restoreSession() }

    /// Called after a real sign-out so the gate is ready for a fresh session.
    /// `authedUser` must go back to nil: `AuthGateView` re-authenticates via
    /// `onChange(of: authedUser)`, and signing back in as the same user would
    /// otherwise look like no change and never fire.
    func signOutReset() {
        authedUser = nil
        email = ""
        password = ""
        errorMessage = nil
        screen = .welcome
    }

    func submitSignIn() async { await run { try await self.auth.signIn(email: self.email, password: self.password) } }
    func submitSignUp() async { await run { try await self.auth.signUp(email: self.email, password: self.password) } }

    private func run(_ action: @escaping () async throws -> AuthedUser) async {
        errorMessage = nil; isBusy = true
        defer { isBusy = false }
        do { authedUser = try await action() }
        catch { errorMessage = "Couldn't sign in. Check your email and password." }
    }

    // MARK: Gate navigation

    /// Returning-user entry: welcome (sign-up) → sign-in.
    func showSignIn() {
        screen = .signIn
    }

    /// Sign-in → sign-up switch link. Clears returning-user fields so the
    /// two entry points never bleed into each other (mirrors the lab's
    /// `goToSignUp`).
    func showWelcome() {
        email = ""
        password = ""
        errorMessage = nil
        screen = .welcome
    }

    /// Sign-up (Apple/Google/mobile) and the sign-in screen's social
    /// buttons aren't wired to real auth yet — surface a "coming soon"
    /// notice instead of silently doing nothing.
    func requestUnavailable() {
        showingComingSoon = true
    }
}
