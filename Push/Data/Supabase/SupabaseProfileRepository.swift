//
//  SupabaseProfileRepository.swift
//  Push
//

import Foundation
import Supabase

/// Errors surfaced by Supabase-backed repositories. Day-1 is reads-only for
/// social data, so writes uniformly throw `.writeNotSupported`.
enum SupabaseRepositoryError: Error {
    case notFound
    case writeNotSupported
}

final class SupabaseProfileRepository: ProfileRepository {
    private let client: SupabaseClient
    private let currentUserID: String

    init(client: SupabaseClient, currentUserID: String) {
        self.client = client
        self.currentUserID = currentUserID
    }

    func userProfile() async throws -> UserProfile {
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().eq("id", value: currentUserID).limit(1).execute().value
        guard let row = rows.first else { throw SupabaseRepositoryError.notFound }
        return row.userProfile()
    }

    // Day 1 is reads-only for social data; writes are out of scope.
    func updateBasics(displayName: String, handle: String) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func updatePrivacy(
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}
