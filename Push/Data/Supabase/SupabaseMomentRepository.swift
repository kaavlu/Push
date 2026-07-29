//
//  SupabaseMomentRepository.swift
//  Push
//
//  Live Moments. Reads go through the 0026 read RPCs (one DTO per Moment with
//  block-filtered media and capability flags); writes go through the 0023
//  mutation RPCs. Moments are paginated on demand and deliberately absent from
//  `LiveDataStore.warm()` — a feed page is never part of session bootstrap.
//

import Foundation
import Supabase

final class SupabaseMomentRepository: MomentRepository {
    private let client: SupabaseClient
    private let currentUserID: Person.ID

    init(client: SupabaseClient, currentUserID: Person.ID) {
        self.client = client
        self.currentUserID = currentUserID
    }

    // MARK: - Reads

    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage {
        let pageSize = max(1, limit)
        // Ask for one extra row: its presence is what proves another page
        // exists, matching `LocalMomentRepository`'s cursor semantics.
        let rows: [MomentRow] = try await run("feedMoments") {
            try await client
                .rpc(
                    "feed_moments",
                    params: FeedMomentsParams(
                        p_cursor_activity: cursor.map { PushDateFormatting.string($0.lastActivityAt) },
                        p_cursor_id: cursor?.momentID,
                        p_limit: pageSize + 1,
                        p_group_id: groupID
                    )
                )
                .execute()
                .value
        }

        let page = rows.prefix(pageSize).map { $0.summary(viewerID: currentUserID) }
        let hasMore = rows.count > pageSize
        let nextCursor = hasMore ? page.last.map {
            MomentFeedCursor(lastActivityAt: $0.moment.lastActivityAt, momentID: $0.moment.id)
        } : nil
        return MomentFeedPage(moments: Array(page), nextCursor: nextCursor)
    }

    func hubMoments() async throws -> [MomentSummary] {
        let rows: [MomentRow] = try await run("hubMoments") {
            try await client
                .rpc("hub_moments", params: HubMomentsParams(p_limit: MomentReadConstants.hubLimit))
                .execute()
                .value
        }
        return rows.map { $0.summary(viewerID: currentUserID) }
    }

    func moment(id: Moment.ID) async throws -> MomentDetail {
        let row: MomentRow = try await run("momentDetail") {
            try await client
                .rpc("moment_detail", params: MomentDetailParams(p_moment_id: id))
                .execute()
                .value
        }
        return row.detail(viewerID: currentUserID)
    }

    // MARK: - Mutations

    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        try await run("createMoment") {
            try await client
                .rpc(
                    "create_moment",
                    params: CreateMomentParams(
                        p_title: draft.title,
                        p_location_text: draft.locationText,
                        p_push_id: draft.pushID,
                        p_tag_ids: draft.taggedPersonIDs,
                        p_media: draft.media.map(MomentMediaParam.init)
                    )
                )
                .execute()
                .value
        }
    }

    /// Per item, like the RPC: a rejected item leaves the earlier appends
    /// committed (contract §7.7 partial batch keeps successes).
    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {
        for item in items {
            try await run("appendMomentMedia") {
                try await client
                    .rpc(
                        "append_moment_media",
                        params: AppendMomentMediaParams(
                            p_moment_id: momentID,
                            p_kind: item.kind.rawValue,
                            p_storage_path: item.storagePath,
                            p_public_url: item.publicURL,
                            p_poster_path: item.posterPath,
                            p_poster_url: item.posterURL
                        )
                    )
                    .execute()
            }
        }
    }

    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws {
        try await run("updateMomentMetadata") {
            try await client
                .rpc(
                    "update_moment_metadata",
                    params: UpdateMomentMetadataParams(
                        p_moment_id: momentID, p_title: title, p_location_text: locationText
                    )
                )
                .execute()
        }
    }

    func addTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws {
        try await run("addMomentMembers") {
            try await client
                .rpc(
                    "add_moment_members",
                    params: AddMomentMembersParams(p_moment_id: momentID, p_person_ids: personIDs)
                )
                .execute()
        }
    }

    func removeTag(momentID: Moment.ID, personID: Person.ID) async throws {
        try await run("removeMomentMember") {
            try await client
                .rpc(
                    "remove_moment_member",
                    params: RemoveMomentMemberParams(p_moment_id: momentID, p_person_id: personID)
                )
                .execute()
        }
    }

    func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws {
        try await run("reorderMomentMedia") {
            try await client
                .rpc(
                    "reorder_moment_media",
                    params: ReorderMomentMediaParams(
                        p_moment_id: momentID, p_ordered_ids: orderedMediaIDs
                    )
                )
                .execute()
        }
    }

    func softDeleteMedia(mediaID: MomentMedia.ID) async throws {
        try await run("softDeleteMomentMedia") {
            try await client
                .rpc("soft_delete_moment_media", params: SoftDeleteMediaParams(p_media_id: mediaID))
                .execute()
        }
    }

    func softDeleteMoment(momentID: Moment.ID) async throws {
        try await run("softDeleteMoment") {
            try await client
                .rpc("soft_delete_moment", params: SoftDeleteMomentParams(p_moment_id: momentID))
                .execute()
        }
    }

    // MARK: - Internals

    /// Logs a redacted failure line, then rethrows the RPC exception as a
    /// domain error so view models can branch on it.
    @discardableResult
    private func run<T>(_ label: String, _ operation: () async throws -> T) async throws -> T {
        do {
            return try await PushLog.logged(label, operation: operation)
        } catch {
            throw MomentErrorMapper.map(error)
        }
    }
}

