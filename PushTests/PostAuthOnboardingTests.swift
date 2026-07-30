import XCTest
@testable import Push

@MainActor
final class PostAuthOnboardingTests: XCTestCase {
    func testPrivacyOptionMapsToSharingAndGhost() {
        XCTAssertEqual(OnboardingPrivacyOption.exactActivity.locationVisibility, .exact)
        XCTAssertEqual(OnboardingPrivacyOption.exactActivity.activityVisibility, .full)
        XCTAssertTrue(OnboardingPrivacyOption.exactActivity.isPresencePublishingEnabled)

        XCTAssertEqual(OnboardingPrivacyOption.exact.activityVisibility, .hidden)
        XCTAssertEqual(OnboardingPrivacyOption.vague.locationVisibility, .vague)
        XCTAssertFalse(OnboardingPrivacyOption.ghost.isPresencePublishingEnabled)
        XCTAssertEqual(OnboardingPrivacyOption.ghost.locationVisibility, .hidden)
    }

    func testMockDiscoverPeopleExcludesAcceptedFriends() async throws {
        let container = AppDataContainer(seed: .standard())
        let hits = try await container.friends.discoverPeople(limit: 50)
        let accepted = try await container.friends.friends()
        let acceptedIDs = Set(accepted.map(\.id))
        XCTAssertFalse(hits.contains { acceptedIDs.contains($0.id) })
        // Seed discoverable people (austin/jordan) should appear.
        XCTAssertTrue(hits.contains { $0.id == "austin" || $0.handle.contains("austin") || $0.person.firstName == "austin" })
    }

    func testLocalSetGlobalDefaultsUpdatesPolicy() async throws {
        let container = AppDataContainer(seed: .standard())
        try await container.sharing.setGlobalDefaults(
            location: .vague,
            activity: .hidden,
            availability: .full
        )
        let policies = try await container.sharing.allPolicies()
        let global = policies.first {
            $0.ownerPersonID == container.currentUserID && $0.audienceType == .globalDefault
        }
        XCTAssertEqual(global?.locationVisibility, .vague)
        XCTAssertEqual(global?.activityVisibility, .hidden)
    }

    func testMockNeverNeedsPostAuthOnboarding() async throws {
        let container = AppDataContainer(seed: .standard())
        let needs = try await container.profile.needsPostAuthOnboarding()
        XCTAssertFalse(needs)
    }

    func testContinueFromPrivacyAdvancesToLocation() async {
        let container = AppDataContainer(seed: .standard())
        let vm = PostAuthOnboardingViewModel(container: container)
        XCTAssertEqual(vm.screen, .privacy)
        vm.select(.vague)
        await vm.continueFromPrivacy()
        XCTAssertEqual(vm.screen, .location)
        XCTAssertNil(vm.errorMessage)
    }

    func testSkipLocationAdvancesToNotifications() {
        let container = AppDataContainer(seed: .standard())
        let vm = PostAuthOnboardingViewModel(container: container)
        vm.skipLocation()
        XCTAssertEqual(vm.screen, .notifications)
    }

    func testFinishOnboardingReachesDone() async {
        let container = AppDataContainer(seed: .standard())
        let session = FakeLocationSession(
            state: LocationTrackingState(authorization: .whenInUse)
        )
        let vm = PostAuthOnboardingViewModel(
            container: container,
            locationSession: session
        )
        await vm.continueFromPrivacy()
        vm.skipLocation()
        await vm.skipNotifications()
        XCTAssertEqual(vm.screen, .friends)
        await vm.continueFromFriends()
        XCTAssertEqual(vm.screen, .done)
        vm.openApp()
        XCTAssertTrue(vm.isFinished)
    }

    func testFinishOnboardingBlockedWithoutLocationAuthorization() async {
        let container = AppDataContainer(seed: .standard())
        let deniedSession = FakeLocationSession(
            state: LocationTrackingState(authorization: .denied)
        )
        let vm = PostAuthOnboardingViewModel(
            container: container,
            locationSession: deniedSession
        )
        await vm.continueFromFriends()
        XCTAssertNotEqual(vm.screen, .done)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testFinishOnboardingSucceedsWhenLocationAuthorized() async {
        let container = AppDataContainer(seed: .standard())
        let authorizedSession = FakeLocationSession(
            state: LocationTrackingState(authorization: .whenInUse)
        )
        let vm = PostAuthOnboardingViewModel(
            container: container,
            locationSession: authorizedSession
        )
        await vm.continueFromFriends()
        XCTAssertEqual(vm.screen, .done)
        XCTAssertNil(vm.errorMessage)
    }
}
