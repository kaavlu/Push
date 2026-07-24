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
    /// OAuth / non-recovery callback established a session (enter the app).
    case signedIn(AuthedUser)
    case ignored
}

/// Context for mapping GoTrue / network failures to calm user-facing copy.
enum AuthFailureContext: Equatable {
    case signIn
    case signUp
    case socialSignIn
    case resetRequest
    case updatePassword
    case openURL
    case deleteAccount
}

enum AuthRedirect {
    static let scheme = "pushapp"
    static let resetURLString = "pushapp://auth/reset"
    static var resetURL: URL { URL(string: resetURLString)! }
    /// OAuth provider return (Google via ASWebAuthenticationSession).
    static let oauthCallbackURLString = "pushapp://auth/callback"
    static var oauthCallbackURL: URL { URL(string: oauthCallbackURLString)! }
}

enum AuthUserMessage {
    static let signInFailed = "Couldn't sign in. Check your email and password."
    static let emailTaken = "That email already has an account. Try signing in."
    static let socialAccountConflict =
        "That account is already in use. Try signing in with email, or use a different provider."
    static let socialFailed = "Couldn't complete sign-in. Try again."
    static let weakPassword = "Choose a stronger password (at least 8 characters)."
    static let handleTaken = "That handle is taken. Try another."
    static let rateLimited = "Too many attempts. Wait a moment and try again."
    static let generic = "Something went wrong. Check your connection and try again."
    static let resetSent = "If an account exists for that email, we sent a reset link."
    static let resetLinkExpired = "This reset link expired. Request a new one."
    static let deleteFailed = "Couldn't delete your account. Check your connection and try again."

    static func message(for error: Error, context: AuthFailureContext) -> String {
        if context == .deleteAccount { return deleteFailed }
        if SocialAuthCancellation.isCancellation(error) { return "" }
        if let social = error as? SocialAuthError {
            switch social {
            case .cancelled: return ""
            case .missingIDToken, .unavailable: return socialFailed
            }
        }
        if let authError = error as? AuthError {
            return message(for: authError, context: context)
        }
        return context == .socialSignIn ? socialFailed : generic
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
            return context == .socialSignIn ? socialFailed : resetLinkExpired
        default:
            return context == .socialSignIn ? socialFailed : generic
        }
    }

    private static func message(forCode code: ErrorCode, context: AuthFailureContext) -> String {
        if code == .invalidCredentials { return signInFailed }
        if code == .userAlreadyExists || code == .emailExists {
            return emailTaken
        }
        if code == .identityAlreadyExists {
            return socialAccountConflict
        }
        if code == .weakPassword { return weakPassword }
        if code == .overRequestRateLimit || code == .overEmailSendRateLimit {
            return rateLimited
        }
        if code == .emailNotConfirmed, context == .signIn {
            return "Confirm your email, then try signing in."
        }
        // Unique handle collisions may surface as a generic API conflict.
        if code == .conflict, context == .signUp { return handleTaken }
        if context == .socialSignIn { return socialFailed }
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
    /// Google via Supabase OAuth + system web authentication session.
    func signInWithGoogle() async throws -> AuthedUser
    func resetPasswordRequest(email: String) async throws
    func updatePassword(newPassword: String) async throws -> AuthedUser
    func handleAuthURL(_ url: URL) async throws -> AuthURLResult
    func signOut() async throws
    /// Permanently deletes the authenticated Auth user and related app data.
    /// Must not clear the local session until the server operation succeeds.
    func deleteAccount() async throws
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

    @MainActor
    func signInWithGoogle() async throws -> AuthedUser {
        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: AuthRedirect.oauthCallbackURL
            ) { webSession in
                webSession.prefersEphemeralWebBrowserSession = false
            }
            let user = Self.map(session.user)
            currentUser = user
            return user
        } catch {
            if SocialAuthCancellation.isCancellation(error) {
                throw SocialAuthError.cancelled
            }
            throw error
        }
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
        // Recovery: pushapp://auth/reset… or type=recovery. OAuth: pushapp://auth/callback…
        let lower = url.absoluteString.lowercased()
        let isResetRoute =
            lower.contains("type=recovery")
            || url.path.lowercased().contains("reset")
            || (url.host?.lowercased() == "auth" && url.path.lowercased().contains("reset"))
        let isOAuthCallback =
            url.path.lowercased().contains("callback")
            || lower.contains("auth/callback")
        guard isResetRoute || isOAuthCallback || looksLikeAuthCallback(url) else {
            return .ignored
        }

        do {
            let session = try await client.auth.session(from: url)
            let user = Self.map(session.user)
            currentUser = user
            if isResetRoute { return .passwordRecovery }
            return .signedIn(user)
        } catch {
            // Non-auth pushapp URLs should not surface as expired-link errors.
            if looksLikeAuthCallback(url) || isResetRoute || isOAuthCallback { throw error }
            return .ignored
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    func deleteAccount() async throws {
        // RPC first — never clear local session if the backend failed.
        try await client.rpc("delete_account").execute()
        currentUser = nil
        // Session rows are already gone with auth.users; best-effort local wipe.
        try? await client.auth.signOut()
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

