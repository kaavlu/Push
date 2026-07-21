import XCTest
@testable import Push

/// Exercises `SupabasePushRepository` end-to-end against the same stateful
/// `LiveDataLoaderSpy` fake used by `LiveDataStoreTests`, so create/update/
/// cancel/respond behave the same as they would against real PostgREST
/// (minus RLS, which the migration/advisors check covers separately).
@MainActor
final class SupabasePushRepositoryTests: XCTestCase {
    private func makeRepository(
        loader: LiveDataLoaderSpy, currentUserID: String
    ) -> (SupabasePushRepository, LiveDataStore) {
        let store = LiveDataStore(loader: loader)
        return (SupabasePushRepository(store: store, currentUserID: currentUserID), store)
    }

    func testCreatePushSeedsCreatorInAndGroupInviteesPending() async throws {
        let loader = LiveDataLoaderSpy()
        loader.membershipRows = [
            GroupMembershipRow(
                id: "m1", person_id: "member1", group_id: "g1", role: "member",
                membership_status: "active", joined_at: "2026-07-14T00:00:00Z"
            )
        ]
        let (repo, store) = makeRepository(loader: loader, currentUserID: "creator1")

        let draft = PushDraft(
            title: "Beach day", recipientIDs: ["group_g1"],
            startsAt: Date(), locationText: "The pier", notes: "Bring towels",
            creatorID: "creator1"
        )
        let planID = try await repo.createPush(draft)

        let plans = try await repo.activePlans()
        XCTAssertEqual(plans.map(\.id), [planID])
        XCTAssertEqual(plans.first?.audience, .group)
        XCTAssertEqual(plans.first?.groupID, "g1")

        let responses = try await repo.responses()
        let byPerson = Dictionary(uniqueKeysWithValues: responses.map { ($0.personID, $0.response) })
        XCTAssertEqual(byPerson["creator1"], .in)
        XCTAssertEqual(byPerson["member1"], .pending)
        XCTAssertGreaterThan(store.revision, 0)
    }

    func testUpdatePushReconcilesInviteesAddingAndRemoving() async throws {
        let loader = LiveDataLoaderSpy()
        let (repo, _) = makeRepository(loader: loader, currentUserID: "creator1")

        let created = try await repo.createPush(PushDraft(
            title: "Dinner", recipientIDs: ["friend_bob"],
            startsAt: Date(), locationText: "", notes: "",
            creatorID: "creator1"
        ))

        try await repo.updatePush(planID: created, with: PushDraft(
            title: "Dinner (moved)", recipientIDs: ["friend_carol"],
            startsAt: Date().addingTimeInterval(3600), locationText: "New spot", notes: "",
            creatorID: "creator1"
        ))

        let responses = try await repo.responses()
        let personIDs = Set(responses.map(\.personID))
        XCTAssertTrue(personIDs.contains("carol"), "newly added invitee should get a pending row")
        XCTAssertFalse(personIDs.contains("bob"), "removed invitee's row should be dropped")
        XCTAssertTrue(personIDs.contains("creator1"), "creator's row is never dropped")

        let plans = try await repo.activePlans()
        XCTAssertEqual(plans.first?.title, "Dinner (moved)")
        XCTAssertEqual(plans.first?.locationText, "New spot")
    }

    func testUpdatePushPreservesExistingRsvpsForUntouchedInvitees() async throws {
        let loader = LiveDataLoaderSpy()
        let (repo, store) = makeRepository(loader: loader, currentUserID: "creator1")

        let created = try await repo.createPush(PushDraft(
            title: "Hike", recipientIDs: ["friend_bob"],
            startsAt: Date(), locationText: "", notes: "", creatorID: "creator1"
        ))
        // bob RSVPs .in before the creator edits the push.
        // Same session store as production: one LiveDataStore per container so
        // notifyPushesChanged() invalidates the snapshot both actors read.
        let bobRepo = SupabasePushRepository(store: store, currentUserID: "bob")
        try await bobRepo.setCurrentUserResponse(planID: created, response: .in)

        // Editing the push (still inviting bob, plus a title change) must not
        // reset bob's already-recorded RSVP back to pending.
        try await repo.updatePush(planID: created, with: PushDraft(
            title: "Hike (retitled)", recipientIDs: ["friend_bob"],
            startsAt: Date(), locationText: "", notes: "", creatorID: "creator1"
        ))

        let responses = try await repo.responses()
        XCTAssertEqual(responses.first { $0.personID == "bob" }?.response, .in)
    }

