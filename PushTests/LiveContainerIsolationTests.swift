import XCTest
import Combine
@testable import Push

@MainActor
final class LiveContainerIsolationTests: XCTestCase {
    func testLiveContainerExposesNoMockPresenceOrPushesOrFeed() async throws {
        let container = AppDataContainer.live(
            client: SupabaseClientProvider.shared.client,
            currentUserID: "11111111-1111-1111-1111-111111111111"
        )
        // No network is exercised here: these live repos return empty synchronously.
        let presence = try await container.friends.presenceStatuses()
        let plans = try await container.pushes.activePlans()
        let events = try await container.feed.events()
        XCTAssertTrue(presence.isEmpty)
        XCTAssertTrue(plans.isEmpty)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(container.currentUserID, "11111111-1111-1111-1111-111111111111")
    }

    func testMockContainerStillSeedsData() async throws {
        let container = AppDataContainer(seed: .standard())
        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.isEmpty)   // Existing behavior preserved.
    }
}
