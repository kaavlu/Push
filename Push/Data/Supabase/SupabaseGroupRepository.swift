//
//  SupabaseGroupRepository.swift
//  Push
//

import Foundation
import Supabase

final class SupabaseGroupRepository: GroupRepository {
    private let store: LiveDataStore

    init(store: LiveDataStore) { self.store = store }

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

    // Task 4 will wire lifecycle RPCs + group-photos Storage.
    func renameGroup(groupID: FriendGroup.ID, name: String) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func updateGroupPhoto(groupID: FriendGroup.ID, jpegData: Data) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func removeGroupPhoto(groupID: FriendGroup.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func inviteToGroup(groupID: FriendGroup.ID, inviteeIDs: [Person.ID]) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func cancelGroupInvite(membershipID: GroupMembership.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func removeMember(groupID: FriendGroup.ID, personID: Person.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func leaveGroup(groupID: FriendGroup.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func transferOwnership(groupID: FriendGroup.ID, newOwnerID: Person.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func deleteGroup(groupID: FriendGroup.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}
