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
