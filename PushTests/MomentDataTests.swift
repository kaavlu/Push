//
//  MomentDataTests.swift
//  PushTests
//
//  Mock Moment data layer: seed determinism, viewer-scoped reads, and the
//  local repository's parity with the 0023 mutation RPCs.
//

import Foundation
import XCTest
@testable import Push

@MainActor
final class MomentDataTests: XCTestCase {

    private let northPark = "moment-north-park"   // created by the current user
    private let blueBottle = "moment-blue-bottle" // tagged, no contribution
    private let crunch = "moment-crunch"          // viewer only

    // MARK: - Seed

    func testSeedIsDeterministicForAFixedClock() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let first = SeedData.standard(now: now)
        let second = SeedData.standard(now: now)

        XCTAssertEqual(first.moments, second.moments)
        XCTAssertEqual(first.momentMembers, second.momentMembers)
        XCTAssertEqual(first.momentMedia, second.momentMedia)
        XCTAssertFalse(first.moments.isEmpty)
    }

    func testSeedMomentsAreIndependentOfActivityFeedEvents() {
        let seed = SeedData.standard()
        let momentIDs = Set(seed.moments.map(\.id))
        let eventIDs = Set(seed.feedEvents.map(\.id))
        XCTAssertTrue(momentIDs.isDisjoint(with: eventIDs))
        // Empty-graph seeds carry no albums at all.
        XCTAssertTrue(SeedData.emptyGraph().moments.isEmpty)
    }

    func testSeedMomentsAreInternallyConsistent() {
        let seed = SeedData.standard()
        let peopleIDs = Set(seed.people.map(\.id))
        for moment in seed.moments {
            let members = seed.momentMembers.filter { $0.momentID == moment.id }
            let media = seed.momentMedia.filter { $0.momentID == moment.id }
            XCTAssertTrue(
                members.contains { $0.personID == moment.creatorID },
                "creator must always be tagged"
            )
            XCTAssertFalse(media.isEmpty, "a published Moment always has media")
            XCTAssertEqual(
                media.map(\.sortOrder).sorted(), Array(0..<media.count),
                "media order must be dense from 0"
            )
            XCTAssertTrue(peopleIDs.isSuperset(of: members.map(\.personID)))
            XCTAssertTrue(peopleIDs.isSuperset(of: media.map(\.uploaderID)))
        }
    }

    // MARK: - Reads

    func testFeedIsNewestActivityFirstWithCoverAndVisibleCount() async throws {
        let container = AppDataContainer(seed: .standard())
        let page = try await container.moments.feedPage(
            cursor: nil, limit: 10, groupID: nil
        )

        XCTAssertEqual(page.moments.map(\.id), [northPark, blueBottle, crunch])
        XCTAssertFalse(page.hasMore)
        XCTAssertNil(page.nextCursor)

        let first = try XCTUnwrap(page.moments.first)
        XCTAssertEqual(first.visibleMediaCount, 3)
        XCTAssertEqual(first.coverMedia?.sortOrder, 0)
        // Creator leads the tag stack.
        XCTAssertEqual(first.taggedPersonIDs.first, container.currentUserID)
    }

    func testFeedPaginatesOnTheActivityCursorWithoutOverlap() async throws {
        let container = AppDataContainer(seed: .standard())
        let first = try await container.moments.feedPage(
            cursor: nil, limit: 2, groupID: nil
        )
        XCTAssertEqual(first.moments.map(\.id), [northPark, blueBottle])
        XCTAssertTrue(first.hasMore)

        let second = try await container.moments.feedPage(
            cursor: first.nextCursor, limit: 2, groupID: nil
        )
        XCTAssertEqual(second.moments.map(\.id), [crunch])
        XCTAssertFalse(second.hasMore)
    }

    func testGroupFilterUsesSharedMembershipOfTaggedPeople() async throws {
        let container = AppDataContainer(seed: .standard())
        let database = try XCTUnwrap(container.database)

        // Viewer is not an active member of any seeded group yet.
        let before = try await container.moments.feedPage(
            cursor: nil, limit: 10, groupID: "india"
        )
        XCTAssertTrue(before.moments.isEmpty)

        database.memberships.append(
            GroupMembership(
                id: "membership-india-\(container.currentUserID)",
                personID: container.currentUserID,
                groupID: "india",
                role: .member,
                sharingLevel: .full,
                membershipStatus: .active,
                joinedAt: Date()
            )
        )

        let after = try await container.moments.feedPage(
            cursor: nil, limit: 10, groupID: "india"
        )
        // Blue Bottle matches through chitty/nitin. North Park matches because the
        // viewer is tagged and is now an India member — `private.shares_group` is
        // self-inclusive, so the mock mirrors it. Crunch has no India path at all.
        XCTAssertEqual(after.moments.map(\.id), [northPark, blueBottle])
        XCTAssertFalse(after.moments.contains { $0.id == self.crunch })
    }

    func testHubExcludesMomentsTheViewerOnlyWatches() async throws {
        let container = AppDataContainer(seed: .standard())
        let hub = try await container.moments.hubMoments()
        XCTAssertEqual(Set(hub.map(\.id)), [northPark, blueBottle])
    }

    func testDetailCarriesViewerCapabilitiesForATaggedNonContributor() async throws {
        let container = AppDataContainer(seed: .standard())
        let detail = try await container.moments.moment(id: blueBottle)

        XCTAssertTrue(detail.capabilities.canView)
        XCTAssertTrue(detail.capabilities.canAddMedia)
        XCTAssertTrue(detail.capabilities.showOpenForAddsChip)
        XCTAssertFalse(detail.capabilities.canEditMetadata)
        XCTAssertFalse(detail.capabilities.canReorderMedia)
        XCTAssertFalse(detail.capabilities.youContributed)
        XCTAssertEqual(detail.media.map(\.sortOrder), [0, 1])
    }

    func testSoftDeletedMomentIsNotReadable() async throws {
        let container = AppDataContainer(seed: .standard())
        try await container.moments.softDeleteMoment(momentID: northPark)

        await assertThrows(.notFound) {
            _ = try await container.moments.moment(id: self.northPark)
        }
        let page = try await container.moments.feedPage(cursor: nil, limit: 10, groupID: nil)
        XCTAssertFalse(page.moments.contains { $0.id == self.northPark })
    }

    // MARK: - Create

    func testCreateTagsTheCreatorAndOrdersMediaDensely() async throws {
        let container = AppDataContainer(seed: .standard())
        let id = try await container.moments.createMoment(
            MomentDraft(
                title: "Late night",
                locationText: "Kerrytown",
                taggedPersonIDs: ["ram"],
                media: [draft("a"), draft("b")]
            )
        )

        let detail = try await container.moments.moment(id: id)
        XCTAssertEqual(detail.moment.creatorID, container.currentUserID)
        XCTAssertEqual(detail.members.map(\.personID), [container.currentUserID, "ram"])
        XCTAssertEqual(detail.media.map(\.sortOrder), [0, 1])
        XCTAssertEqual(detail.moment.publishedAt, detail.moment.lastActivityAt)
        XCTAssertTrue(detail.capabilities.canDeleteMoment)
    }

    func testCreateRejectsEmptyMediaOversizeBatchesAndNonFriendTags() async {
        let container = AppDataContainer(seed: .standard())

        await assertThrows(.mediaRequired) {
            _ = try await container.moments.createMoment(
                MomentDraft(title: "Empty", media: [])
            )
        }
        await assertThrows(.mediaLimitExceeded) {
            _ = try await container.moments.createMoment(
                MomentDraft(
                    title: "Too many",
                    media: (0...8).map { self.draft("m\($0)") }
                )
            )
        }
        await assertThrows(.invalidTag) {
            _ = try await container.moments.createMoment(
                // `austin` is discoverable but not an accepted friend.
                MomentDraft(title: "Stranger tag", taggedPersonIDs: ["austin"], media: [self.draft("a")])
            )
        }
    }

    func testPushSlotIsConsumedOnceEvenAfterSoftDelete() async throws {
        let container = AppDataContainer(seed: .standard())
        let database = try XCTUnwrap(container.database)
        let pushID = insertHistoricalPush(into: database)

        let id = try await container.moments.createMoment(
            MomentDraft(title: "From push", pushID: pushID, media: [draft("a")])
        )
        try await container.moments.softDeleteMoment(momentID: id)

        await assertThrows(.momentExistsForPush) {
            _ = try await container.moments.createMoment(
                MomentDraft(title: "Second", pushID: pushID, media: [self.draft("b")])
            )
        }
    }

    func testCreateFromAnActivePushIsRejected() async throws {
        let container = AppDataContainer(seed: .standard())
        let database = try XCTUnwrap(container.database)
        let activePushID = try XCTUnwrap(
            database.plansByID.values
                .first { $0.cancelledAt == nil && $0.expiresAt > Date() }?.id
        )

        await assertThrows(.invalidPush) {
            _ = try await container.moments.createMoment(
                MomentDraft(title: "Too early", pushID: activePushID, media: [self.draft("a")])
            )
        }
    }

    // MARK: - Append

    func testAppendBumpsActivityAndCapsAtEightItems() async throws {
        let container = AppDataContainer(seed: .standard())
        let before = try await container.moments.moment(id: northPark)

        try await container.moments.appendMedia(momentID: northPark, items: [draft("new")])
        let after = try await container.moments.moment(id: northPark)

        XCTAssertGreaterThan(after.moment.lastActivityAt, before.moment.lastActivityAt)
        XCTAssertEqual(after.media.count, before.media.count + 1)
        // Appends land at the end; the cover never moves.
        XCTAssertEqual(after.media.last?.sortOrder, after.media.count - 1)
        XCTAssertEqual(after.media.first?.id, before.media.first?.id)

        // 4 active now — five more fit, the sixth is rejected.
        try await container.moments.appendMedia(
            momentID: northPark, items: (0..<4).map { draft("fill\($0)") }
        )
        await assertThrows(.mediaLimitExceeded) {
            try await container.moments.appendMedia(
                momentID: self.northPark, items: [self.draft("nine")]
            )
        }
        let capped = try await container.moments.moment(id: northPark)
        XCTAssertEqual(capped.media.count, MomentLimits.maxActiveMedia)
    }

    func testPartialAppendBatchKeepsTheItemsThatFit() async throws {
        let container = AppDataContainer(seed: .standard())
        // 3 seeded items; ask for 6 so the last one overflows the cap of 8.
        await assertThrows(.mediaLimitExceeded) {
            try await container.moments.appendMedia(
                momentID: self.northPark, items: (0..<6).map { self.draft("batch\($0)") }
            )
        }
        let detail = try await container.moments.moment(id: northPark)
        XCTAssertEqual(detail.media.count, MomentLimits.maxActiveMedia)
    }

    func testUntaggedViewerCannotAppend() async {
        let container = AppDataContainer(seed: .standard())
        await assertThrows(.notAllowed) {
            try await container.moments.appendMedia(
                momentID: self.crunch, items: [self.draft("nope")]
            )
        }
    }

    // MARK: - Metadata / tags

    func testMetadataEditDoesNotBumpActivityAndIsCreatorOnly() async throws {
        let container = AppDataContainer(seed: .standard())
        let before = try await container.moments.moment(id: northPark)

        try await container.moments.updateMetadata(
            momentID: northPark, title: "Renamed", locationText: "Elsewhere"
        )
        let after = try await container.moments.moment(id: northPark)
        XCTAssertEqual(after.moment.title, "Renamed")
        XCTAssertEqual(after.moment.locationText, "Elsewhere")
        XCTAssertEqual(after.moment.lastActivityAt, before.moment.lastActivityAt)

        // Tagged non-contributor on someone else's Moment.
        await assertThrows(.notAllowed) {
            try await container.moments.updateMetadata(
                momentID: self.blueBottle, title: "Hack", locationText: "Hack"
            )
        }
    }

    func testSelfRemoveKeepsMediaAndCreatorCannotBeRemoved() async throws {
        let container = AppDataContainer(seed: .standard())
        let userID = container.currentUserID

        // Tagged non-contributor hides their attendance.
        try await container.moments.removeTag(momentID: blueBottle, personID: userID)
        let detail = try await container.moments.moment(id: blueBottle)
        XCTAssertFalse(detail.members.contains { $0.personID == userID })
        XCTAssertEqual(detail.media.count, 2, "other people's media is untouched")
        XCTAssertFalse(detail.capabilities.canAddMedia)
        // Still viewable through the remaining tagged friends.
        XCTAssertTrue(detail.capabilities.canView)

        await assertThrows(.cannotRemoveCreator) {
            try await container.moments.removeTag(
                momentID: self.northPark, personID: userID
            )
        }
    }

    func testAddTagsRequiresEditRightsAndAcceptedFriends() async throws {
        let container = AppDataContainer(seed: .standard())

        try await container.moments.addTags(momentID: northPark, personIDs: ["ryan"])
        let detail = try await container.moments.moment(id: northPark)
        XCTAssertTrue(detail.members.contains { $0.personID == "ryan" })

        await assertThrows(.invalidTag) {
            try await container.moments.addTags(
                momentID: self.northPark, personIDs: ["austin"]
            )
        }
        // Tagged non-contributor may not edit other people's tags.
        await assertThrows(.notAllowed) {
            try await container.moments.addTags(
                momentID: self.blueBottle, personIDs: ["ram"]
            )
        }
    }

    // MARK: - Reorder / delete

    func testReorderRewritesDenseOrderAndRejectsMismatchedSets() async throws {
        let container = AppDataContainer(seed: .standard())
        let detail = try await container.moments.moment(id: northPark)
        let reversed = detail.media.map(\.id).reversed().map { $0 }

        try await container.moments.reorderMedia(
            momentID: northPark, orderedMediaIDs: reversed
        )
        let after = try await container.moments.moment(id: northPark)
        XCTAssertEqual(after.media.map(\.id), reversed)
        XCTAssertEqual(after.media.map(\.sortOrder), [0, 1, 2])
        XCTAssertEqual(after.coverMedia?.id, reversed.first)

        await assertThrows(.conflict) {
            try await container.moments.reorderMedia(
                momentID: self.northPark, orderedMediaIDs: Array(reversed.dropLast())
            )
        }
        // Tagged non-contributor cannot reorder.
        await assertThrows(.notAllowed) {
            let other = try await container.moments.moment(id: self.blueBottle)
            try await container.moments.reorderMedia(
                momentID: self.blueBottle, orderedMediaIDs: other.media.map(\.id).reversed()
            )
        }
    }

    func testDeletingMediaRenumbersAndLastDeleteSoftDeletesTheMoment() async throws {
        let container = AppDataContainer(seed: .standard())
        var detail = try await container.moments.moment(id: northPark)
        let cover = try XCTUnwrap(detail.media.first)

        try await container.moments.softDeleteMedia(mediaID: cover.id)
        detail = try await container.moments.moment(id: northPark)
        XCTAssertEqual(detail.media.count, 2)
        XCTAssertEqual(detail.media.map(\.sortOrder), [0, 1])
        XCTAssertFalse(detail.media.contains { $0.id == cover.id })

        for item in detail.media {
            try await container.moments.softDeleteMedia(mediaID: item.id)
        }
        await assertThrows(.notFound) {
            _ = try await container.moments.moment(id: self.northPark)
        }
        let database = try XCTUnwrap(container.database)
        XCTAssertNotNil(database.momentsByID[northPark]?.deletedAt)
    }

    func testMediaDeletionIsUploaderOwnOrCreatorAny() async throws {
        let container = AppDataContainer(seed: .standard())
        // Creator deletes another member's item (`ram` uploaded the third one).
        let mine = try await container.moments.moment(id: northPark)
        let ramItem = try XCTUnwrap(mine.media.first { $0.uploaderID == "ram" })
        try await container.moments.softDeleteMedia(mediaID: ramItem.id)
        let remaining = try await container.moments.moment(id: northPark).media.count
        XCTAssertEqual(remaining, 2)

        // Neither uploader nor creator elsewhere.
        let other = try await container.moments.moment(id: blueBottle)
        let theirs = try XCTUnwrap(other.media.first)
        await assertThrows(.notAllowed) {
            try await container.moments.softDeleteMedia(mediaID: theirs.id)
        }
    }

    func testNonCreatorCannotSoftDeleteTheMoment() async {
        let container = AppDataContainer(seed: .standard())
        await assertThrows(.notAllowed) {
            try await container.moments.softDeleteMoment(momentID: self.blueBottle)
        }
    }

    // MARK: - Helpers

    /// Seed pushes are all still active; publishing from a Push needs one that
    /// has already expired.
    private func insertHistoricalPush(into database: InMemoryDatabase) -> PushPlan.ID {
        let startedAt = Date().addingTimeInterval(-2 * SeedTime.ninetyDays)
        let plan = PushPlan(
            id: "push-history-fixture",
            title: "Last month's dinner",
            groupID: nil,
            creatorID: database.currentUserID,
            createdAt: startedAt,
            updatedAt: startedAt,
            startsAt: startedAt,
            hasExplicitTime: true,
            isApproximateTime: false,
            expiresAt: startedAt.addingTimeInterval(SeedTime.sixHours),
            cancelledAt: nil,
            placeID: nil,
            placeIsSuggested: false,
            state: .locked,
            audience: .inviteesOnly,
            note: nil,
            locationText: "Kerrytown"
        )
        database.plansByID[plan.id] = plan
        return plan.id
    }

    private func draft(_ label: String) -> MomentMediaDraft {
        MomentMediaDraft(
            kind: .photo,
            storagePath: "pending/manav/\(label).jpg",
            publicURL: "https://example.invalid/\(label).jpg"
        )
    }

    private func assertThrows(
        _ expected: MomentRepositoryError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? MomentRepositoryError, expected, file: file, line: line)
        }
    }
}
