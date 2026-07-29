//
//  MomentFeedCardBuilderTests.swift
//  PushTests
//
//  Mapping from viewer-scoped `MomentSummary` rows onto the approved Feed card
//  presentation model (Issue #125 / S6).
//

import Foundation
import XCTest
@testable import Push

@MainActor
final class MomentFeedCardBuilderTests: XCTestCase {

    private let viewer = "self"
    private let publishedAt = Date(timeIntervalSince1970: 1_800_000_000)

    private var people: [Person.ID: Person] {
        [
            "self": Person(id: "self", firstName: "you", imageAssetPath: nil),
            "ram": Person(id: "ram", firstName: "ram", imageAssetPath: "assets/friends/ram.png"),
            "ohm": Person(id: "ohm", firstName: "ohm", imageAssetPath: nil)
        ]
    }

    func testCardCarriesViewerVisibleMediaPeopleAndMeta() {
        let summary = makeSummary(
            title: "Park hang",
            locationText: "Dolores Park",
            taggedPersonIDs: ["self", "ram"],
            media: [photo(id: "m0", uploader: "self", order: 0), photo(id: "m1", uploader: "ram", order: 1)]
        )

        let card = MomentFeedCardBuilder.card(from: summary, people: people, now: publishedAt)

        XCTAssertEqual(card.id, "moment-1")
        XCTAssertEqual(card.items.map(\.id), ["m0", "m1"])
        XCTAssertEqual(card.title, "Park hang")
        XCTAssertEqual(card.locationTitle, "Dolores Park")
        XCTAssertEqual(card.participants.map(\.id), ["self", "ram"])
        XCTAssertEqual(card.participants.map(\.displayName), ["You", "Ram"])
        // Cover uploader drives attribution.
        XCTAssertEqual(card.contributorName, "You")
    }

    /// The album order the repository returned is the carousel order — the
    /// builder never re-sorts or re-filters (visibility is server-side).
    func testMediaOrderAndCountFollowTheRepositoryProjection() {
        let summary = makeSummary(
            // Cover uploader blocked for this viewer: dense list starts at 1.
            media: [photo(id: "m1", uploader: "ram", order: 1), photo(id: "m2", uploader: "ohm", order: 2)]
        )

        let card = MomentFeedCardBuilder.card(from: summary, people: people, now: publishedAt)

        XCTAssertEqual(card.items.map(\.id), ["m1", "m2"])
        XCTAssertEqual(card.contributorName, "Ram")
    }

    func testPhotoUsesPublicURLAndVideoUsesItsPoster() {
        let video = MomentMedia(
            id: "v0", momentID: "moment-1", uploaderID: "ram", kind: .video,
            storagePath: "moment-1/ram/v0.mp4",
            publicURL: "https://example.invalid/v0.mp4",
            posterPath: "moment-1/ram/v0.jpg",
            posterURL: "https://example.invalid/v0.jpg",
            sortOrder: 1, createdAt: publishedAt, deletedAt: nil
        )
        let summary = makeSummary(media: [photo(id: "m0", uploader: "self", order: 0), video])

        let card = MomentFeedCardBuilder.card(from: summary, people: people, now: publishedAt)

        XCTAssertEqual(card.items[0].kind, .photo)
        XCTAssertEqual(card.items[0].source, .assetPath("https://example.invalid/m0.jpg"))
        XCTAssertEqual(card.items[1].kind, .video)
        // Poster still only — playback stays out of scope.
        XCTAssertEqual(card.items[1].source, .assetPath("https://example.invalid/v0.jpg"))
    }

    func testMissingMediaPathFallsBackToTheMissingPlaceholder() {
        let broken = MomentMedia(
            id: "m0", momentID: "moment-1", uploaderID: "ram", kind: .photo,
            storagePath: "", publicURL: "", posterPath: nil, posterURL: nil,
            sortOrder: 0, createdAt: publishedAt, deletedAt: nil
        )

        let card = MomentFeedCardBuilder.card(
            from: makeSummary(media: [broken]), people: people, now: publishedAt
        )

        XCTAssertEqual(card.items.first?.source, .missing)
    }

