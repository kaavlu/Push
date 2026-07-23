import XCTest
@testable import Push

/// Issue #44 — friend relationship lifecycle matrix (mock store + ViewModels).
@MainActor
final class FriendRelationshipTests: XCTestCase {

    // MARK: - Duplicate / idempotent send

    func testDuplicateSendDoesNotCreateSecondPendingRequest() async throws {
        let container = AppDataContainer(seed: .standard())
        let first = try await container.friends.sendFriendRequest(to: "jordan")
        let second = try await container.friends.sendFriendRequest(to: "jordan")

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second)
        let pending = container.database.friendRequests.filter {
            $0.status == .pending && $0.requester.id == container.currentUserID && $0.recipientID == "jordan"
        }
        XCTAssertEqual(pending.count, 1)
    }

    func testSendToExistingFriendIsNoOp() async throws {
        let container = AppDataContainer(seed: .standard())
        let before = container.database.friendRequests.count
        _ = try await container.friends.sendFriendRequest(to: "ram")
        XCTAssertEqual(container.database.friendRequests.count, before)

        let results = try await container.friends.searchPeople(query: "ram")
        XCTAssertEqual(results.first?.relation, .friends)
    }

    // MARK: - Cancel outgoing

    func testCancelOutgoingRemovesRequestFromSearchAndAlerts() async throws {
        let container = AppDataContainer(seed: .standard())
        let requestID = try await container.friends.sendFriendRequest(to: "jordan")
        XCTAssertFalse(requestID.isEmpty)

        try await container.friends.cancelFriendRequest(id: requestID)

        let results = try await container.friends.searchPeople(query: "jordan")
        XCTAssertEqual(results.first?.relation, FriendshipRelation.none)
        XCTAssertFalse(
            container.database.friendRequests.contains {
                $0.id == requestID && $0.status == .pending
            }
        )
    }

    func testCancelIsIdempotentForMissingRequest() async throws {
        let container = AppDataContainer(seed: .standard())
        // No throw — mock no-ops unknown ids (matches “stale client” soft recovery).
        try await container.friends.cancelFriendRequest(id: "request-does-not-exist")
    }

    // MARK: - Deny + re-request

    func testDenyThenReRequestCreatesOneActivePending() async throws {
        let container = AppDataContainer(seed: .standard())
        try await container.alerts.denyFriendRequest(id: "request-austin")

        let afterDeny = try await container.friends.searchPeople(query: "austin")
        XCTAssertEqual(afterDeny.first?.relation, FriendshipRelation.none)

        let alerts = try await container.alerts.incomingFriendRequests()
        XCTAssertFalse(alerts.contains { $0.id == "request-austin" })

        let reopened = try await container.friends.sendFriendRequest(to: "austin")
        XCTAssertFalse(reopened.isEmpty)

        let afterSend = try await container.friends.searchPeople(query: "austin")
        guard case .outgoingPending(let id) = afterSend.first?.relation else {
            return XCTFail("Expected outgoing pending after re-request")
        }
        XCTAssertEqual(id, reopened)

        let pending = container.database.friendRequests.filter {
            $0.status == .pending
                && (
                    ($0.requester.id == container.currentUserID && $0.recipientID == "austin")
                        || ($0.requester.id == "austin" && $0.recipientID == container.currentUserID)
                )
        }
        XCTAssertEqual(pending.count, 1)
    }

    // MARK: - Accept + cannot re-send while friends

    func testAcceptMakesFriendsAndBlocksFurtherRequests() async throws {
        let container = AppDataContainer(seed: .standard())
        try await container.alerts.acceptFriendRequest(id: "request-austin")

        let friends = try await container.friends.friends().map(\.id)
        XCTAssertTrue(friends.contains("austin"))

        let results = try await container.friends.searchPeople(query: "austin")
        XCTAssertEqual(results.first?.relation, .friends)

        let before = container.database.friendRequests.filter { $0.status == .pending }.count
        _ = try await container.friends.sendFriendRequest(to: "austin")
        let after = container.database.friendRequests.filter { $0.status == .pending }.count
        XCTAssertEqual(before, after)
    }

    // MARK: - Remove + re-add; groups and pushes intact

    func testRemoveFriendClearsRelationshipAndAllowsReRequest() async throws {
        let container = AppDataContainer(seed: .standard())
        try await container.alerts.acceptFriendRequest(id: "request-austin")
        let friendsAfterAccept = try await container.friends.friends().map(\.id)
        XCTAssertTrue(friendsAfterAccept.contains("austin"))

        let groupsBefore = try await container.groups.groups().map(\.id)
        let membershipsBefore = try await container.groups.memberships().count
        let plansBefore = try await container.pushes.activePlans().map(\.id)

        try await container.friends.removeFriend("austin")

        let friendsAfterRemove = try await container.friends.friends().map(\.id)
        XCTAssertFalse(friendsAfterRemove.contains("austin"))
        let results = try await container.friends.searchPeople(query: "austin")
        XCTAssertEqual(results.first?.relation, FriendshipRelation.none)

        let groupsAfter = try await container.groups.groups().map(\.id)
        let membershipsAfter = try await container.groups.memberships().count
        let plansAfter = try await container.pushes.activePlans().map(\.id)
        XCTAssertEqual(groupsAfter, groupsBefore)
        XCTAssertEqual(membershipsAfter, membershipsBefore)
        XCTAssertEqual(plansAfter, plansBefore)

        let requestID = try await container.friends.sendFriendRequest(to: "austin")
        XCTAssertFalse(requestID.isEmpty)
        let afterReRequest = try await container.friends.searchPeople(query: "austin")
        guard case .outgoingPending = afterReRequest.first?.relation else {
            return XCTFail("Expected outgoing pending after re-add request")
        }
    }

    func testRemoveFriendClearsPendingBetweenPair() async throws {
        let container = AppDataContainer(seed: .standard())
        let requestID = try await container.friends.sendFriendRequest(to: "jordan")
        // Treat as “remove” cleanup for the pair even without accepted friendship.
        try await container.friends.removeFriend("jordan")

        XCTAssertFalse(
            container.database.friendRequests.contains { $0.id == requestID && $0.status == .pending }
        )
        let results = try await container.friends.searchPeople(query: "jordan")
        XCTAssertEqual(results.first?.relation, FriendshipRelation.none)
    }

    // MARK: - Search state matrix

    func testSearchMapsNoneOutgoingIncomingFriends() async throws {
        let container = AppDataContainer(seed: .standard())
        _ = try await container.friends.sendFriendRequest(to: "jordan")

        let results = try await container.friends.searchPeople(query: "a")
        XCTAssertFalse(results.contains { $0.person.id == container.currentUserID })
        XCTAssertEqual(
            results.first { $0.person.id == "austin" }?.relation,
            .incomingPending(requestID: "request-austin")
        )
        guard case .outgoingPending = results.first(where: { $0.person.id == "jordan" })?.relation else {
            return XCTFail("Expected jordan outgoing")
        }
        XCTAssertEqual(results.first { $0.person.id == "ram" }?.relation, .friends)
    }

    // MARK: - ViewModel optimistic rollback

    func testSendFailureRestoresRelationAndSetsActionError() async throws {
        let viewModel = AddFriendsViewModel(
            friends: ControllableFriendRepository(shouldFailMutations: true),
            alerts: ControllableAlertRepository()
        )
        viewModel.onSearchTextChanged("pat")
        try await waitForResults(viewModel)
        let row = try XCTUnwrap(viewModel.rows.first)

        await viewModel.sendRequest(to: row)

        XCTAssertEqual(viewModel.rows.first?.relation, FriendshipRelation.none)
        XCTAssertEqual(viewModel.actionError?.message, AddFriendsMutationCopy.sendFailed)
    }

    func testCancelFailureRestoresOutgoingAndSetsActionError() async throws {
        let friends = ControllableFriendRepository(shouldFailMutations: true)
        friends.seedOutgoing("pat", requestID: "req-1")
        let viewModel = AddFriendsViewModel(friends: friends, alerts: ControllableAlertRepository())
        viewModel.onSearchTextChanged("pat")
        try await waitForResults(viewModel)
        let row = try XCTUnwrap(viewModel.rows.first)

        await viewModel.cancelRequest(for: row)

        guard case .outgoingPending(let id) = viewModel.rows.first?.relation else {
            return XCTFail("Expected outgoing restored after cancel failure")
        }
        XCTAssertEqual(id, "req-1")
        XCTAssertEqual(viewModel.actionError?.message, AddFriendsMutationCopy.cancelFailed)
    }

    func testViewModelCancelOutgoingSucceeds() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AddFriendsViewModel(container: container)
        viewModel.onSearchTextChanged("jordan")
        try await waitForResults(viewModel)
        let jordan = try XCTUnwrap(viewModel.rows.first { $0.id == "jordan" })
        await viewModel.sendRequest(to: jordan)
        try await waitForResults(viewModel)

        let outgoing = try XCTUnwrap(viewModel.rows.first { $0.id == "jordan" })
        await viewModel.cancelRequest(for: outgoing)
        try await waitForResults(viewModel)

        XCTAssertEqual(
            viewModel.rows.first { $0.id == "jordan" }?.relation,
            FriendshipRelation.none
        )
        XCTAssertNil(viewModel.actionError)
    }

    // MARK: - Live store cancel / remove invalidate revision

    func testLiveStoreCancelAndRemoveBumpRevision() async throws {
        let loader = LiveDataLoaderSpy()
        loader.friendshipRows = [
            FriendshipRow(
                id: "pending-1",
                user_low: "other",
                user_high: "self",
                status: "pending",
                requested_by: "self",
                created_at: "2026-07-14T00:00:00Z"
            ),
            FriendshipRow(
                id: "accepted-1",
                user_low: "friend",
                user_high: "self",
                status: "accepted",
                requested_by: nil,
                created_at: "2026-07-14T00:00:00Z"
            )
        ]
        let store = LiveDataStore(loader: loader)
        let before = store.revision

        try await store.cancelFriendRequest(id: "pending-1")
        XCTAssertGreaterThan(store.revision, before)
        XCTAssertFalse(loader.friendshipRows.contains { $0.id == "pending-1" })

        let mid = store.revision
        try await store.removeFriend(targetUserID: "friend")
        XCTAssertGreaterThan(store.revision, mid)
        XCTAssertFalse(loader.friendshipRows.contains { $0.involves("friend") })
    }

    // MARK: - Helpers

    private func waitForResults(_ viewModel: AddFriendsViewModel) async throws {
        for _ in 0..<40 {
            if case .results = viewModel.contentState { return }
            if case .failed = viewModel.contentState {
                return XCTFail("Search failed while waiting for results")
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for search results: \(viewModel.contentState)")
    }
}

private extension AddFriendsViewModel {
    var rows: [AddFriendRowModel] {
        if case .results(let rows) = contentState { return rows }
        return []
    }
}

// MARK: - Controllable fakes

@MainActor
private final class ControllableFriendRepository: FriendRepository {
    var shouldFailMutations: Bool
    private var results: [PersonSearchResult]

    init(shouldFailMutations: Bool = false) {
        self.shouldFailMutations = shouldFailMutations
        self.results = [
            PersonSearchResult(
                person: Person(id: "pat", firstName: "Pat", imageAssetPath: nil),
                handle: "pat",
                relation: .none
            )
        ]
    }

    func seedOutgoing(_ personID: Person.ID, requestID: String) {
        results = results.map { row in
            guard row.person.id == personID else { return row }
            return PersonSearchResult(
                person: row.person,
                handle: row.handle,
                relation: .outgoingPending(requestID: requestID)
            )
        }
    }

    func friends() async throws -> [Person] { [] }
    func currentUser() async throws -> Person {
        Person(id: "me", firstName: "Me", imageAssetPath: nil)
    }
    func presenceStatuses() async throws -> [PresenceStatus] { [] }
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {}

    func searchPeople(query: String) async throws -> [PersonSearchResult] {
        let q = query.lowercased()
        return results.filter {
            $0.person.firstName.lowercased().contains(q) || $0.handle.lowercased().contains(q)
        }
    }

    func sendFriendRequest(to personID: Person.ID) async throws -> FriendRequest.ID {
        if shouldFailMutations { throw URLError(.notConnectedToInternet) }
        let id = "req-\(personID)"
        results = results.map { row in
            guard row.person.id == personID else { return row }
            return PersonSearchResult(
                person: row.person,
                handle: row.handle,
                relation: .outgoingPending(requestID: id)
            )
        }
        return id
    }

    func cancelFriendRequest(id: FriendRequest.ID) async throws {
        if shouldFailMutations { throw URLError(.notConnectedToInternet) }
        results = results.map { row in
            if case .outgoingPending(let requestID) = row.relation, requestID == id {
                return PersonSearchResult(person: row.person, handle: row.handle, relation: .none)
            }
            return row
        }
    }

    func removeFriend(_ personID: Person.ID) async throws {
        if shouldFailMutations { throw URLError(.notConnectedToInternet) }
    }

    func blockUser(_ personID: Person.ID) async throws {
        if shouldFailMutations { throw URLError(.notConnectedToInternet) }
    }

    func unblockUser(_ personID: Person.ID) async throws {
        if shouldFailMutations { throw URLError(.notConnectedToInternet) }
    }

    func blockedUsers() async throws -> [BlockedPerson] { [] }
}

