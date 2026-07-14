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
    private let store: LiveDataStore
    private let currentUserID: String

    init(store: LiveDataStore, currentUserID: String) {
        self.store = store
        self.currentUserID = currentUserID
    }

    func userProfile() async throws -> UserProfile {
        try await store.profile(userID: currentUserID).userProfile()
    }

    // Profile settings are the user's own row (`profiles_update_self` RLS), so
    // Day-1 writes are supported here unlike the reads-only social graph.
    func updateBasics(displayName: String, handle: String) async throws {
        try await store.updateBasics(userID: currentUserID, displayName: displayName, handle: handle)
    }

    func updatePrivacy(
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) async throws {
        let payload = ProfileSettingsPayload(
            settings_activity_visibility: activityVisibility.enabledByID(),
            settings_map_preferences: mapPreferences.enabledByID(),
            settings_close_friends: closeFriends.enabledByID()
        )
        try await store.updatePrivacy(userID: currentUserID, payload: payload)
    }
}

private extension Array where Element == ProfileToggleItem {
    /// Copy (title/subtitle/icon) stays client-side in `ProfileScaffolding`;
    /// only the id → enabled state is worth persisting server-side.
    func enabledByID() -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.isEnabled) })
    }
}
