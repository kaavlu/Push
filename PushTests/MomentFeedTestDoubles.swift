//
//  MomentFeedTestDoubles.swift
//  PushTests
//
//  Shared doubles for the repository-backed Feed (Issue #125): a cursor-chain
//  fake repository and one album expressed as both mock seed rows and the live
//  `feed_moments` DTO.
//

import Foundation
@testable import Push

/// Serves a canned page chain keyed by cursor, so repeated loads are idempotent
/// (the initializer's bootstrap load must not shift page boundaries) while page
/// boundaries and cursors stay explicit.
@MainActor
final class FakeMomentRepository: MomentRepository {
    struct FeedCall: Equatable {
        let cursor: MomentFeedCursor?
        let limit: Int
        let groupID: FriendGroup.ID?
    }

    var feedCalls: [FeedCall] = []
    /// Consumed by the next `feedPage` call, which then throws.
    var failNextFeedPage = false
    /// Reassign to change what page one serves (refresh / filter change).
    var pages: [MomentFeedPage]

    init(pages: [MomentFeedPage]) {
        self.pages = pages
    }

    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage {
        if failNextFeedPage {
            failNextFeedPage = false
            throw MomentRepositoryError.notAuthenticated
        }
        feedCalls.append(FeedCall(cursor: cursor, limit: limit, groupID: groupID))
        guard let cursor else { return pages.first ?? .empty }
        // The page whose `nextCursor` produced this request.
        guard let index = pages.firstIndex(where: { $0.nextCursor == cursor }),
              pages.indices.contains(index + 1) else {
            return .empty
        }
        return pages[index + 1]
    }

    func hubMoments() async throws -> [MomentSummary] { [] }

    func moment(id: Moment.ID) async throws -> MomentDetail {
        throw MomentRepositoryError.notFound
    }

    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        throw MomentRepositoryError.notAllowed
    }
    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {
        throw MomentRepositoryError.notAllowed
    }
    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws {
        throw MomentRepositoryError.notAllowed
    }
    func addTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws {
        throw MomentRepositoryError.notAllowed
    }
    func removeTag(momentID: Moment.ID, personID: Person.ID) async throws {
        throw MomentRepositoryError.notAllowed
    }
    func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws {
        throw MomentRepositoryError.notAllowed
    }
    func softDeleteMedia(mediaID: MomentMedia.ID) async throws {
        throw MomentRepositoryError.notAllowed
    }
    func softDeleteMoment(momentID: Moment.ID) async throws {
        throw MomentRepositoryError.notAllowed
    }
}

/// One album expressed twice — as mock seed rows and as the `feed_moments` DTO —
/// so mock and live cards can be compared field for field.
enum MomentParityFixture {
    static let momentID = "moment-parity"
    static let creator = "ram"
    static let viewer = SeedIDs.currentUser

