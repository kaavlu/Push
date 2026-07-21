// Push/Data/Supabase/AuthService.swift
import Foundation
import Supabase

struct AuthedUser: Equatable {
    let id: String
    let email: String?
}

/// Outcome of email/password sign-up. Confirmation-required projects return
/// a user without a session; autoconfirm returns a full session.
enum SignUpResult: Equatable {
    case authenticated(AuthedUser)
    case confirmationRequired(email: String)
}

/// Result of handling an inbound custom-scheme auth URL.
enum AuthURLResult: Equatable {
    case passwordRecovery
    case ignored
}

/// Context for mapping GoTrue / network failures to calm user-facing copy.
enum AuthFailureContext: Equatable {
    case signIn
    case signUp
    case resetRequest
    case updatePassword
    case openURL
}

enum AuthRedirect {
    static let scheme = "pushapp"
    static let resetURLString = "pushapp://auth/reset"
    static var resetURL: URL { URL(string: resetURLString)! }
}

enum AuthUserMessage {
    static let signInFailed = "Couldn't sign in. Check your email and password."
    static let emailTaken = "That email already has an account. Try signing in."
    static let weakPassword = "Choose a stronger password (at least 8 characters)."
    static let handleTaken = "That handle is taken. Try another."
    static let rateLimited = "Too many attempts. Wait a moment and try again."
    static let generic = "Something went wrong. Check your connection and try again."
    static let resetSent = "If an account exists for that email, we sent a reset link."
    static let resetLinkExpired = "This reset link expired. Request a new one."

    static func message(for error: Error, context: AuthFailureContext) -> String {
        if let authError = error as? AuthError {
            return message(for: authError, context: context)
        }
        return generic
    }

    private static func message(for error: AuthError, context: AuthFailureContext) -> String {
        switch error {
        case .weakPassword:
            return weakPassword
        case .sessionMissing:
            return context == .updatePassword || context == .openURL ? resetLinkExpired : generic
        case .api(_, let code, _, _):
            return message(forCode: code, context: context)
        case .pkceGrantCodeExchange, .implicitGrantRedirect:
            return resetLinkExpired
        default:
            return generic
        }
    }

    private static func message(forCode code: ErrorCode, context: AuthFailureContext) -> String {
        if code == .invalidCredentials { return signInFailed }
        if code == .userAlreadyExists { return emailTaken }
        if code == .weakPassword { return weakPassword }
        if code == .overRequestRateLimit || code == .overEmailSendRateLimit {
            return rateLimited
        }
        if code == .emailNotConfirmed, context == .signIn {
            return "Confirm your email, then try signing in."
        }
        // Unique handle collisions may surface as a generic API conflict.
        if code == .conflict, context == .signUp { return handleTaken }
        return generic
    }
}

protocol AuthService {
    var currentUser: AuthedUser? { get }
    func restoreSession() async -> AuthedUser?
    func signIn(email: String, password: String) async throws -> AuthedUser
    func signUp(
        email: String,
        password: String,
        displayName: String,
        handle: String
    ) async throws -> SignUpResult
    func resetPasswordRequest(email: String) async throws
    func updatePassword(newPassword: String) async throws -> AuthedUser
    func handleAuthURL(_ url: URL) async throws -> AuthURLResult
    func signOut() async throws
}

final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient
    private(set) var currentUser: AuthedUser?

    init(client: SupabaseClient = SupabaseClientProvider.shared.client) {
        self.client = client
    }

    func restoreSession() async -> AuthedUser? {
        // The SDK loads any persisted session; `session` returns it or throws if none.
        guard let session = try? await client.auth.session else { return nil }
        let user = Self.map(session.user)
        currentUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> AuthedUser {
        let session = try await client.auth.signIn(email: email, password: password)
        let user = Self.map(session.user)
        currentUser = user
        return user
    }

    func signUp(
        email: String,
        password: String,
        displayName: String,
        handle: String
    ) async throws -> SignUpResult {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "first_name": .string(displayName),
                "handle": .string(handle),
            ],
            redirectTo: AuthRedirect.resetURL
        )
        if let session = response.session {
            let user = Self.map(session.user)
            currentUser = user
            return .authenticated(user)
        }
        // User row created; email confirmation still required before a session exists.
        currentUser = nil
        return .confirmationRequired(email: email)
    }

    func resetPasswordRequest(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: AuthRedirect.resetURL
        )
    }

    func updatePassword(newPassword: String) async throws -> AuthedUser {
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
        let session = try await client.auth.session
        let user = Self.map(session.user)
        currentUser = user
        return user
    }

    func handleAuthURL(_ url: URL) async throws -> AuthURLResult {
        guard url.scheme?.lowercased() == AuthRedirect.scheme else { return .ignored }
        // Recovery emails use pushapp://auth/reset (host "auth", path "/reset").
        let isResetRoute =
            url.host?.lowercased() == "auth"
            || url.path.lowercased().contains("reset")
            || url.absoluteString.lowercased().contains("type=recovery")
        guard isResetRoute || looksLikeAuthCallback(url) else { return .ignored }

        do {
            let session = try await client.auth.session(from: url)
            currentUser = Self.map(session.user)
            return .passwordRecovery
        } catch {
            // Non-auth pushapp URLs should not surface as expired-link errors.
            if looksLikeAuthCallback(url) || isResetRoute { throw error }
            return .ignored
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    private func looksLikeAuthCallback(_ url: URL) -> Bool {
        let s = url.absoluteString
        return s.contains("code=")
            || s.contains("access_token")
            || s.contains("refresh_token")
            || s.contains("type=")
    }

    // NOTE: with `import Supabase`, the auth user type resolves as the unqualified
    // `User` (not `Auth.User`) in supabase-swift 2.51.0.
    private static func map(_ user: User) -> AuthedUser {
        // Lowercase to match PostgREST's UUID rendering: identity flows into
        // `AppDataContainer.currentUserID`, and any future live read that compares a
        // DB-sourced id against it must not fail on `UUID.uuidString`'s uppercase form.
        AuthedUser(id: user.id.uuidString.lowercased(), email: user.email)
    }
}

/// In-memory double for tests/previews — never touches the network.
final class FakeAuthService: AuthService {
    private(set) var currentUser: AuthedUser?
    var restorable: AuthedUser?
    var signInResult: Result<AuthedUser, Error>?
    var signUpResult: Result<SignUpResult, Error>?
    var resetPasswordResult: Result<Void, Error>?
    var updatePasswordResult: Result<AuthedUser, Error>?
    var authURLResult: Result<AuthURLResult, Error>?

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

    func resetPasswordRequest(email: String) async throws {
        _ = email
        if case .failure(let e) = resetPasswordResult { throw e }
    }

    func updatePassword(newPassword: String) async throws -> AuthedUser {
        _ = newPassword
        switch updatePasswordResult ?? .success(currentUser ?? AuthedUser(id: "recovered", email: "r@push.test")) {
        case .success(let u): currentUser = u; return u
        case .failure(let e): throw e
        }
    }

    func handleAuthURL(_ url: URL) async throws -> AuthURLResult {
        _ = url
        switch authURLResult ?? .success(.passwordRecovery) {
        case .success(let r):
            if r == .passwordRecovery {
                currentUser = currentUser ?? AuthedUser(id: "recovered", email: "r@push.test")
            }
            return r
        case .failure(let e):
            throw e
        }
    }

    func signOut() async throws { currentUser = nil }
}