    /// A tagged id with no cached `Person` cannot render a face or a name, so it
    /// is dropped rather than shown blank (same rule as group memberships).
    func testUnknownTaggedPeopleAreDropped() {
        let summary = makeSummary(taggedPersonIDs: ["self", "stranger", "ram"])

        let card = MomentFeedCardBuilder.card(from: summary, people: people, now: publishedAt)

        XCTAssertEqual(card.participants.map(\.id), ["self", "ram"])
    }

    func testBlankTitleFallsBackToUntitledCopy() {
        let card = MomentFeedCardBuilder.card(
            from: makeSummary(title: "   "), people: people, now: publishedAt
        )
        XCTAssertEqual(card.title, MomentFeedCopy.untitledMoment)
    }

    func testAddYoursFollowsTheCapabilityProjection() {
        let tagged = MomentFeedCardBuilder.card(
            from: makeSummary(canAddMedia: true), people: people, now: publishedAt
        )
        let watcher = MomentFeedCardBuilder.card(
            from: makeSummary(canAddMedia: false), people: people, now: publishedAt
        )

        XCTAssertTrue(tagged.canAddYours)
        XCTAssertFalse(watcher.canAddYours)
    }

    func testDateLabelUsesTodayYesterdayThenWeekdayThenDate() throws {
        let now = publishedAt
        let calendar = Calendar.current

        let today = label(for: now, now: now)
        let yesterday = label(
            for: try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now)), now: now
        )
        let lastWeek = label(
            for: try XCTUnwrap(calendar.date(byAdding: .day, value: -20, to: now)), now: now
        )

        XCTAssertTrue(today.hasPrefix("Today · "), today)
        XCTAssertTrue(yesterday.hasPrefix("Yesterday · "), yesterday)
        XCTAssertFalse(lastWeek.hasPrefix("Today"), lastWeek)
        XCTAssertFalse(lastWeek.hasPrefix("Yesterday"), lastWeek)
        // Meta line joins location and date without empty separators.
        XCTAssertFalse(lastWeek.hasSuffix("· "), lastWeek)
    }

    func testCardsPreservePageOrder() {
        let cards = MomentFeedCardBuilder.cards(
            from: [makeSummary(id: "b"), makeSummary(id: "a")],
            people: people,
            now: publishedAt
        )
        XCTAssertEqual(cards.map(\.id), ["b", "a"])
    }

    // MARK: - Helpers

    private func label(for date: Date, now: Date) -> String {
        MomentFeedCardBuilder.card(
            from: makeSummary(publishedAt: date), people: people, now: now
        ).dateTimeLabel
    }

    private func photo(id: String, uploader: Person.ID, order: Int) -> MomentMedia {
        MomentMedia(
            id: id, momentID: "moment-1", uploaderID: uploader, kind: .photo,
            storagePath: "moment-1/\(uploader)/\(id).jpg",
            publicURL: "https://example.invalid/\(id).jpg",
            posterPath: nil, posterURL: nil,
            sortOrder: order, createdAt: publishedAt, deletedAt: nil
        )
    }

    private func makeSummary(
        id: Moment.ID = "moment-1",
        title: String = "Park hang",
        locationText: String = "Dolores Park",
        publishedAt: Date? = nil,
        taggedPersonIDs: [Person.ID] = ["self", "ram"],
        media: [MomentMedia]? = nil,
        canAddMedia: Bool = true
    ) -> MomentSummary {
        let published = publishedAt ?? self.publishedAt
        let items = media ?? [photo(id: "m0", uploader: "self", order: 0)]
        return MomentSummary(
            moment: Moment(
                id: id,
                creatorID: "self",
                title: title,
                locationText: locationText,
                placeID: nil,
                pushID: nil,
                publishedAt: published,
                lastActivityAt: published,
                deletedAt: nil
            ),
            taggedPersonIDs: taggedPersonIDs,
            media: items,
            visibleMediaCount: items.count,
            capabilities: MomentCapabilities(
                viewerID: viewer,
                canView: true,
                canAddMedia: canAddMedia,
                canEditTags: false,
                canEditMetadata: false,
                canReorderMedia: false,
                canDeleteMoment: false,
                canSelfRemoveTag: false,
                youContributed: false,
                showOpenForAddsChip: false,
                isCreator: false
            )
        )
    }
}
