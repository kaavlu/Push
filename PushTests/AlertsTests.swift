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

        await viewModel.accept(try XCTUnwrap(viewModel.requests.first))

        XCTAssertTrue(viewModel.requests.isEmpty)
        // The standard seed also carries two pending group invites for the
        // current user (see SeedData.standardPendingGroupInvites), so the
        // badge stays lit until those are resolved too.
        XCTAssertTrue(viewModel.hasUnreadAlerts)
        XCTAssertEqual(container.database.friendRequests.first?.status, .accepted)
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