    /// Whole-second instant, so the ISO round-trip through the DTO is exact.
    static let publishedAt: Date = {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: publishedISO) ?? .distantPast
    }()

    static let publishedISO: String = {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date().addingTimeInterval(-oneHour))
    }()

    private static let oneHour: TimeInterval = 3600

    private static let photoURL = "https://cdn.invalid/parity-a.jpg"
    private static let videoPosterURL = "https://cdn.invalid/parity-b-poster.jpg"

    /// Exactly one visible Moment: creator is an accepted friend, the viewer is
    /// tagged and contributed.
    static func seed() -> SeedData {
        var seed = SeedData.standard()
        seed.moments = [
            Moment(
                id: momentID,
                creatorID: creator,
                title: "Rooftop",
                locationText: "Rooftop bar",
                placeID: nil,
                pushID: nil,
                publishedAt: publishedAt,
                lastActivityAt: publishedAt,
                deletedAt: nil
            )
        ]
        seed.momentMembers = [creator, viewer].enumerated().map { index, personID in
            MomentMember(
                id: "\(momentID)-member-\(personID)",
                momentID: momentID,
                personID: personID,
                taggedAt: publishedAt.addingTimeInterval(TimeInterval(index))
            )
        }
        seed.momentMedia = [
            MomentMedia(
                id: "\(momentID)-media-0", momentID: momentID, uploaderID: creator,
                kind: .photo, storagePath: "\(momentID)/\(creator)/a.jpg",
                publicURL: photoURL, posterPath: nil, posterURL: nil,
                sortOrder: 0, createdAt: publishedAt, deletedAt: nil
            ),
            MomentMedia(
                id: "\(momentID)-media-1", momentID: momentID, uploaderID: viewer,
                kind: .video, storagePath: "\(momentID)/\(viewer)/b.mp4",
                publicURL: "https://cdn.invalid/parity-b.mp4",
                posterPath: "\(momentID)/\(viewer)/b-poster.jpg",
                posterURL: videoPosterURL,
                sortOrder: 1, createdAt: publishedAt, deletedAt: nil
            )
        ]
        return seed
    }

    static func feedJSON() -> String {
        """
        {
          "id": "\(momentID)",
          "creator_id": "\(creator)",
          "title": "Rooftop",
          "location_text": "Rooftop bar",
          "place_id": null,
          "push_id": null,
          "published_at": "\(publishedISO)",
          "last_activity_at": "\(publishedISO)",
          "tagged_person_ids": ["\(creator)", "\(viewer)"],
          "media": [
            {
              "id": "\(momentID)-media-0",
              "moment_id": "\(momentID)",
              "uploader_id": "\(creator)",
              "kind": "photo",
              "storage_path": "\(momentID)/\(creator)/a.jpg",
              "public_url": "\(photoURL)",
              "poster_path": null,
              "poster_url": null,
              "sort_order": 0,
              "created_at": "\(publishedISO)"
            },
            {
              "id": "\(momentID)-media-1",
              "moment_id": "\(momentID)",
              "uploader_id": "\(viewer)",
              "kind": "video",
              "storage_path": "\(momentID)/\(viewer)/b.mp4",
              "public_url": "https://cdn.invalid/parity-b.mp4",
              "poster_path": "\(momentID)/\(viewer)/b-poster.jpg",
              "poster_url": "\(videoPosterURL)",
              "sort_order": 1,
              "created_at": "\(publishedISO)"
            }
          ],
          "visible_media_count": 2,
          "capabilities": {
            "canView": true,
            "canAddMedia": true,
            "canEditTags": true,
            "canEditMetadata": false,
            "canReorderMedia": true,
            "canDeleteMoment": false,
            "youContributed": true,
            "showOpenForAddsChip": false
          }
        }
        """
    }
}

enum FeedTestMoment {
    static let publishedAt = Date(timeIntervalSince1970: 1_800_000_000)

    static func summary(id: Moment.ID) -> MomentSummary {
        let media = MomentMedia(
            id: "\(id)-media-0",
            momentID: id,
            uploaderID: "self",
            kind: .photo,
            storagePath: "\(id)/self/0.jpg",
            publicURL: "https://example.invalid/\(id)/0.jpg",
            posterPath: nil,
            posterURL: nil,
            sortOrder: 0,
            createdAt: publishedAt,
            deletedAt: nil
        )
        return MomentSummary(
            moment: Moment(
                id: id,
                creatorID: "self",
                title: "Moment \(id)",
                locationText: "Somewhere",
                placeID: nil,
                pushID: nil,
                publishedAt: publishedAt,
                lastActivityAt: publishedAt,
                deletedAt: nil
            ),
            taggedPersonIDs: ["self"],
            media: [media],
            visibleMediaCount: 1,
            capabilities: MomentCapabilities(
                viewerID: "self",
                canView: true,
                canAddMedia: true,
                canEditTags: false,
                canEditMetadata: false,
                canReorderMedia: false,
                canDeleteMoment: false,
                canSelfRemoveTag: false,
                youContributed: true,
                showOpenForAddsChip: false,
                isCreator: true
            )
        )
    }
}
