//
//  SupabaseMomentRepositoryTests.swift
//  PushTests
//
//  Live Moment mapping and error translation. Decodes the exact DTO shape the
//  0026 RPCs return, so a payload change fails here rather than in the UI.
//

import Foundation
import Supabase
import XCTest
@testable import Push

@MainActor
final class SupabaseMomentRepositoryTests: XCTestCase {

    private let viewer = "11111111-1111-1111-1111-111111111111"
    private let creator = "22222222-2222-2222-2222-222222222222"

    // MARK: - Mapping

    func testSummaryMapsMomentCoverAndVisibleCount() throws {
        let row = try decode(feedJSON())
        let summary = row.summary(viewerID: viewer)

        XCTAssertEqual(summary.id, "33333333-3333-3333-3333-333333333333")
        XCTAssertEqual(summary.moment.creatorID, creator)
        XCTAssertEqual(summary.moment.title, "Rooftop")
        XCTAssertEqual(summary.moment.locationText, "Rooftop bar")
        XCTAssertNil(summary.moment.pushID)
        XCTAssertNil(summary.moment.deletedAt, "read RPCs only return live Moments")
        XCTAssertEqual(summary.taggedPersonIDs, [creator, viewer])
        XCTAssertEqual(summary.coverMedia?.sortOrder, 0)
        XCTAssertEqual(summary.coverMedia?.kind, .photo)
        XCTAssertEqual(summary.visibleMediaCount, 2)
    }

    func testTimestampsParseFractionalAndPlainISO8601() throws {
        let row = try decode(feedJSON())
        let moment = row.moment()
        XCTAssertEqual(
            moment.publishedAt,
            ISO8601DateFormatter().date(from: "2026-07-29T18:00:00Z")
        )
        // last_activity_at carries fractional seconds in production payloads.
        XCTAssertGreaterThan(moment.lastActivityAt, moment.publishedAt)
    }

    func testDetailMapsMediaOrderPostersAndMembers() throws {
        let row = try decode(feedJSON())
        let detail = row.detail(viewerID: viewer)

        XCTAssertEqual(detail.media.map(\.sortOrder), [0, 1])
        XCTAssertEqual(detail.media.first?.publicURL, "https://cdn.invalid/a.jpg")
        XCTAssertNil(detail.media.first?.posterPath)
        XCTAssertEqual(detail.media.last?.kind, .video)
        XCTAssertEqual(detail.media.last?.posterURL, "https://cdn.invalid/b-poster.jpg")
        // Tag order is preserved from the server's ordered id list.
        XCTAssertEqual(detail.members.map(\.personID), [creator, viewer])
        XCTAssertEqual(detail.coverMedia?.id, detail.media.first?.id)
    }

    func testCapabilitiesMapIncludingDerivedSelfRemove() throws {
        let row = try decode(feedJSON())
        let capabilities = row.summary(viewerID: viewer).capabilities

        XCTAssertTrue(capabilities.canView)
        XCTAssertTrue(capabilities.canAddMedia)
        XCTAssertTrue(capabilities.canEditTags)
        XCTAssertFalse(capabilities.canEditMetadata)
        XCTAssertTrue(capabilities.canReorderMedia)
        XCTAssertFalse(capabilities.canDeleteMoment)
        XCTAssertTrue(capabilities.youContributed)
        XCTAssertFalse(capabilities.showOpenForAddsChip)
        // Not in the server payload: tagged and not the creator.
        XCTAssertTrue(capabilities.canSelfRemoveTag)

        // Creator's own view: no self-remove, deletes anyone's media.
        let asCreator = row.summary(viewerID: creator).capabilities
        XCTAssertFalse(asCreator.canSelfRemoveTag)
        let othersMedia = try XCTUnwrap(row.detail(viewerID: creator).media.first)
        XCTAssertTrue(asCreator.canDeleteMedia(othersMedia))
    }

    func testCoverFallsBackToFirstVisibleItemWhenTheGlobalCoverIsFiltered() throws {
        // Server omitted sort_order 0 (blocked uploader); order 1 leads.
        let row = try decode(blockFilteredJSON())
        let summary = row.summary(viewerID: viewer)

        XCTAssertEqual(summary.coverMedia?.sortOrder, 1)
        XCTAssertEqual(summary.visibleMediaCount, 1)
        XCTAssertFalse(summary.taggedPersonIDs.contains("44444444-4444-4444-4444-444444444444"))
    }

    func testUnknownMediaKindIsDroppedRatherThanGuessed() throws {
        let row = try decode(unknownKindJSON())
        let detail = row.detail(viewerID: viewer)
        XCTAssertEqual(detail.media.count, 1)
        XCTAssertEqual(detail.media.first?.kind, .photo)
    }

    func testEmptyTagAndMediaArraysDecode() throws {
        let row = try decode(emptyArraysJSON())
        let detail = row.detail(viewerID: viewer)
        XCTAssertTrue(detail.members.isEmpty)
        XCTAssertTrue(detail.media.isEmpty)
        XCTAssertNil(detail.coverMedia)
    }

    func testFeedPageDecodesAsAnArrayOfRows() throws {
        let json = "[\(feedJSON()),\(feedJSON())]"
        let rows = try JSONDecoder().decode([MomentRow].self, from: Data(json.utf8))
        XCTAssertEqual(rows.count, 2)
    }

    // MARK: - Error mapping

