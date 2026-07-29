//
//  CreatePostHubBuilderTests.swift
//  PushTests
//
//  Issue #126 / S7 §6.2–6.3: `MomentSummary` → Existing Moment rows and
//  historical `PushPlan` → Past Push rows (prefill, exclusion, ordering).
//

import XCTest
@testable import Push

@MainActor
final class CreatePostHubBuilderTests: XCTestCase {

    private let viewer = "manav"
    private let friend = "ram"

    func testExistingMomentRowCarriesMediaChipAndContributors() {
        let summary = summaryWithTwoUploaders()
        let row = CreatePostHubBuilder.existingMoment(
            from: summary, people: people(), now: summary.moment.publishedAt
        )

        XCTAssertEqual(row.id, summary.moment.id)
        XCTAssertEqual(row.title, "Rooftop")
        XCTAssertEqual(row.locationTitle, "Rooftop bar")
        XCTAssertTrue(row.showsMediaThumbnail)
        XCTAssertEqual(row.mediaCount, 2)
        XCTAssertEqual(row.participants.map(\.id), [viewer, friend])
        // Distinct uploaders, first upload first — not the tag order.
        XCTAssertEqual(row.contributors.map(\.id), [friend, viewer])
        XCTAssertEqual(row.contributionState, .youContributed)
    }

    func testOpenForAddsChipComesFromCapabilities() {
        let summary = summaryWithTwoUploaders(
            youContributed: false, showOpenForAddsChip: true
        )
        let row = CreatePostHubBuilder.existingMoment(from: summary, people: people())
        XCTAssertEqual(row.contributionState, .openForAdds)
    }

    func testUnknownPeopleAreDroppedRatherThanRenderedNameless() {
        let summary = summaryWithTwoUploaders()
        let row = CreatePostHubBuilder.existingMoment(
            from: summary, people: [viewer: person(id: viewer, name: "Manav")]
        )
        XCTAssertEqual(row.participants.map(\.id), [viewer])
        XCTAssertEqual(row.contributors.map(\.id), [viewer])
    }

    func testPastPushRowsExcludeConsumedSlotsAndPrefillInResponses() {
        let now = Date()
        let recent = plan(id: "recent", hoursAgo: 10, now: now)
        let older = plan(id: "older", hoursAgo: 40, now: now)
        let consumed = plan(id: "consumed", hoursAgo: 20, now: now)
        let upcoming = plan(id: "upcoming", hoursAgo: -10, now: now)

        let rows = CreatePostHubBuilder.pastPushes(
            plans: [older, upcoming, recent, consumed],
            responses: [
                response(pushID: recent.id, personID: friend, response: .in),
                response(pushID: recent.id, personID: viewer, response: .in),
                response(pushID: recent.id, personID: "ohm", response: .maybe),
                response(pushID: recent.id, personID: "unknown-person", response: .in)
            ],
            momentPushIDs: [consumed.id],
            peopleByID: people(),
            placesByID: [:],
            viewerID: viewer,
            now: now
        )

        // Newest first; consumed slot and still-active push both excluded.
        XCTAssertEqual(rows.map(\.id), [recent.id, older.id])
        // Prefill is the "in" crowd minus the viewer (creator tag is implicit)
        // and minus ids with no cached person (the server rejects those tags).
        XCTAssertEqual(rows[0].participants.map(\.id), [friend])
        XCTAssertEqual(rows[0].style, .pastPush)
        XCTAssertTrue(rows[0].mediaItems.isEmpty)
        XCTAssertEqual(rows[0].locationTitle, "Dolores Park")
    }

