//
//  SupabaseGroupRepository.swift
//  Push
//

import Foundation

final class SupabaseGroupRepository: GroupRepository {
    private let store: LiveDataStore
    private let photoStorage: GroupPhotoStoring?

    init(store: LiveDataStore, photoStorage: GroupPhotoStoring? = nil) {
        self.store = store
        self.photoStorage = photoStorage
    }

    func groups() async throws -> [FriendGroup] {
        let rows = try await store.groups()
        return rows.map { $0.friendGroup() }
    }

    func memberships() async throws -> [GroupMembership] {
        let rows = try await store.memberships()
        return rows.map { $0.membership() }
    }

    func createGroup(
        name: String, imageAssetPath: String?, inviteeIDs: [Person.ID]
    ) async throws -> FriendGroup.ID {
        let row = try await store.createGroup(
            name: name, imageAssetPath: imageAssetPath, inviteeIDs: inviteeIDs
        )
        return row.id
    }

    func renameGroup(groupID: FriendGroup.ID, name: String) async throws {
        try await store.renameGroup(groupID: groupID, name: name)
    }

    func updateGroupPhoto(groupID: FriendGroup.ID, jpegData: Data) async throws {
        guard let photoStorage else { throw SupabaseRepositoryError.writeNotSupported }
        // LiveDataStore is @MainActor; hop explicitly for the sync cache read.
        let previousPath = await store.cachedGroupImagePath(groupID: groupID)
        let previousObject = GroupPhotoPath.storageObjectPath(from: previousPath)

        // Upload first so a network failure never writes a broken URL.
        let uploaded = try await photoStorage.upload(groupID: groupID, jpegData: jpegData)
        do {
            try await store.setGroupImage(groupID: groupID, imagePath: uploaded.publicURL)
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

    func removeGroupPhoto(groupID: FriendGroup.ID) async throws {
        guard let photoStorage else { throw SupabaseRepositoryError.writeNotSupported }
        let previousPath = await store.cachedGroupImagePath(groupID: groupID)
        let previousObject = GroupPhotoPath.storageObjectPath(from: previousPath)

        // Clear the row first so a failed Storage delete cannot leave a dead URL.
        try await store.setGroupImage(groupID: groupID, imagePath: nil)
        AvatarImageLoader.invalidate(path: previousPath)
        if let previousObject {
            try? await photoStorage.delete(objectPath: previousObject)
        }
    }

    func inviteToGroup(groupID: FriendGroup.ID, inviteeIDs: [Person.ID]) async throws {
        try await store.inviteToGroup(groupID: groupID, inviteeIDs: inviteeIDs)
    }

    func cancelGroupInvite(membershipID: GroupMembership.ID) async throws {
        try await store.cancelGroupInvite(membershipID: membershipID)
    }

    func removeMember(groupID: FriendGroup.ID, personID: Person.ID) async throws {
        try await store.removeGroupMember(groupID: groupID, personID: personID)
    }

    func leaveGroup(groupID: FriendGroup.ID) async throws {
        try await store.leaveGroup(groupID: groupID)
    }

    func transferOwnership(groupID: FriendGroup.ID, newOwnerID: Person.ID) async throws {
        try await store.transferGroupOwnership(groupID: groupID, newOwnerID: newOwnerID)
    }

    func deleteGroup(groupID: FriendGroup.ID) async throws {
        let previousPath = await store.cachedGroupImagePath(groupID: groupID)
        let previousObject = GroupPhotoPath.storageObjectPath(from: previousPath)
        try await store.deleteGroup(groupID: groupID)
        AvatarImageLoader.invalidate(path: previousPath)
        if let previousObject {
            try? await photoStorage?.delete(objectPath: previousObject)
        }
    }
}
