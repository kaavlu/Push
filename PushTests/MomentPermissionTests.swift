//
//  MomentPermissionTests.swift
//  PushTests
//
//  Parity between `MomentAuthorization` and the locked permission matrix
//  (product contract §10) plus visibility rules (§5.1) as enforced by
//  migration 0022. Pure derivation — no store, no repository.
//

import Foundation
import XCTest
@testable import Push

final class MomentPermissionTests: XCTestCase {

    // Fixture: creator `creator`, tagged contributor `contributor`,
    // tagged non-contributor `tagged`, untagged past contributor `pastPoster`,
    // untagged viewer `viewer`, stranger `stranger`.
    private let creator = "creator"
    private let contributor = "contributor"
    private let tagged = "tagged"
    private let pastPoster = "past-poster"
    private let viewer = "viewer"
    private let stranger = "stranger"

    // MARK: - Matrix

    func testCreatorHasEveryCapabilityExceptSelfRemove() {
        let caps = capabilities(for: creator)
        XCTAssertTrue(caps.canView)
        XCTAssertTrue(caps.canAddMedia)
        XCTAssertTrue(caps.canEditTags)
        XCTAssertTrue(caps.canEditMetadata)
        XCTAssertTrue(caps.canReorderMedia)
        XCTAssertTrue(caps.canDeleteMoment)
        XCTAssertTrue(caps.youContributed)
        // Creator is always tagged — the row can never be dropped.
        XCTAssertFalse(caps.canSelfRemoveTag)
        XCTAssertFalse(caps.showOpenForAddsChip)
    }

    func testTaggedContributorEditsTagsAndOrderButNotMetadata() {
        let caps = capabilities(for: contributor)
        XCTAssertTrue(caps.canView)
        XCTAssertTrue(caps.canAddMedia)
        XCTAssertTrue(caps.canEditTags)
        XCTAssertTrue(caps.canReorderMedia)
        XCTAssertTrue(caps.canSelfRemoveTag)
        XCTAssertTrue(caps.youContributed)
        XCTAssertFalse(caps.canEditMetadata)
        XCTAssertFalse(caps.canDeleteMoment)
        XCTAssertFalse(caps.showOpenForAddsChip)
    }

    func testTaggedNonContributorMayOnlyAddMediaAndSelfRemove() {
        let caps = capabilities(for: tagged)
        XCTAssertTrue(caps.canView)
        XCTAssertTrue(caps.canAddMedia)
        XCTAssertTrue(caps.canSelfRemoveTag)
        // Hasn't posted yet — this is the "open for adds" state.
        XCTAssertTrue(caps.showOpenForAddsChip)
        XCTAssertFalse(caps.youContributed)
        XCTAssertFalse(caps.canEditTags)
        XCTAssertFalse(caps.canReorderMedia)
        XCTAssertFalse(caps.canEditMetadata)
        XCTAssertFalse(caps.canDeleteMoment)
    }

    func testUntaggedContributorLosesAddAndEditRightsButKeepsView() {
        let caps = capabilities(for: pastPoster)
        XCTAssertTrue(caps.canView)
        XCTAssertTrue(caps.youContributed)
        XCTAssertFalse(caps.canAddMedia)
        XCTAssertFalse(caps.canEditTags)
        XCTAssertFalse(caps.canReorderMedia)
        XCTAssertFalse(caps.canSelfRemoveTag)
    }

    func testViewerHasViewOnly() {
        let caps = capabilities(for: viewer)
        XCTAssertTrue(caps.canView)
        XCTAssertFalse(caps.canAddMedia)
        XCTAssertFalse(caps.canEditTags)
        XCTAssertFalse(caps.canReorderMedia)
        XCTAssertFalse(caps.canEditMetadata)
        XCTAssertFalse(caps.canDeleteMoment)
        XCTAssertFalse(caps.canSelfRemoveTag)
        XCTAssertFalse(caps.youContributed)
    }

    func testStrangerWithNoFriendPathCannotView() {
        let caps = capabilities(for: stranger, friends: [])
        XCTAssertFalse(caps.canView)
        XCTAssertFalse(caps.canAddMedia)
    }

    // MARK: - Media deletion

    func testMediaDeletionIsUploaderOwnOrCreatorAny() {
        let creatorCaps = capabilities(for: creator)
        let contributorCaps = capabilities(for: contributor)
        let taggedCaps = capabilities(for: tagged)
        let pastPosterCaps = capabilities(for: pastPoster)
        let viewerCaps = capabilities(for: viewer)

        let creatorItem = media[0]
        let contributorItem = media[1]
        let pastPosterItem = media[2]

        // Creator deletes anything.
        XCTAssertTrue(creatorCaps.canDeleteMedia(creatorItem))
        XCTAssertTrue(creatorCaps.canDeleteMedia(contributorItem))
        XCTAssertTrue(creatorCaps.canDeleteMedia(pastPosterItem))

        // Everyone else: own uploads only, including after losing their tag.
        XCTAssertTrue(contributorCaps.canDeleteMedia(contributorItem))
        XCTAssertFalse(contributorCaps.canDeleteMedia(creatorItem))
        XCTAssertTrue(pastPosterCaps.canDeleteMedia(pastPosterItem))
        XCTAssertFalse(pastPosterCaps.canDeleteMedia(creatorItem))
        XCTAssertFalse(taggedCaps.canDeleteMedia(creatorItem))
        XCTAssertFalse(viewerCaps.canDeleteMedia(creatorItem))
    }