    func testCancelPushSoftCancelsAndHidesFromActivePlans() async throws {
        let loader = LiveDataLoaderSpy()
        let (repo, _) = makeRepository(loader: loader, currentUserID: "creator1")

        let created = try await repo.createPush(PushDraft(
            title: "Movie night", recipientIDs: [],
            startsAt: Date(), locationText: "", notes: "", creatorID: "creator1"
        ))
        try await repo.cancelPush(planID: created)

        let plans = try await repo.activePlans()
        XCTAssertTrue(plans.isEmpty, "a cancelled push must not appear in activePlans()")
        XCTAssertEqual(loader.pushRows.first?.cancelled_at != nil, true)
    }

    func testSetCurrentUserResponseUpsertsRsvpAndClearsRespondedAtForPending() async throws {
        let loader = LiveDataLoaderSpy()
        let (repo, store) = makeRepository(loader: loader, currentUserID: "creator1")
        let created = try await repo.createPush(PushDraft(
            title: "Game night", recipientIDs: ["friend_bob"],
            startsAt: Date(), locationText: "", notes: "", creatorID: "creator1"
        ))

        // Share the session store (mirrors AppDataContainer.live) so bob's
        // notifyPushesChanged() drops the snapshot creator reads next.
        let bobRepo = SupabasePushRepository(store: store, currentUserID: "bob")
        try await bobRepo.setCurrentUserResponse(planID: created, response: .maybe)
        var responses = try await repo.responses()
        let bobResponse = responses.first { $0.personID == "bob" }
        XCTAssertEqual(bobResponse?.response, .maybe)
        XCTAssertNotNil(bobResponse?.respondedAt)

        try await bobRepo.setCurrentUserResponse(planID: created, response: .pending)
        responses = try await repo.responses()
        XCTAssertNil(responses.first { $0.personID == "bob" }?.respondedAt)
    }

    func testInviteesDedupesFriendsAndGroupMembersExcludingCreator() {
        let parsed = PushRecipientResolver.parse(["friend_bob", "group_g1"])
        XCTAssertEqual(Set(parsed.friendIDs), ["bob"])
        XCTAssertEqual(parsed.groupIDs, ["g1"])
        XCTAssertFalse(parsed.singleGroupOnly, "a mixed friend+group selection isn't group-only audience")

        let memberships = [
            GroupMembership(
                id: "m1", personID: "bob", groupID: "g1", role: .member,
                sharingLevel: .full, membershipStatus: .active, joinedAt: Date()
            ),
            GroupMembership(
                id: "m2", personID: "creator1", groupID: "g1", role: .member,
                sharingLevel: .full, membershipStatus: .active, joinedAt: Date()
            )
        ]
        let invitees = PushRecipientResolver.invitees(
            groupIDs: parsed.groupIDs, friendIDs: parsed.friendIDs,
            memberships: memberships, creatorID: "creator1"
        )
        XCTAssertEqual(invitees, ["bob"], "bob is deduped (friend + group member) and the creator is excluded")
    }

    /// Blocked direct friend tokens are filtered; group co-members stay inviteable.
    func testCreatePushFiltersBlockedDirectFriendsButKeepsGroupCoMembers() async throws {
        let loader = LiveDataLoaderSpy()
        loader.blockedRows = [
            SearchProfileRow(
                id: "blocked-peer", first_name: "Blocked", handle: "blocked", image_asset_path: nil
            )
        ]
        loader.membershipRows = [
            GroupMembershipRow(
                id: "m1", person_id: "blocked-peer", group_id: "g1", role: "member",
                membership_status: "active", joined_at: "2026-07-14T00:00:00Z"
            ),
            GroupMembershipRow(
                id: "m2", person_id: "ok-friend", group_id: "g1", role: "member",
                membership_status: "active", joined_at: "2026-07-14T00:00:00Z"
            )
        ]
        let (repo, _) = makeRepository(loader: loader, currentUserID: "creator1")

        let groupID = try await repo.createPush(PushDraft(
            title: "Group hang",
            recipientIDs: ["group_g1"],
            startsAt: Date(), locationText: "", notes: "", creatorID: "creator1"
        ))
        let groupResponses = try await repo.responses().filter { $0.pushID == groupID }
        XCTAssertTrue(
            groupResponses.contains { $0.personID == "blocked-peer" && $0.response == .pending },
            "blocked co-member still gets a group-audience pending row"
        )
        XCTAssertTrue(groupResponses.contains { $0.personID == "ok-friend" })

        let directID = try await repo.createPush(PushDraft(
            title: "Direct",
            recipientIDs: ["friend_blocked-peer", "friend_ok-friend"],
            startsAt: Date(), locationText: "", notes: "", creatorID: "creator1"
        ))
        let direct = try await repo.responses().filter { $0.pushID == directID }
        XCTAssertFalse(direct.contains { $0.personID == "blocked-peer" })
        XCTAssertTrue(direct.contains { $0.personID == "ok-friend" && $0.response == .pending })
    }
}
