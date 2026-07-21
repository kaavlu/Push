//
//  SupabaseAlertRepository.swift
//  Push
//

import Foundation
import Supabase

/// Live friend-request inbox. Reads pending incoming rows and resolves them
/// through the same RPCs / store revision path as Add Friends.
final class SupabaseAlertRepository: AlertRepository {
    private let store: LiveDataStore
    private let currentUserID: String

    init(store: LiveDataStore, currentUserID: String) {
        self.store = store
        self.currentUserID = currentUserID
    }

    func incomingFriendRequests() async throws -> [FriendRequest] {
        let rows = try await store.friendships()
            .filter { $0.isPending && $0.involves(currentUserID) && !$0.isRequester(currentUserID) }

        var results: [FriendRequest] = []
        for row in rows {
            guard let requesterID = row.requested_by else { continue }
            let profile = try await store.profileForFriendship(userID: requesterID)
            results.append(
                FriendRequest(
                    id: row.id,
                    requester: profile.person(),
                    recipientID: currentUserID,
                    createdAt: PushDateFormatting.parse(row.created_at) ?? Date(),
                    status: .pending,
                    isUnread: true
                )
            )
        }
        return results.sorted { $0.createdAt > $1.createdAt }
    }

    func acceptFriendRequest(id: FriendRequest.ID) async throws {
        try await store.resolveFriendRequest(id: id, accept: true)
    }

    func denyFriendRequest(id: FriendRequest.ID) async throws {
        try await store.resolveFriendRequest(id: id, accept: false)
    }

    func incomingGroupInvites() async throws -> [GroupInvite] {
        let rows = try await store.incomingGroupInvites()
        return rows.map { $0.groupInvite() }.sorted { $0.createdAt > $1.createdAt }
    }

    func acceptGroupInvite(id: GroupInvite.ID) async throws {
        try await store.resolveGroupInvite(id: id, accept: true)
    }

    func denyGroupInvite(id: GroupInvite.ID) async throws {
        try await store.resolveGroupInvite(id: id, accept: false)
    }
}
