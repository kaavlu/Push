import XCTest
@testable import Push

@MainActor
final class BlockUserTests: XCTestCase {
    func testBlockRemovesFriendshipAndPendingRequests() async throws {
        let container = AppDataContainer(seed: .standard())
        let friendID = try await container.friends.friends().first!.id

        try await container.friends.blockUser(friendID)

        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.contains { $0.id == friendID })

        let blocked = try await container.friends.blockedUsers()
        XCTAssertTrue(blocked.contains { $0.id == friendID })

        // Cannot re-friend while blocked — send is a no-op; search hides blocked.
        try await container.friends.sendFriendRequest(to: friendID)
        let hits = try await container.friends.searchPeople(query: blocked.first!.firstName)
        XCTAssertFalse(hits.contains { $0.id == friendID })
        let relation = container.database.relation(to: friendID)
        XCTAssertEqual(relation, .none)
    }

    func testUnblockDoesNotRestoreFriendship() async throws {
        let container = AppDataContainer(seed: .standard())
        let friendID = try await container.friends.friends().first!.id
        try await container.friends.blockUser(friendID)
        try await container.friends.unblockUser(friendID)

        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.contains { $0.id == friendID })
        let blocked = try await container.friends.blockedUsers()
        XCTAssertFalse(blocked.contains { $0.id == friendID })

        // Re-request allowed after unblock.
        try await container.friends.sendFriendRequest(to: friendID)
        let relation = container.database.relation(to: friendID)
        if case .outgoingPending = relation {
            // ok
        } else {
            XCTFail("expected outgoing pending after re-request, got \(relation)")
        }
    }

    func testBlockWithNoPriorRelationship() async throws {
        let container = AppDataContainer(seed: .standard())
        // jordan is discoverable seed with no friendship / pending request.
        let hits = try await container.friends.searchPeople(query: "jordan")
        guard let target = hits.first(where: { $0.relation == .none }) else {
            throw XCTSkip("no discoverable non-friend in seed")
        }
        try await container.friends.blockUser(target.id)
        let after = try await container.friends.searchPeople(query: "jordan")
        XCTAssertFalse(after.contains { $0.id == target.id })
    }

    func testIncomingFriendRequestSoftHiddenWhenBlocked() async throws {
        let container = AppDataContainer(seed: .standard())
        let requests = try await container.alerts.incomingFriendRequests()
        guard let request = requests.first else {
            throw XCTSkip("no incoming request in seed")
        }
        try await container.friends.blockUser(request.requester.id)
        let after = try await container.alerts.incomingFriendRequests()
        XCTAssertFalse(after.contains { $0.id == request.id })
    }

    /// Seed exec/michigan invites are owned by ram — block hides them from
    /// Alerts without deleting the pending membership rows.
    func testGroupInviteSoftHiddenWhenInviterBlocked() async throws {
        let container = AppDataContainer(seed: .standard())
        let invites = try await container.alerts.incomingGroupInvites()
        XCTAssertFalse(invites.isEmpty)
        let inviterID = try XCTUnwrap(invites.first?.inviterID)
        XCTAssertFalse(inviterID.isEmpty)

        try await container.friends.blockUser(inviterID)

        let after = try await container.alerts.incomingGroupInvites()
        XCTAssertFalse(after.contains { $0.inviterID == inviterID })
        // Soft-hide only — memberships stay so unblock does not need re-invite.
        XCTAssertTrue(
            container.database.memberships.contains {
                $0.personID == container.currentUserID && $0.membershipStatus == .invited
            }
        )
    }

    /// Start Push / Add Group pickers load via friends() only; after block the
    /// target is gone from that list so they cannot be re-selected as invitees.
    func testBlockedFriendExcludedFromFriendsPickerSource() async throws {
        let container = AppDataContainer(seed: .standard())
        let friendID = try await container.friends.friends().first!.id
        try await container.friends.blockUser(friendID)

        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.contains { $0.id == friendID })
    }

    /// Live friends() drops outbound-blocked ids (including co-members still on profiles).
    func testLiveFriendsExcludesBlockedUsers() async throws {
        let loader = LiveDataLoaderSpy()
        loader.blockedRows = [
            SearchProfileRow(
                id: "friend", first_name: "Friend", handle: "friend", image_asset_path: nil
            )
        ]
        let store = LiveDataStore(loader: loader)
        let friends = SupabaseFriendRepository(store: store, currentUserID: "self")

        let people = try await friends.friends()
        XCTAssertFalse(people.contains { $0.id.caseInsensitiveCompare("friend") == .orderedSame })
    }

    /// Live Alerts soft-hides group invites whose inviter is in list_blocked_users.
    func testLiveGroupInviteSoftHiddenWhenInviterBlocked() async throws {
        let loader = LiveDataLoaderSpy()
        loader.groupInviteRows = [
            GroupInviteRow(
                membership_id: "m-blocked",
                group_id: "g1",
                group_name: "Blocked Invite",
                image_asset_path: nil,
                inviter_id: "blocked-peer",
                inviter_first_name: "Blocked",
                inviter_image: nil,
                member_count: 2,
                created_at: "2026-07-14T00:00:00Z"
            ),
            GroupInviteRow(
                membership_id: "m-ok",
                group_id: "g2",
                group_name: "Ok Invite",
                image_asset_path: nil,
                inviter_id: "friend",
                inviter_first_name: "Friend",
                inviter_image: nil,
                member_count: 3,
                created_at: "2026-07-14T01:00:00Z"
            )
        ]
        loader.blockedRows = [
            SearchProfileRow(
                id: "blocked-peer",
                first_name: "Blocked",
                handle: "blocked",
                image_asset_path: nil
            )
        ]
        let store = LiveDataStore(loader: loader)
        let alerts = SupabaseAlertRepository(store: store, currentUserID: "self")

        let invites = try await alerts.incomingGroupInvites()
        XCTAssertEqual(invites.map(\.id), ["m-ok"])
        XCTAssertFalse(invites.contains { $0.inviterID == "blocked-peer" })
    }

    /// Blocked direct friends are excluded; group co-members still get responses.
    func testGroupAudiencePushKeepsBlockedCoMember() async throws {
        let container = AppDataContainer(seed: .standard())
        let me = container.currentUserID
        // chitty is an active member of seed group "india" and a friend.
        let blockedID = "chitty"
        try await container.friends.blockUser(blockedID)

        let id = try await container.pushes.createPush(PushDraft(
            title: "India hang",
            recipientIDs: ["group_india"],
            startsAt: Date(), locationText: "", notes: "", creatorID: me
        ))
        let responses = try await container.pushes.responses().filter { $0.pushID == id }
        XCTAssertTrue(
            responses.contains { $0.personID == blockedID && $0.response == .pending },
            "blocked co-member should still receive a group-audience response"
        )

        // Direct person recipient remains filtered.
        let other = try await container.friends.friends().first!.id
        let directID = try await container.pushes.createPush(PushDraft(
            title: "Direct",
            recipientIDs: ["friend_\(blockedID)", "friend_\(other)"],
            startsAt: Date(), locationText: "", notes: "", creatorID: me
        ))
        let direct = try await container.pushes.responses().filter { $0.pushID == directID }
        XCTAssertFalse(direct.contains { $0.personID == blockedID })
        XCTAssertTrue(direct.contains { $0.personID == other && $0.response == .pending })
    }

    /// Failed block must keep the friend row and surface a recoverable banner.
    func testBlockFailureKeepsFriendAndSurfacesError() async throws {
        let container = AppDataContainer(seed: .standard())
        let failingFriends = BlockFailingFriendRepository(backing: container.friends)
        let viewModel = FriendsViewModel(
            friends: failingFriends,
            groups: container.groups,
            sharing: container.sharing,
            pushes: container.pushes
        )
        await waitForFriendsLoad(viewModel)
        let row = try XCTUnwrap(viewModel.rows.first)
        let beforeCount = viewModel.rows.count

        await viewModel.blockFriend(row)

        XCTAssertEqual(viewModel.rows.count, beforeCount)
        XCTAssertTrue(viewModel.rows.contains { $0.id == row.id })
        XCTAssertEqual(
            viewModel.actionError?.message,
            "Couldn't block \(row.friend.name). Try again."
        )
        XCTAssertFalse(viewModel.blockingFriendIDs.contains(row.id))
    }

    func testUnblockRemovesFromList() async throws {
        let container = AppDataContainer(seed: .standard())
        let friendID = try await container.friends.friends().first!.id
        try await container.friends.blockUser(friendID)
        let vm = BlockedUsersViewModel(friends: container.friends, container: container)
        await vm.load()
        guard case .loaded(let people) = vm.loadState else {
            return XCTFail("expected loaded blocked list")
        }
        XCTAssertTrue(people.contains { $0.id == friendID })
        let person = people.first { $0.id == friendID }!
        await vm.unblock(person)
        guard case .loaded(let after) = vm.loadState else {
            return XCTFail("expected loaded after unblock")
        }
        XCTAssertFalse(after.contains { $0.id == friendID })
        XCTAssertNil(vm.actionError)
    }

    /// Failed unblock must keep the person on the list and surface a banner.
    func testUnblockFailureKeepsPersonAndSurfacesError() async throws {
        let container = AppDataContainer(seed: .standard())
        let friendID = try await container.friends.friends().first!.id
        try await container.friends.blockUser(friendID)
        let failingFriends = UnblockFailingFriendRepository(backing: container.friends)
        let vm = BlockedUsersViewModel(friends: failingFriends, container: container)
        await vm.load()
        guard case .loaded(let people) = vm.loadState else {
            return XCTFail("expected loaded blocked list")
        }
        let person = try XCTUnwrap(people.first { $0.id == friendID })

        await vm.unblock(person)

        guard case .loaded(let after) = vm.loadState else {
            return XCTFail("expected loaded after failed unblock")
        }
        XCTAssertTrue(after.contains { $0.id == friendID })
        let displayName = person.firstName.prefix(1).uppercased() + person.firstName.dropFirst()
        XCTAssertEqual(
            vm.actionError?.message,
            "Couldn't unblock \(displayName). Try again."
        )
        XCTAssertFalse(vm.unblockingIDs.contains(person.id))
    }

    private func waitForFriendsLoad(_ viewModel: FriendsViewModel) async {
        for _ in 0..<50 {
            if viewModel.loadState.value != nil { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

/// Forwards all friend reads/writes except `blockUser`, which always throws.
@MainActor
private final class BlockFailingFriendRepository: FriendRepository {
    enum Failure: Error { case expected }

    private let backing: FriendRepository

    init(backing: FriendRepository) {
        self.backing = backing
    }

    func friends() async throws -> [Person] { try await backing.friends() }
    func currentUser() async throws -> Person { try await backing.currentUser() }
    func presenceStatuses() async throws -> [PresenceStatus] {
        try await backing.presenceStatuses()
    }
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        try await backing.setCurrentUserAvailability(availability)
    }
    func searchPeople(query: String) async throws -> [PersonSearchResult] {
        try await backing.searchPeople(query: query)
    }
    func sendFriendRequest(to personID: Person.ID) async throws {
        try await backing.sendFriendRequest(to: personID)
    }
    func removeFriend(_ personID: Person.ID) async throws {
        try await backing.removeFriend(personID)
    }
    func blockUser(_ personID: Person.ID) async throws {
        throw Failure.expected
    }
    func unblockUser(_ personID: Person.ID) async throws {
        try await backing.unblockUser(personID)
    }
    func blockedUsers() async throws -> [BlockedPerson] {
        try await backing.blockedUsers()
    }
}

/// Forwards all friend reads/writes except `unblockUser`, which always throws.
@MainActor
private final class UnblockFailingFriendRepository: FriendRepository {
    enum Failure: Error { case expected }

    private let backing: FriendRepository

    init(backing: FriendRepository) {
        self.backing = backing
    }

    func friends() async throws -> [Person] { try await backing.friends() }
    func currentUser() async throws -> Person { try await backing.currentUser() }
    func presenceStatuses() async throws -> [PresenceStatus] {
        try await backing.presenceStatuses()
    }
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        try await backing.setCurrentUserAvailability(availability)
    }
    func searchPeople(query: String) async throws -> [PersonSearchResult] {
        try await backing.searchPeople(query: query)
    }
    func sendFriendRequest(to personID: Person.ID) async throws {
        try await backing.sendFriendRequest(to: personID)
    }
    func removeFriend(_ personID: Person.ID) async throws {
        try await backing.removeFriend(personID)
    }
    func blockUser(_ personID: Person.ID) async throws {
        try await backing.blockUser(personID)
    }
    func unblockUser(_ personID: Person.ID) async throws {
        throw Failure.expected
    }
    func blockedUsers() async throws -> [BlockedPerson] {
        try await backing.blockedUsers()
    }
}
