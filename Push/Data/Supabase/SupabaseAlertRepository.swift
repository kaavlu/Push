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
        guard !rows.isEmpty else { return [] }

        let mutualCounts = Dictionary(
            uniqueKeysWithValues: try await store.incomingFriendRequestMutualCounts().map {
                ($0.request_id.lowercased(), max(0, $0.mutual_friend_count))
            }
        )

        var results: [FriendRequest] = []
        for row in rows {
            // The RPC is the current, server-authorized inbox snapshot. If a
            // warm friendship row no longer appears, the request was resolved
            // or cancelled after bootstrap and should not be rendered.
            guard let mutualFriendCount = mutualCounts[row.id.lowercased()] else { continue }
            guard let requesterID = row.requested_by else { continue }
            let profile = try await store.profileForFriendship(userID: requesterID)
            results.append(
                FriendRequest(
                    id: row.id,
                    requester: profile.person(),
                    recipientID: currentUserID,
                    createdAt: PushDateFormatting.parse(row.created_at) ?? Date(),
                    status: .pending,
                    isUnread: true,
                    mutualFriendCount: mutualFriendCount
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
        let invites = try await store.incomingGroupInvites().map { $0.groupInvite() }
        // Soft-hide invites from blocked inviters. Friendship rows are deleted
        // server-side on block, but group membership invites remain; resolve is
        // also guarded by private.is_blocked. Skip the list RPC when empty.
        guard !invites.isEmpty else { return [] }
        let blockedIDs = Set(
            (try await store.listBlockedUsers()).map { $0.id.lowercased() }
        )
        return invites
            .filter { invite in
                let inviter = invite.inviterID.lowercased()
                return inviter.isEmpty || !blockedIDs.contains(inviter)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func acceptGroupInvite(id: GroupInvite.ID) async throws {
        try await store.resolveGroupInvite(id: id, accept: true)
    }

    func denyGroupInvite(id: GroupInvite.ID) async throws {
        try await store.resolveGroupInvite(id: id, accept: false)
    }
}
