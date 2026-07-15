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
        XCTAssertFalse(viewModel.hasUnreadAlerts)
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
}
