// Push/Data/Supabase/FakeAuthService.swift
import Foundation

/// In-memory double for tests/previews — never touches the network.
final class FakeAuthService: AuthService {
    private(set) var currentUser: AuthedUser?
    var restorable: AuthedUser?
    var signInResult: Result<AuthedUser, Error>?
    var signUpResult: Result<SignUpResult, Error>?
    var signInWithAppleResult: Result<AuthedUser, Error>?
    var signInWithGoogleResult: Result<AuthedUser, Error>?
    var resetPasswordResult: Result<Void, Error>?
    var updatePasswordResult: Result<AuthedUser, Error>?
    var authURLResult: Result<AuthURLResult, Error>?
    var deleteAccountResult: Result<Void, Error>?

    init(restorable: AuthedUser? = nil) { self.restorable = restorable }

    func restoreSession() async -> AuthedUser? { currentUser = restorable; return restorable }

    func signIn(email: String, password: String) async throws -> AuthedUser {
        switch signInResult ?? .success(AuthedUser(id: "user-\(email)", email: email)) {
        case .success(let u): currentUser = u; return u
        case .failure(let e): throw e
        }
    }

    func signUp(
        email: String,
        password: String,
        displayName: String,
        handle: String
    ) async throws -> SignUpResult {
        _ = displayName
        _ = handle
        let fallback = SignUpResult.authenticated(AuthedUser(id: "user-\(email)", email: email))
        switch signUpResult ?? .success(fallback) {
        case .success(let result):
            if case .authenticated(let u) = result { currentUser = u }
            else { currentUser = nil }
            return result
        case .failure(let e):
            throw e
        }
    }

    func signInWithApple() async throws -> AuthedUser {
        switch signInWithAppleResult
            ?? .success(AuthedUser(id: "apple-user", email: "apple@push.test"))
        {
        case .success(let u): currentUser = u; return u
        case .failure(let e): throw e
        }
    }

    func signInWithGoogle() async throws -> AuthedUser {
        switch signInWithGoogleResult
            ?? .success(AuthedUser(id: "google-user", email: "google@push.test"))
        {
        case .success(let u): currentUser = u; return u
        case .failure(let e): throw e
        }
    }

    func resetPasswordRequest(email: String) async throws {
        _ = email
        if case .failure(let e) = resetPasswordResult { throw e }
    }

    func updatePassword(newPassword: String) async throws -> AuthedUser {
        _ = newPassword
        switch updatePasswordResult
            ?? .success(currentUser ?? AuthedUser(id: "recovered", email: "r@push.test"))
        {
        case .success(let u): currentUser = u; return u
        case .failure(let e): throw e
        }
    }

    func handleAuthURL(_ url: URL) async throws -> AuthURLResult {
        _ = url
        switch authURLResult ?? .success(.passwordRecovery) {
        case .success(let r):
            switch r {
            case .passwordRecovery:
                currentUser = currentUser ?? AuthedUser(id: "recovered", email: "r@push.test")
            case .signedIn(let user):
                currentUser = user
            case .ignored:
                break
            }
            return r
        case .failure(let e):
            throw e
        }
    }

    func signOut() async throws { currentUser = nil }

    func deleteAccount() async throws {
        switch deleteAccountResult ?? .success(()) {
        case .success:
            currentUser = nil
        case .failure(let error):
            throw error
        }
    }
}