    func testRPCExceptionStringsMapToDomainErrors() {
        let expectations: [(String, MomentRepositoryError)] = [
            ("not authenticated", .notAuthenticated),
            ("not found", .notFound),
            ("not allowed", .notAllowed),
            ("media required", .mediaRequired),
            ("media limit exceeded", .mediaLimitExceeded),
            ("invalid tag", .invalidTag),
            ("invalid push", .invalidPush),
            ("moment exists for push", .momentExistsForPush),
            ("cannot remove creator", .cannotRemoveCreator),
            ("conflict", .conflict),
            // 0025 storage-path validation.
            ("invalid media path", .invalidMediaPath),
            ("media type mismatch", .invalidMediaPath),
            ("media already registered", .invalidMediaPath)
        ]

        for (message, expected) in expectations {
            let mapped = MomentErrorMapper.map(
                PostgrestError(code: "P0001", message: message)
            )
            XCTAssertEqual(mapped as? MomentRepositoryError, expected, "message: \(message)")
        }
    }

    func testUnrecognizedAndNonPostgrestErrorsPassThroughUnchanged() {
        let transport = URLError(.notConnectedToInternet)
        XCTAssertTrue(MomentErrorMapper.map(transport) is URLError)

        let unknown = PostgrestError(code: "42501", message: "permission denied for schema")
        XCTAssertNil(MomentErrorMapper.map(unknown) as? MomentRepositoryError)
    }

    // MARK: - Fixtures

    private func decode(_ json: String) throws -> MomentRow {
        try JSONDecoder().decode(MomentRow.self, from: Data(json.utf8))
    }

    private func feedJSON() -> String {
        """
        {
          "id": "33333333-3333-3333-3333-333333333333",
          "creator_id": "\(creator)",
          "title": "Rooftop",
          "location_text": "Rooftop bar",
          "place_id": null,
          "push_id": null,
          "published_at": "2026-07-29T18:00:00+00:00",
          "last_activity_at": "2026-07-29T19:30:12.482913+00:00",
          "tagged_person_ids": ["\(creator)", "\(viewer)"],
          "media": [
            {
              "id": "aaaaaaaa-0000-4000-8000-000000000001",
              "moment_id": "33333333-3333-3333-3333-333333333333",
              "uploader_id": "\(creator)",
              "kind": "photo",
              "storage_path": "pending/\(creator)/a.jpg",
              "public_url": "https://cdn.invalid/a.jpg",
              "poster_path": null,
              "poster_url": null,
              "sort_order": 0,
              "created_at": "2026-07-29T18:00:01+00:00"
            },
            {
              "id": "aaaaaaaa-0000-4000-8000-000000000002",
              "moment_id": "33333333-3333-3333-3333-333333333333",
              "uploader_id": "\(viewer)",
              "kind": "video",
              "storage_path": "pending/\(viewer)/b.mp4",
              "public_url": "https://cdn.invalid/b.mp4",
              "poster_path": "pending/\(viewer)/b-poster.jpg",
              "poster_url": "https://cdn.invalid/b-poster.jpg",
              "sort_order": 1,
              "created_at": "2026-07-29T19:30:12+00:00"
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

    private func blockFilteredJSON() -> String {
        """
        {
          "id": "33333333-3333-3333-3333-333333333334",
          "creator_id": "\(creator)",
          "title": "Filtered",
          "location_text": "",
          "place_id": null,
          "push_id": "55555555-5555-5555-5555-555555555555",
          "published_at": "2026-07-29T18:00:00+00:00",
          "last_activity_at": "2026-07-29T18:00:00+00:00",
          "tagged_person_ids": ["\(creator)"],
          "media": [
            {
              "id": "aaaaaaaa-0000-4000-8000-000000000003",
              "moment_id": "33333333-3333-3333-3333-333333333334",
              "uploader_id": "\(creator)",
              "kind": "photo",
              "storage_path": "pending/\(creator)/c.jpg",
              "public_url": "https://cdn.invalid/c.jpg",
              "poster_path": null,
              "poster_url": null,
              "sort_order": 1,
              "created_at": "2026-07-29T18:00:05+00:00"
            }
          ],
          "visible_media_count": 1,
          "capabilities": {
            "canView": true,
            "canAddMedia": false,
            "canEditTags": false,
            "canEditMetadata": false,
            "canReorderMedia": false,
            "canDeleteMoment": false,
            "youContributed": false,
            "showOpenForAddsChip": false
          }
        }
        """
    }

    private func unknownKindJSON() -> String {
        feedJSON().replacingOccurrences(of: "\"kind\": \"video\"", with: "\"kind\": \"live-photo\"")
    }

    /// `coalesce(..., '[]')` in the DTO means empty arrays are a real payload.
    private func emptyArraysJSON() -> String {
        """
        {
          "id": "33333333-3333-3333-3333-333333333335",
          "creator_id": "\(creator)",
          "title": "",
          "location_text": "",
          "place_id": "place-1",
          "push_id": null,
          "published_at": "2026-07-29T18:00:00+00:00",
          "last_activity_at": "2026-07-29T18:00:00+00:00",
          "tagged_person_ids": [],
          "media": [],
          "visible_media_count": 0,
          "capabilities": {
            "canView": false,
            "canAddMedia": false,
            "canEditTags": false,
            "canEditMetadata": false,
            "canReorderMedia": false,
            "canDeleteMoment": false,
            "youContributed": false,
            "showOpenForAddsChip": false
          }
        }
        """
    }
}
