// Push/Data/Supabase/EmptyLiveRepositories.swift
import Foundation

/// Day-1 live mode has no feed (out of scope). Reads are empty. This keeps
/// mock data out of authenticated sessions (R1). Pushes are live-persisted —
/// see `SupabasePushRepository`.
final class EmptyLiveFeedRepository: FeedRepository {
    func events() async throws -> [FeedEvent] { [] }
}

/// Live Moments have no repository yet (S5). Reads are empty and writes throw
/// rather than silently succeeding — an authenticated session must never fall
/// back to mock albums or Feed carousel fixtures (R1).
final class EmptyLiveMomentRepository: MomentRepository {
    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage { .empty }

    func hubMoments() async throws -> [MomentSummary] { [] }

    func moment(id: Moment.ID) async throws -> MomentDetail {
        throw MomentRepositoryError.notFound
    }

    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func addTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func removeTag(momentID: Moment.ID, personID: Person.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func softDeleteMedia(mediaID: MomentMedia.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }

    func softDeleteMoment(momentID: Moment.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
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
    func incomingGroupInvites() async throws -> [GroupInvite] { [] }
    func acceptGroupInvite(id: GroupInvite.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
    func denyGroupInvite(id: GroupInvite.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}