enum MomentReadConstants {
    /// Hub is a bounded list, not a paginated surface.
    static let hubLimit = 50
}

/// Maps 0023/0025 RPC exception strings to `MomentRepositoryError`.
///
/// The message is matched but never logged: PostgREST error bodies can embed
/// user input, and these strings are the RPCs' own fixed literals.
enum MomentErrorMapper {
    private static let table: [(needle: String, error: MomentRepositoryError)] = [
        ("not authenticated", .notAuthenticated),
        ("not found", .notFound),
        ("not allowed", .notAllowed),
        ("cannot remove creator", .cannotRemoveCreator),
        ("moment exists for push", .momentExistsForPush),
        ("invalid push", .invalidPush),
        ("invalid tag", .invalidTag),
        ("media required", .mediaRequired),
        ("media limit exceeded", .mediaLimitExceeded),
        ("media already registered", .invalidMediaPath),
        ("media type mismatch", .invalidMediaPath),
        ("invalid media path", .invalidMediaPath),
        ("invalid media kind", .invalidMediaPath),
        ("conflict", .conflict)
    ]

    static func map(_ error: Error) -> Error {
        guard let message = message(from: error)?.lowercased() else { return error }
        for entry in table where message.contains(entry.needle) {
            return entry.error
        }
        return error
    }

    private static func message(from error: Error) -> String? {
        if let postgrestError = error as? PostgrestError { return postgrestError.message }
        return nil
    }
}

// MARK: - RPC parameter payloads

private struct FeedMomentsParams: Encodable {
    let p_cursor_activity: String?
    let p_cursor_id: String?
    let p_limit: Int
    let p_group_id: String?
}

private struct HubMomentsParams: Encodable {
    let p_limit: Int
}

private struct MomentDetailParams: Encodable {
    let p_moment_id: String
}

private struct MomentMediaParam: Encodable {
    let kind: String
    let storage_path: String
    let public_url: String
    let poster_path: String?
    let poster_url: String?

    init(_ draft: MomentMediaDraft) {
        kind = draft.kind.rawValue
        storage_path = draft.storagePath
        // Sent for API compatibility; 0025 derives the stored URL from the path.
        public_url = draft.publicURL
        poster_path = draft.posterPath
        poster_url = draft.posterURL
    }
}

private struct CreateMomentParams: Encodable {
    let p_title: String
    let p_location_text: String
    let p_push_id: String?
    let p_tag_ids: [String]
    let p_media: [MomentMediaParam]
}

private struct AppendMomentMediaParams: Encodable {
    let p_moment_id: String
    let p_kind: String
    let p_storage_path: String
    let p_public_url: String
    let p_poster_path: String?
    let p_poster_url: String?
}

private struct UpdateMomentMetadataParams: Encodable {
    let p_moment_id: String
    let p_title: String
    let p_location_text: String
}

private struct AddMomentMembersParams: Encodable {
    let p_moment_id: String
    let p_person_ids: [String]
}

private struct RemoveMomentMemberParams: Encodable {
    let p_moment_id: String
    let p_person_id: String
}

private struct ReorderMomentMediaParams: Encodable {
    let p_moment_id: String
    let p_ordered_ids: [String]
}

private struct SoftDeleteMediaParams: Encodable {
    let p_media_id: String
}

private struct SoftDeleteMomentParams: Encodable {
    let p_moment_id: String
}
