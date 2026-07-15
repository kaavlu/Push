// Push/Data/Supabase/EmptyLiveRepositories.swift
import Foundation

/// Day-1 live mode has no feed (out of scope). Reads are empty. This keeps
/// mock data out of authenticated sessions (R1). Pushes are live-persisted —
/// see `SupabasePushRepository`.
final class EmptyLiveFeedRepository: FeedRepository {
    func events() async throws -> [FeedEvent] { [] }
}

/// Kept for isolation tests that want an inert alerts surface without network.
final class EmptyLiveAlertRepository: AlertRepository {
    func incomingFriendRequests() async throws -> [FriendRequest] { [] }
    func acceptFriendRequest(id: FriendRequest.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
    func denyFriendRequest(id: FriendRequest.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}
