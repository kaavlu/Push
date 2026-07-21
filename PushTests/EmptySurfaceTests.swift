import CoreLocation
import XCTest
@testable import Push

final class EmptySurfaceTests: XCTestCase {
    func testCopyIsHonestAndDistinct() {
        XCTAssertFalse(EmptySurfaceCopy.mapEmptyTitle.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.feedDeferredTitle.isEmpty)
        XCTAssertNotEqual(EmptySurfaceCopy.mapEmptyTitle, EmptySurfaceCopy.failedTitle(surface: "map"))
        XCTAssertEqual(EmptySurfaceCopy.addFriendsAction, "Add friends")
        XCTAssertEqual(EmptySurfaceCopy.calendarEmptyFooter, "No hangouts this week")
        XCTAssertFalse(EmptySurfaceCopy.startPushEmptyTitle.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.startPushEmptyMessage.isEmpty)
    }

    func testSurfacePhasesAreDistinct() {
        let phases: [SurfaceContentPhase] = [.loading, .empty, .failed, .content, .deferred]
        XCTAssertEqual(Set(phases.map { String(describing: $0) }).count, 5)
    }

    @MainActor
    func testMapEmptyPhaseForEmptyGraph() async throws {
        let viewModel = MapViewModel(container: AppDataContainer(seed: .emptyGraph()))
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .empty)
        XCTAssertFalse(viewModel.hasFriendMapContent)
    }

    /// Self-only presence (exact place) is not friend map content — phase stays empty.
    @MainActor
    func testMapEmptyPhaseWhenOnlySelfHasPresence() async throws {
        let now = Date()
        let place = Place(
            id: "self-home",
            name: "Home",
            shortName: "Home",
            address: "1 Main",
            vagueLabel: "Mission",
            latitude: 37.77,
            longitude: -122.42,
            vagueLatitude: 37.76,
            vagueLongitude: -122.41
        )
        let user = Person(
            id: SeedIDs.currentUser,
            firstName: "manav",
            imageAssetPath: "assets/profile/manav.jpeg"
        )
        let status = PresenceStatus(
            id: "status-self",
            personID: SeedIDs.currentUser,
            availability: .freeNow,
            activity: PresenceActivity(name: "Home", symbolName: "house.fill"),
            placeID: place.id,
            statusNote: nil,
            confidence: .high,
            observedAt: now,
            updatedAt: now,
            expiresAt: nil,
            source: .seed
        )
        let seed = SeedData(
            currentUserID: SeedIDs.currentUser,
            people: [user],
            acceptedFriendIDs: [],
            groups: [],
            memberships: [],
            places: [place],
            statuses: [status],
            policies: [],
            plans: [],
            responses: [],
            hangouts: [],
            feedEvents: [],
            friendRequests: [],
            profile: SeedData.standardProfile()
        )
        let viewModel = MapViewModel(container: AppDataContainer(seed: seed))
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .empty)
        XCTAssertFalse(viewModel.hasFriendMapContent)
    }

    /// Friend vague regional sources count as friend content (self-only vague does not).
    func testFriendVagueSourcesCountAsMapContentPredicate() {
        let coordinate = CLLocationCoordinate2D(latitude: 37.76, longitude: -122.41)
        let selfSource = RegionalPuckSource(
            id: "vague-self",
            coordinate: coordinate,
            people: [],
            availability: .freeNow,
            regionName: "Mission",
            containsCurrentUser: true,
            groupIDs: []
        )
        let friendSource = RegionalPuckSource(
            id: "vague-friend",
            coordinate: coordinate,
            people: [],
            availability: .freeNow,
            regionName: "Mission",
            containsCurrentUser: false,
            groupIDs: []
        )
        // Mirrors MapViewModel.hasFriendMapContent vague branch.
        XCTAssertFalse([selfSource].contains { !$0.containsCurrentUser })
        XCTAssertTrue([friendSource].contains { !$0.containsCurrentUser })
        XCTAssertTrue([selfSource, friendSource].contains { !$0.containsCurrentUser })
    }

    @MainActor
    func testMapContentPhaseForStandardSeed() async throws {
        let viewModel = MapViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .content)
        XCTAssertTrue(viewModel.hasFriendMapContent)
    }

    @MainActor
    func testMapFailedPhaseOnRepositoryError() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = MapViewModel(
            friends: ThrowingFriendRepository(),
            groups: container.groups,
            sharing: container.sharing,
            pushes: container.pushes
        )
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .failed)
    }

    @MainActor
    func testFriendsEmptyPhaseForEmptyGraph() async throws {
        let viewModel = FriendsViewModel(container: AppDataContainer(seed: .emptyGraph()))
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .empty)
        XCTAssertEqual(viewModel.friendsCount, 0)
        XCTAssertFalse(viewModel.showsFilterChips)
    }

    @MainActor
    func testFriendsHiddenPresenceIsContentNotEmpty() async throws {
        let viewModel = FriendsViewModel(
            container: AppDataContainer(seed: .friendsWithoutPresence())
        )
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .content)
        XCTAssertFalse(viewModel.rows.isEmpty)
        XCTAssertTrue(viewModel.rows.allSatisfy { $0.friend.venueStatusText == "Hidden right now" })
    }

    @MainActor
    func testFriendsFailedPhase() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = FriendsViewModel(
            friends: ThrowingFriendRepository(),
            groups: container.groups,
            sharing: container.sharing,
            pushes: container.pushes
        )
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .failed)
    }

    @MainActor
    func testPlansEmptyWeekHidesHistoryAndUsesHonestFooter() async throws {
        let viewModel = PlansViewModel(container: AppDataContainer(seed: .emptyGraph()))
        await viewModel.load()
        XCTAssertFalse(viewModel.showsHistoryLink)
        XCTAssertFalse(viewModel.hasWeekHangoutSummary)
        XCTAssertEqual(viewModel.weekFooterPrimaryText, EmptySurfaceCopy.calendarEmptyFooter)
        XCTAssertFalse(viewModel.showsMostActiveGroup)
        XCTAssertFalse(viewModel.showsBestDay)
    }

    @MainActor
    func testStartPushEmptyPhaseWhenNoInvitees() async throws {
        let viewModel = StartPushViewModel(container: AppDataContainer(seed: .emptyGraph()))
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .empty)
        XCTAssertFalse(viewModel.hasInviteesAvailable)
        XCTAssertFalse(viewModel.canAdvanceStep1)
    }

    @MainActor
    func testStartPushContentPhaseForStandardSeed() async throws {
        let viewModel = StartPushViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .content)
        XCTAssertTrue(viewModel.hasInviteesAvailable)
        XCTAssertFalse(viewModel.friends.isEmpty)
    }
}
