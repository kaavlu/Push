import XCTest
@testable import Push

@MainActor
final class AddFriendsTests: XCTestCase {
    func testSearchExcludesSelfAndMapsRelations() async throws {
        let container = AppDataContainer(seed: .standard())
        let results = try await container.friends.searchPeople(query: "a")

        XCTAssertFalse(results.contains { $0.person.id == container.currentUserID })
        XCTAssertEqual(
            results.first { $0.person.id == "austin" }?.relation,
            .incomingPending(requestID: "request-austin")
        )
        XCTAssertEqual(
            results.first { $0.person.id == "jordan" }?.relation,
            FriendshipRelation.none
        )
        XCTAssertEqual(
            results.first { $0.person.id == "ram" }?.relation,
            .friends
        )
    }

    func testSendFriendRequestMarksOutgoingPending() async throws {
        let container = AppDataContainer(seed: .standard())
        try await container.friends.sendFriendRequest(to: "jordan")

        let results = try await container.friends.searchPeople(query: "jordan")
        guard case .outgoingPending = results.first?.relation else {
            return XCTFail("Expected outgoing pending for jordan")
        }

        let alerts = try await container.alerts.incomingFriendRequests()
        XCTAssertFalse(alerts.contains { $0.requester.id == "jordan" })
    }

    func testAcceptFromAlertsAddsFriendAndUpdatesSearch() async throws {
        let container = AppDataContainer(seed: .standard())
        let before = try await container.friends.friends().map(\.id)
        XCTAssertFalse(before.contains("austin"))

        let alertsVM = AlertsViewModel(container: container)
        await alertsVM.load()
        await alertsVM.accept(try XCTUnwrap(alertsVM.requests.first))

        let after = try await container.friends.friends().map(\.id)
        XCTAssertTrue(after.contains("austin"))

        let results = try await container.friends.searchPeople(query: "austin")
        XCTAssertEqual(results.first?.relation, .friends)
    }

    func testAddFriendsViewModelSendAndAccept() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AddFriendsViewModel(container: container)

        viewModel.onSearchTextChanged("jordan")
        try await waitForResults(viewModel)
        let jordan = try XCTUnwrap(
            viewModel.rows.first { $0.id == "jordan" }
        )
        await viewModel.sendRequest(to: jordan)
        try await waitForResults(viewModel)
        guard case .outgoingPending = viewModel.rows.first(where: { $0.id == "jordan" })?.relation else {
            return XCTFail("Expected outgoing pending after send")
        }

        viewModel.onSearchTextChanged("austin")
        try await waitForResults(viewModel)
        let austin = try XCTUnwrap(viewModel.rows.first { $0.id == "austin" })
        await viewModel.accept(row: austin)
        try await waitForResults(viewModel)
        XCTAssertEqual(viewModel.rows.first { $0.id == "austin" }?.relation, .friends)
    }

    func testSearchFailureDrivesFailedState() async {
        let viewModel = AddFriendsViewModel(
            friends: ThrowingFriendRepository(),
            alerts: ThrowingAlertRepository()
        )
        viewModel.onSearchTextChanged("anyone")
        // Debounce then wait for the throwing search to settle (avoid flaky single sleep).
        for _ in 0..<40 {
            if case .failed = viewModel.contentState { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(viewModel.contentState, .failed)
    }

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

private struct ThrowingAlertRepository: AlertRepository {
    enum Failure: Error { case unavailable }
    func incomingFriendRequests() async throws -> [FriendRequest] { throw Failure.unavailable }
    func acceptFriendRequest(id: FriendRequest.ID) async throws { throw Failure.unavailable }
    func denyFriendRequest(id: FriendRequest.ID) async throws { throw Failure.unavailable }
    func incomingGroupInvites() async throws -> [GroupInvite] { throw Failure.unavailable }
    func acceptGroupInvite(id: GroupInvite.ID) async throws { throw Failure.unavailable }
    func denyGroupInvite(id: GroupInvite.ID) async throws { throw Failure.unavailable }
}
