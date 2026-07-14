// Push/Auth/AuthViewModel.swift
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isBusy = false
    @Published private(set) var authedUser: AuthedUser?

    private let auth: AuthService
    init(auth: AuthService) { self.auth = auth }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isBusy
    }

    func restore() async { authedUser = await auth.restoreSession() }

    func submitSignIn() async { await run { try await self.auth.signIn(email: self.email, password: self.password) } }
    func submitSignUp() async { await run { try await self.auth.signUp(email: self.email, password: self.password) } }

    private func run(_ action: @escaping () async throws -> AuthedUser) async {
        errorMessage = nil; isBusy = true
        defer { isBusy = false }
        do { authedUser = try await action() }
        catch { errorMessage = "Couldn't sign in. Check your email and password." }
    }
}