    func testPlaceNameWinsOverFreeTextLocation() {
        let now = Date()
        let base = plan(id: "with-place", hoursAgo: 12, now: now)
        let withPlace = PushPlan(
            id: base.id, title: base.title, groupID: nil, creatorID: viewer,
            createdAt: base.createdAt, updatedAt: base.updatedAt, startsAt: base.startsAt,
            hasExplicitTime: false, isApproximateTime: false, expiresAt: base.expiresAt,
            cancelledAt: nil, placeID: "north-park", placeIsSuggested: true,
            state: .collecting, audience: .inviteesOnly, note: nil,
            locationText: "Dolores Park"
        )
        let place = Place(
            id: "north-park", name: "North Park", shortName: "North Park",
            address: "1 Park Ave", vagueLabel: "North Park", latitude: 0, longitude: 0
        )

        let rows = CreatePostHubBuilder.pastPushes(
            plans: [withPlace],
            responses: [],
            momentPushIDs: [],
            peopleByID: people(),
            placesByID: ["north-park": place],
            viewerID: viewer,
            now: now
        )
        XCTAssertEqual(rows[0].locationTitle, "North Park")
        // No explicit time → weekday only, no "·" time suffix.
        XCTAssertFalse(rows[0].dateLabel.contains("·"))
    }

    // MARK: - Helpers

    private func people() -> [Person.ID: Person] {
        [
            viewer: person(id: viewer, name: "Manav"),
            friend: person(id: friend, name: "Ram"),
            "ohm": person(id: "ohm", name: "Ohm")
        ]
    }

    private func person(id: Person.ID, name: String) -> Person {
        Person(id: id, firstName: name, imageAssetPath: nil)
    }

    private func summaryWithTwoUploaders(
        youContributed: Bool = true,
        showOpenForAddsChip: Bool = false
    ) -> MomentSummary {
        let publishedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let moment = Moment(
            id: "moment-rooftop",
            creatorID: viewer,
            title: "Rooftop",
            locationText: "Rooftop bar",
            placeID: nil,
            pushID: nil,
            publishedAt: publishedAt,
            lastActivityAt: publishedAt,
            deletedAt: nil
        )
        let media = [friend, viewer, friend].enumerated().map { index, uploader in
            MomentMedia(
                id: "media-\(index)",
                momentID: moment.id,
                uploaderID: uploader,
                kind: .photo,
                storagePath: "\(moment.id)/\(index).jpg",
                publicURL: "https://cdn.invalid/\(index).jpg",
                posterPath: nil,
                posterURL: nil,
                sortOrder: index,
                createdAt: publishedAt,
                deletedAt: nil
            )
        }
        return MomentSummary(
            moment: moment,
            taggedPersonIDs: [viewer, friend],
            media: Array(media.prefix(2)),
            visibleMediaCount: 2,
            capabilities: MomentCapabilities(
                viewerID: viewer,
                canView: true,
                canAddMedia: true,
                canEditTags: true,
                canEditMetadata: true,
                canReorderMedia: true,
                canDeleteMoment: true,
                canSelfRemoveTag: false,
                youContributed: youContributed,
                showOpenForAddsChip: showOpenForAddsChip,
                isCreator: true
            )
        )
    }

    private func plan(id: String, hoursAgo: Double, now: Date) -> PushPlan {
        let startsAt = now.addingTimeInterval(-hoursAgo * 3600)
        return PushPlan(
            id: id,
            title: "Push \(id)",
            groupID: nil,
            creatorID: viewer,
            createdAt: startsAt,
            updatedAt: startsAt,
            startsAt: startsAt,
            hasExplicitTime: true,
            isApproximateTime: false,
            // Historical only once the window closed.
            expiresAt: startsAt.addingTimeInterval(3600),
            cancelledAt: nil,
            placeID: nil,
            placeIsSuggested: false,
            state: .collecting,
            audience: .inviteesOnly,
            note: nil,
            locationText: "Dolores Park"
        )
    }

    private func response(
        pushID: String, personID: String, response: PushResponse.Response
    ) -> PushResponse {
        PushResponse(
            id: "\(pushID)-\(personID)",
            pushID: pushID,
            personID: personID,
            response: response,
            respondedAt: nil,
            readyState: .unknown
        )
    }
}
