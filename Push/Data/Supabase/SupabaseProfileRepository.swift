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
    private let photoStorage: ProfilePhotoStoring?

    init(
        store: LiveDataStore,
        currentUserID: String,
        photoStorage: ProfilePhotoStoring? = nil
    ) {
        self.store = store
        self.currentUserID = currentUserID
        self.photoStorage = photoStorage
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

    func updateProfilePhoto(jpegData: Data) async throws {
        guard let photoStorage else { throw SupabaseRepositoryError.writeNotSupported }
        // LiveDataStore is @MainActor; hop explicitly for the sync cache read.
        let previousPath = await store.cachedImagePath(userID: currentUserID)
        let previousObject = ProfilePhotoPath.storageObjectPath(from: previousPath)

        // Upload first so a network failure never writes a broken URL.
        let uploaded = try await photoStorage.upload(userID: currentUserID, jpegData: jpegData)
        do {
            try await store.updateImagePath(
                userID: currentUserID, imageAssetPath: uploaded.publicURL
            )
        } catch {
            // Roll back the orphan object so Storage and the row stay aligned.
            try? await photoStorage.delete(objectPath: uploaded.objectPath)
            throw error
        }

        AvatarImageLoader.invalidate(path: previousPath)
        AvatarImageLoader.invalidate(path: uploaded.publicURL)
        if let previousObject, previousObject != uploaded.objectPath {
            try? await photoStorage.delete(objectPath: previousObject)
        }
    }

    func removeProfilePhoto() async throws {
        guard let photoStorage else { throw SupabaseRepositoryError.writeNotSupported }
        let previousPath = await store.cachedImagePath(userID: currentUserID)
        let previousObject = ProfilePhotoPath.storageObjectPath(from: previousPath)

        // Clear the row first so a failed Storage delete cannot leave a dead URL.
        try await store.updateImagePath(userID: currentUserID, imageAssetPath: nil)
        AvatarImageLoader.invalidate(path: previousPath)
        if let previousObject {
            try? await photoStorage.delete(objectPath: previousObject)
        }
    }

    func needsPostAuthOnboarding() async throws -> Bool {
        let row = try await store.profile(userID: currentUserID)
        return !row.hasCompletedOnboarding
    }

    func completeOnboarding() async throws {
        try await store.completeOnboarding(userID: currentUserID)
    }
}

private extension Array where Element == ProfileToggleItem {
    /// Copy (title/subtitle/icon) stays client-side in `ProfileScaffolding`;
    /// only the id → enabled state is worth persisting server-side.
    func enabledByID() -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.isEnabled) })
    }
}
