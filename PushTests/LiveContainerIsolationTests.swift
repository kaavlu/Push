import XCTest
import Combine
@testable import Push

@MainActor
final class LiveContainerIsolationTests: XCTestCase {
    func testLiveContainerExposesNoMockPresenceOrFeed() async throws {
        let container = AppDataContainer.live(
            client: SupabaseClientProvider.shared.client,
            currentUserID: "11111111-1111-1111-1111-111111111111"
        )
        // No network is exercised here: these live repos return empty synchronously.
        let presence = try await container.friends.presenceStatuses()
        let events = try await container.feed.events()
        XCTAssertTrue(presence.isEmpty)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(container.currentUserID, "11111111-1111-1111-1111-111111111111")
    }

    // Pushes are live-persisted (unlike presence/feed, which stay mock-empty
    // Day-1), so "no mock leak" is verified structurally — the live container
    // must be wired to the real Supabase-backed repository, not the mock —
    // rather than by an unauthenticated network call, which real usage never
    // makes (`RootView` only installs a live container after sign-in) and
    // which would otherwise just 42501 against the `can_view_push` RLS
    // helper (revoked from `anon`, same as `is_group_member`/`is_friend`).
    // Behavioral coverage (create/update/cancel/respond) lives in
    // `SupabasePushRepositoryTests`.
    func testLiveContainerWiresRealPushRepositoryNotMock() {
        let container = AppDataContainer.live(
            client: SupabaseClientProvider.shared.client,
            currentUserID: "11111111-1111-1111-1111-111111111111"
        )
        XCTAssertTrue(container.pushes is SupabasePushRepository)
    }

    func testMockContainerStillSeedsData() async throws {
        let container = AppDataContainer(seed: .standard())
        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.isEmpty)   // Existing behavior preserved.
    }
}