    // MARK: - Visibility (§5.1)

    func testSoftDeletedMomentIsNeverViewable() {
        var deleted = moment
        deleted.deletedAt = Date()
        XCTAssertFalse(
            MomentAuthorization.canView(
                moment: deleted, members: members, media: media,
                viewerID: creator, graph: graph(for: creator)
            )
        )
    }

    func testMomentWithNoActiveMediaIsNotViewable() {
        let removed = media.map { item -> MomentMedia in
            var copy = item
            copy.deletedAt = Date()
            return copy
        }
        XCTAssertFalse(
            MomentAuthorization.canView(
                moment: moment, members: members, media: removed,
                viewerID: creator, graph: graph(for: creator)
            )
        )
    }

    func testBlockedUploaderMediaIsOmittedForThatViewer() {
        let context = graph(for: viewer, blocked: [contributor])
        let visible = MomentAuthorization.visibleMedia(
            media, viewerID: viewer, graph: context
        )
        XCTAssertFalse(visible.contains { $0.uploaderID == contributor })
        XCTAssertEqual(visible.count, media.count - 1)
    }

    func testBlockingEveryTaggedPathHidesTheMoment() {
        // Viewer's only paths are the tagged members; block them all.
        let context = graph(
            for: viewer, blocked: [creator, contributor, tagged]
        )
        XCTAssertFalse(
            MomentAuthorization.canView(
                moment: moment, members: members, media: media,
                viewerID: viewer, graph: context
            )
        )
    }

    func testTagsOutliveUnfriendingButVisibilityIsRecomputed() {
        // Still tagged, no friendships left → no visibility path.
        let context = MomentGraphContext(isFriend: { _ in false }, isBlocked: { _ in false })
        let relation = MomentAuthorization.relation(
            moment: moment, members: members, media: media,
            viewerID: viewer, graph: context
        )
        XCTAssertFalse(relation.canView)

        let taggedRelation = MomentAuthorization.relation(
            moment: moment, members: members, media: media,
            viewerID: tagged, graph: context
        )
        // Self is always a path, so a tagged member keeps their own view.
        XCTAssertTrue(taggedRelation.isTagged)
        XCTAssertTrue(taggedRelation.canView)
    }

    // MARK: - Fixture

    private var moment: Moment {
        Moment(
            id: "m1",
            creatorID: creator,
            title: "Rooftop",
            locationText: "Rooftop",
            placeID: nil,
            pushID: nil,
            publishedAt: Date(timeIntervalSince1970: 1_000),
            lastActivityAt: Date(timeIntervalSince1970: 2_000),
            deletedAt: nil
        )
    }

    private var members: [MomentMember] {
        [creator, contributor, tagged].enumerated().map { index, personID in
            MomentMember(
                id: "member-\(personID)",
                momentID: "m1",
                personID: personID,
                taggedAt: Date(timeIntervalSince1970: 1_000 + Double(index))
            )
        }
    }

    private var media: [MomentMedia] {
        [creator, contributor, pastPoster].enumerated().map { index, uploaderID in
            MomentMedia(
                id: "media-\(uploaderID)",
                momentID: "m1",
                uploaderID: uploaderID,
                kind: .photo,
                storagePath: "pending/\(uploaderID)/\(index).jpg",
                publicURL: "https://example.invalid/\(index).jpg",
                posterPath: nil,
                posterURL: nil,
                sortOrder: index,
                createdAt: Date(timeIntervalSince1970: 1_500 + Double(index)),
                deletedAt: nil
            )
        }
    }

    /// Everyone in the fixture is an accepted friend unless stated otherwise.
    private func graph(
        for viewerID: Person.ID,
        friends: Set<Person.ID>? = nil,
        blocked: Set<Person.ID> = []
    ) -> MomentGraphContext {
        let friendSet = friends ?? Set([creator, contributor, tagged, pastPoster, viewer])
            .subtracting([viewerID])
        return MomentGraphContext(
            isFriend: { friendSet.contains($0) },
            isBlocked: { blocked.contains($0) }
        )
    }

    private func capabilities(
        for viewerID: Person.ID,
        friends: Set<Person.ID>? = nil
    ) -> MomentCapabilities {
        MomentAuthorization.capabilities(
            moment: moment,
            members: members,
            media: media,
            viewerID: viewerID,
            graph: graph(for: viewerID, friends: friends)
        )
    }
}
