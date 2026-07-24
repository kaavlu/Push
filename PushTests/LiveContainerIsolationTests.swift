import XCTest
import Combine
@testable import Push

@MainActor
final class LiveContainerIsolationTests: XCTestCase {
    func testPreparedLiveWithEmptyPresenceDoesNotLeakMockSeed() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = []
        let container = try await AppDataContainer.prepareLive(
            loader: loader, currentUserID: "self"
        )
        // Empty live presence + empty feed — never mock seed pucks / hangouts.
        let presence = try await container.friends.presenceStatuses()
        let places = try await container.pushes.allPlaces()
        let events = try await container.feed.events()
        XCTAssertTrue(presence.isEmpty)
        XCTAssertTrue(places.isEmpty)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(container.currentUserID, "self")
    }

    func testLiveContainerWiresRealFriendAndPushRepositories() {
        let container = AppDataContainer.live(
            client: SupabaseClientProvider.shared.client,
            currentUserID: "11111111-1111-1111-1111-111111111111"
        )
        XCTAssertTrue(container.friends is SupabaseFriendRepository)
        XCTAssertTrue(container.pushes is SupabasePushRepository)
    }

    // Pushes and friend requests are live-persisted. "No mock leak" for presence
    // is covered by empty-cache prepared live above and LivePresenceReadTests.
    // Unauthenticated network is never exercised here — RootView only installs
    // a live container after sign-in.
    func testLiveContainerWiresRealPushRepositoryNotMock() {
        let container = AppDataContainer.live(
            client: SupabaseClientProvider.shared.client,
            currentUserID: "11111111-1111-1111-1111-111111111111"
        )
        XCTAssertTrue(container.pushes is SupabasePushRepository)
    }

    func testLiveContainerWiresRealAlertRepositoryNotMock() {
        let container = AppDataContainer.live(
            client: SupabaseClientProvider.shared.client,
            currentUserID: "11111111-1111-1111-1111-111111111111"
        )
        XCTAssertTrue(container.alerts is SupabaseAlertRepository)
    }

    func testMockContainerStillSeedsData() async throws {
        let container = AppDataContainer(seed: .standard())
        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.isEmpty)   // Existing behavior preserved.
    }
}
