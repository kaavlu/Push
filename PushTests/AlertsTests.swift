import XCTest
@testable import Push

@MainActor
final class AlertsTests: XCTestCase {
    func testRouteMetadataUsesBell() {
        XCTAssertEqual(MainMapRoute.alerts.id, "alerts")
        XCTAssertEqual(MainMapRoute.alerts.accessibilityLabel, "Alerts")
        XCTAssertEqual(MainMapRoute.alerts.systemImageName, "bell.fill")
    }

    func testMockRequestLoadsAndAcceptRemovesIt() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AlertsViewModel(container: container)
        await viewModel.load()

        XCTAssertEqual(viewModel.requests.map(\.id), ["request-austin"])
        XCTAssertTrue(viewModel.hasUnreadAlerts)
        XCTAssertEqual(viewModel.requests.first?.request.mutualFriendCount, 4)
        XCTAssertEqual(viewModel.requests.first?.row.groupLabel, "4 mutual friends")

        await viewModel.accept(try XCTUnwrap(viewModel.requests.first))

        XCTAssertTrue(viewModel.requests.isEmpty)
        // The standard seed also carries two pending group invites for the
        // current user (see SeedData.standardPendingGroupInvites), so the
        // badge stays lit until those are resolved too.
        XCTAssertTrue(viewModel.hasUnreadAlerts)
        XCTAssertEqual(container.database.friendRequests.first?.status, .accepted)
    }

    func testLiveRequestUsesServerMutualFriendCount() async throws {
        let loader = LiveDataLoaderSpy()
        loader.friendshipRows = [
            FriendshipRow(
                id: "pending-incoming",
                user_low: "friend",
                user_high: "self",
                status: "pending",
                requested_by: "friend",
                created_at: "2026-07-29T12:00:00Z"
            )
        ]
        loader.mutualFriendCountRows = [
            IncomingFriendRequestMutualCountRow(
                request_id: "pending-incoming",
                mutual_friend_count: 7
            )
        ]
        let repository = SupabaseAlertRepository(
            store: LiveDataStore(loader: loader),
            currentUserID: "self"
        )

        let requests = try await repository.incomingFriendRequests()

        XCTAssertEqual(requests.map(\.id), ["pending-incoming"])
        XCTAssertEqual(requests.first?.mutualFriendCount, 7)
        XCTAssertEqual(
            FriendRequestAlertModel(request: try XCTUnwrap(requests.first)).row.groupLabel,
            "7 mutual friends"
        )
    }

    func testMutualFriendCopyHandlesSingularAndZero() {
        XCTAssertEqual(AlertsCopy.mutualFriendCountLabel(0), "0 mutual friends")
        XCTAssertEqual(AlertsCopy.mutualFriendCountLabel(1), "1 mutual friend")
    }

    func testMockRequestCanBeDenied() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AlertsViewModel(container: container)
        await viewModel.load()

        await viewModel.deny(try XCTUnwrap(viewModel.requests.first))

        XCTAssertTrue(viewModel.requests.isEmpty)
        XCTAssertEqual(container.database.friendRequests.first?.status, .denied)
    }

    func testMockGroupInvitesLoadAndAcceptRemovesIt() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AlertsViewModel(container: container)
        await viewModel.load()

        XCTAssertEqual(viewModel.groupInvites.map(\.groupID).sorted(), ["exec", "michigan"])

        let invite = try XCTUnwrap(viewModel.groupInvites.first { $0.groupID == "exec" })
        await viewModel.acceptGroupInvite(invite)

        XCTAssertFalse(viewModel.groupInvites.contains { $0.id == invite.id })
        XCTAssertTrue(
            container.database.memberships.contains {
                $0.id == invite.id && $0.membershipStatus == .active
            }
        )
    }

    func testMockGroupInviteCanBeDenied() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AlertsViewModel(container: container)
        await viewModel.load()

        let invite = try XCTUnwrap(viewModel.groupInvites.first { $0.groupID == "michigan" })
        await viewModel.denyGroupInvite(invite)

        XCTAssertFalse(viewModel.groupInvites.contains { $0.id == invite.id })
        XCTAssertFalse(container.database.memberships.contains { $0.id == invite.id })
    }

    func testFailureDrivesFailedLoadState() async {
        let viewModel = AlertsViewModel(repository: ThrowingAlertRepository())
        await viewModel.load()

        guard case .failed = viewModel.loadState else {
            return XCTFail("Expected failed alert load state")
        }
    }

    func testAcceptFailureKeepsRequestAndSetsActionError() async throws {
        let container = AppDataContainer(seed: .standard())
        let controllable = ControllableAlertRepository()
        controllable.requests = try await container.alerts.incomingFriendRequests()
        controllable.invites = try await container.alerts.incomingGroupInvites()
        controllable.shouldFailResolve = true
        let failingVM = AlertsViewModel(repository: controllable)
        await failingVM.load()
        let loaded = try XCTUnwrap(failingVM.requests.first)
        XCTAssertFalse(failingVM.requests.isEmpty)

        await failingVM.accept(loaded)

        XCTAssertTrue(failingVM.requests.contains { $0.id == loaded.id })
        XCTAssertEqual(failingVM.actionError?.message, "Couldn't accept. Try again.")
        if case .failed = failingVM.loadState {
            XCTFail("Action failure must not force full-screen failed load state")
        }
    }

    func testSoftReloadKeepsContentWhenSecondLoadFails() async throws {
        let controllable = ControllableAlertRepository()
        let container = AppDataContainer(seed: .standard())
        controllable.requests = try await container.alerts.incomingFriendRequests()
        controllable.invites = try await container.alerts.incomingGroupInvites()
        let viewModel = AlertsViewModel(repository: controllable)
        await viewModel.load()
        XCTAssertFalse(viewModel.requests.isEmpty)
        let before = viewModel.requests.count

        controllable.shouldFailLoad = true
        await viewModel.load()

        XCTAssertEqual(viewModel.requests.count, before)
        if case .failed = viewModel.loadState {
            XCTFail("Soft load should keep prior loaded state on refresh failure")
        }
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

@MainActor
final class ControllableAlertRepository: AlertRepository {
    var requests: [FriendRequest] = []
    var invites: [GroupInvite] = []
    var shouldFailLoad = false
    var shouldFailResolve = false

    enum Failure: Error { case expected }

    func incomingFriendRequests() async throws -> [FriendRequest] {
        if shouldFailLoad { throw Failure.expected }
        return requests
    }

    func incomingGroupInvites() async throws -> [GroupInvite] {
        if shouldFailLoad { throw Failure.expected }
        return invites
    }

    func acceptFriendRequest(id: FriendRequest.ID) async throws {
        if shouldFailResolve { throw Failure.expected }
        requests.removeAll { $0.id == id }
    }

    func denyFriendRequest(id: FriendRequest.ID) async throws {
        if shouldFailResolve { throw Failure.expected }
        requests.removeAll { $0.id == id }
    }

    func acceptGroupInvite(id: GroupInvite.ID) async throws {
        if shouldFailResolve { throw Failure.expected }
        invites.removeAll { $0.id == id }
    }

    func denyGroupInvite(id: GroupInvite.ID) async throws {
        if shouldFailResolve { throw Failure.expected }
        invites.removeAll { $0.id == id }
    }
}
