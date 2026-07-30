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

    func testProgressAndBackChrome() {
        XCTAssertEqual(PostAuthOnboardingScreen.progressTotal, 7)
        XCTAssertEqual(PostAuthOnboardingScreen.value.progressStep, 1)
        XCTAssertFalse(PostAuthOnboardingScreen.value.showsBackButton)
        XCTAssertEqual(PostAuthOnboardingScreen.locationPrimer.progressStep, 2)
        XCTAssertTrue(PostAuthOnboardingScreen.locationPrimer.showsBackButton)
        XCTAssertEqual(PostAuthOnboardingScreen.locationBlocked.progressStep, 2)
        XCTAssertFalse(PostAuthOnboardingScreen.locationBlocked.showsBackButton)
        XCTAssertEqual(PostAuthOnboardingScreen.findPeople.progressStep, 7)
        XCTAssertEqual(PostAuthOnboardingScreen.done.progressStep, 0)
        XCTAssertFalse(PostAuthOnboardingScreen.done.showsBackButton)
    }

    func testHappyPathOrderWithLocationAllow() async {
        let vm = makeVM(auth: .whenInUse)
        XCTAssertEqual(vm.screen, .value)
        vm.continueFromValue()
        XCTAssertEqual(vm.screen, .locationPrimer)
        await vm.enableLocation()
        XCTAssertEqual(vm.screen, .ghost)
        vm.continueFromGhost()
        XCTAssertEqual(vm.screen, .coordinate)
        vm.continueFromCoordinate()
        XCTAssertEqual(vm.screen, .notifications)
        await vm.skipNotifications()
        XCTAssertEqual(vm.screen, .contacts)
        await vm.skipContacts()
        XCTAssertEqual(vm.screen, .findPeople)
        await vm.continueFromFindPeople()
        XCTAssertEqual(vm.screen, .done)
    }

    func testEnableLocationAllowAppliesDefaultsAndAdvances() async throws {
        let container = AppDataContainer(seed: .standard())
        let session = FakeLocationSession(
            state: LocationTrackingState(authorization: .whenInUse)
        )
        let vm = PostAuthOnboardingViewModel(
            container: container,
            locationSession: session
        )
        vm.continueFromValue()
        await vm.enableLocation()
        XCTAssertEqual(vm.screen, .ghost)
        XCTAssertEqual(session.startIfEligibleCount, 1)
        XCTAssertTrue(session.state.isPresencePublishingEnabled)

        let policies = try await container.sharing.allPolicies()
        let global = policies.first {
            $0.audienceType == .globalDefault && $0.ownerPersonID == container.currentUserID
        }
        XCTAssertEqual(global?.locationVisibility, .exact)
        XCTAssertEqual(global?.activityVisibility, .full)
        XCTAssertEqual(global?.availabilityVisibility, .full)
    }

    func testEnableLocationDeniedGoesToBlocked() async {
        let vm = makeVM(auth: .denied)
        vm.continueFromValue()
        await vm.enableLocation()
        XCTAssertEqual(vm.screen, .locationBlocked)
        XCTAssertFalse(vm.screen.showsBackButton)
    }

    func testRetryLocationAccessAfterAllowAdvances() async {
        let session = FakeLocationSession(
            state: LocationTrackingState(authorization: .denied)
        )
        let container = AppDataContainer(seed: .standard())
        let vm = PostAuthOnboardingViewModel(
            container: container,
            locationSession: session
        )
        vm.continueFromValue()
        await vm.enableLocation()
        XCTAssertEqual(vm.screen, .locationBlocked)

        session.setAuthorization(.whenInUse)
        await vm.retryLocationAccess()
        XCTAssertEqual(vm.screen, .ghost)
    }

    func testOpenSystemSettingsDelegatesToOpener() {
        let opener = FakeSettingsOpener()
        let vm = PostAuthOnboardingViewModel(
            container: AppDataContainer(seed: .standard()),
            locationSession: FakeLocationSession(
                state: LocationTrackingState(authorization: .denied)
            ),
            settingsOpener: opener
        )
        vm.openSystemSettings()
        XCTAssertEqual(opener.openCount, 1)
    }

    func testLoadSelfPuckPreviewUsesCurrentUserAtSFCenter() async throws {
        let container = AppDataContainer(seed: .standard())
        let vm = PostAuthOnboardingViewModel(
            container: container,
            locationSession: FakeLocationSession(
                state: LocationTrackingState(authorization: .whenInUse)
            )
        )
        await vm.loadSelfPuckPreview()
        let user = try await container.friends.currentUser()
        let puck = try XCTUnwrap(vm.selfPuck)
        XCTAssertEqual(puck.id, user.id)
        XCTAssertEqual(puck.avatarPlaceholder, user.initials)
        XCTAssertEqual(puck.profileImageAssetName, user.imageAssetPath)
        XCTAssertEqual(puck.coordinate.latitude, OnboardingMapDefaults.latitude, accuracy: 0.0001)
        XCTAssertEqual(puck.coordinate.longitude, OnboardingMapDefaults.longitude, accuracy: 0.0001)
        // Idempotent — second load should not replace.
        await vm.loadSelfPuckPreview()
        XCTAssertEqual(vm.selfPuck?.id, user.id)
    }

    func testGoBackStack() async {
        let vm = makeVM(auth: .whenInUse)
        vm.continueFromValue()
        await vm.enableLocation()
        XCTAssertEqual(vm.screen, .ghost)
        vm.continueFromGhost()
        vm.continueFromCoordinate()
        await vm.skipNotifications()
        await vm.skipContacts()
        XCTAssertEqual(vm.screen, .findPeople)

        vm.goBack()
        XCTAssertEqual(vm.screen, .contacts)
        vm.goBack()
        XCTAssertEqual(vm.screen, .notifications)
        vm.goBack()
        XCTAssertEqual(vm.screen, .coordinate)
        vm.goBack()
        XCTAssertEqual(vm.screen, .ghost)
        vm.goBack()
        XCTAssertEqual(vm.screen, .locationPrimer)
        vm.goBack()
        XCTAssertEqual(vm.screen, .value)
        vm.goBack()
        XCTAssertEqual(vm.screen, .value)
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
        await vm.continueFromFindPeople()
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
        await vm.continueFromFindPeople()
        XCTAssertEqual(vm.screen, .done)
        XCTAssertNil(vm.errorMessage)
        vm.openApp()
        XCTAssertTrue(vm.isFinished)
    }

    // MARK: - Helpers

    private func makeVM(auth: LocationAuthorizationState) -> PostAuthOnboardingViewModel {
        let container = AppDataContainer(seed: .standard())
        let session = FakeLocationSession(
            state: LocationTrackingState(authorization: auth)
        )
        return PostAuthOnboardingViewModel(
            container: container,
            locationSession: session
        )
    }
}

// MARK: - Test doubles

@MainActor
private final class FakeSettingsOpener: SettingsOpening {
    private(set) var openCount = 0

    func openAppSettings() {
        openCount += 1
    }
}
