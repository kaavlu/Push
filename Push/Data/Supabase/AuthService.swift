// Push/Data/Supabase/AuthService.swift
import Foundation
import Supabase

struct AuthedUser: Equatable {
    let id: String
    let email: String?
}

protocol AuthService {
    var currentUser: AuthedUser? { get }
    func restoreSession() async -> AuthedUser?
    func signIn(email: String, password: String) async throws -> AuthedUser
    func signUp(email: String, password: String) async throws -> AuthedUser
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

    func signUp(email: String, password: String) async throws -> AuthedUser {
        let response = try await client.auth.signUp(email: email, password: password)
        let user = Self.map(response.user)
        currentUser = user
        return user
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    // NOTE: with `import Supabase`, the auth user type resolves as the unqualified
    // `User` (not `Auth.User`) in supabase-swift 2.51.0.
    private static func map(_ user: User) -> AuthedUser {
        AuthedUser(id: user.id.uuidString, email: user.email)
    }
}

/// In-memory double for tests/previews — never touches the network.
final class FakeAuthService: AuthService {
    private(set) var currentUser: AuthedUser?
    var restorable: AuthedUser?
    var signInResult: Result<AuthedUser, Error>?

    init(restorable: AuthedUser? = nil) { self.restorable = restorable }

    func restoreSession() async -> AuthedUser? { currentUser = restorable; return restorable }

    func signIn(email: String, password: String) async throws -> AuthedUser {
        switch signInResult ?? .success(AuthedUser(id: "user-\(email)", email: email)) {
        case .success(let u): currentUser = u; return u
        case .failure(let e): throw e
        }
    }

    func signUp(email: String, password: String) async throws -> AuthedUser {
        let u = AuthedUser(id: "user-\(email)", email: email); currentUser = u; return u
    }

    func signOut() async throws { currentUser = nil }
}
