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

    // Profile settings are the user's own row (`profiles_update_self` RLS), so
    // Day-1 writes are supported here unlike the reads-only social graph.
    func updateBasics(displayName: String, handle: String) async throws {
        try await client.from("profiles")
            .update(ProfileBasicsUpdate(first_name: displayName, handle: handle))
            .eq("id", value: currentUserID)
            .execute()
    }

    func updatePrivacy(
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) async throws {
        let payload = ProfileSettingsUpdate(
            settings_activity_visibility: activityVisibility.enabledByID(),
            settings_map_preferences: mapPreferences.enabledByID(),
            settings_close_friends: closeFriends.enabledByID()
        )
        try await client.from("profiles")
            .update(payload)
            .eq("id", value: currentUserID)
            .execute()
    }
}

private struct ProfileBasicsUpdate: Encodable {
    let first_name: String
    let handle: String
}

private struct ProfileSettingsUpdate: Encodable {
    let settings_activity_visibility: [String: Bool]
    let settings_map_preferences: [String: Bool]
    let settings_close_friends: [String: Bool]
}

private extension Array where Element == ProfileToggleItem {
    /// Copy (title/subtitle/icon) stays client-side in `ProfileScaffolding`;
    /// only the id → enabled state is worth persisting server-side.
    func enabledByID() -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.isEnabled) })
    }
}
