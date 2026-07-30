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
        XCTAssertEqual(PostAuthOnboardingScreen.progressTotal, 5)
        XCTAssertEqual(PostAuthOnboardingScreen.locationPrimer.progressStep, 1)
        XCTAssertFalse(PostAuthOnboardingScreen.locationPrimer.showsBackButton)
        XCTAssertEqual(PostAuthOnboardingScreen.locationBlocked.progressStep, 1)
        XCTAssertFalse(PostAuthOnboardingScreen.locationBlocked.showsBackButton)
        XCTAssertEqual(PostAuthOnboardingScreen.ghost.progressStep, 2)
        XCTAssertTrue(PostAuthOnboardingScreen.ghost.showsBackButton)
        XCTAssertEqual(PostAuthOnboardingScreen.coordinate.progressStep, 3)
        XCTAssertEqual(PostAuthOnboardingScreen.notifications.progressStep, 4)
        XCTAssertEqual(PostAuthOnboardingScreen.findPeople.progressStep, 5)
        XCTAssertEqual(PostAuthOnboardingScreen.done.progressStep, 0)
        XCTAssertFalse(PostAuthOnboardingScreen.done.showsBackButton)
    }

    func testHappyPathOrderWithLocationAllow() async {
        let vm = makeVM(auth: .whenInUse)
        XCTAssertEqual(vm.screen, .locationPrimer)
        await vm.enableLocation()
        XCTAssertEqual(vm.screen, .ghost)
        vm.continueFromGhost()
        XCTAssertEqual(vm.screen, .coordinate)
        vm.continueFromCoordinate()
        XCTAssertEqual(vm.screen, .notifications)
        await vm.skipNotifications()
        XCTAssertEqual(vm.screen, .findPeople)
        await vm.loadFindPeopleDirectoryIfNeeded()
        await vm.continueFromFindPeople()
        XCTAssertEqual(vm.screen, .done)
    }

    func testFindPeopleLoadRequestsContactsOnce() async {
        let contacts = FixedContactsProvider(grantAccess: false, hints: [])
        let vm = makeVM(auth: .whenInUse, contacts: contacts)
        await vm.skipNotifications()
        XCTAssertEqual(vm.screen, .findPeople)
        await vm.loadFindPeopleDirectoryIfNeeded()
        XCTAssertEqual(contacts.requestAccessCount, 1)
        await vm.loadFindPeopleDirectoryIfNeeded()
        XCTAssertEqual(contacts.requestAccessCount, 1)
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

    /// Primer appear / puck preview must never request OS location authorization.
    func testPrimerLoadDoesNotStartLocationUntilEnable() async {
        let session = FakeLocationSession(
            state: LocationTrackingState(authorization: .notDetermined)
        )
        let vm = PostAuthOnboardingViewModel(
            container: AppDataContainer(seed: .standard()),
            locationSession: session
        )
        XCTAssertEqual(vm.screen, .locationPrimer)
        XCTAssertEqual(session.startIfEligibleCount, 0)

        await vm.loadSelfPuckPreview()
        XCTAssertNotNil(vm.selfPuck)
        XCTAssertEqual(session.startIfEligibleCount, 0)

        // Only the Enable CTA path may request authorization.
        await vm.enableLocation()
        XCTAssertEqual(session.startIfEligibleCount, 1)
    }

    func testSkipNotificationsGoesToFindPeopleWithoutBlocking() async {
        let vm = makeVM(auth: .whenInUse)
        await vm.enableLocation()
        vm.continueFromGhost()
        vm.continueFromCoordinate()
        XCTAssertEqual(vm.screen, .notifications)
        await vm.skipNotifications()
        XCTAssertEqual(vm.screen, .findPeople)
    }

    func testRetryLocationAccessIncrementsStartIfEligible() async {
        let session = FakeLocationSession(
            state: LocationTrackingState(authorization: .denied)
        )
        let vm = PostAuthOnboardingViewModel(
            container: AppDataContainer(seed: .standard()),
            locationSession: session
        )
        await vm.enableLocation()
        XCTAssertEqual(session.startIfEligibleCount, 1)
        XCTAssertEqual(vm.screen, .locationBlocked)

        session.setAuthorization(.whenInUse)
        await vm.retryLocationAccess()
        XCTAssertEqual(session.startIfEligibleCount, 2)
        XCTAssertEqual(vm.screen, .ghost)
    }

    func testGoBackStack() async {
        let vm = makeVM(auth: .whenInUse)
        await vm.enableLocation()
        XCTAssertEqual(vm.screen, .ghost)
        vm.continueFromGhost()
        vm.continueFromCoordinate()
        await vm.skipNotifications()
        XCTAssertEqual(vm.screen, .findPeople)

        vm.goBack()
        XCTAssertEqual(vm.screen, .notifications)
        XCTAssertTrue(vm.hasFullyRevealed(.notifications))
        vm.goBack()
        XCTAssertEqual(vm.screen, .coordinate)
        XCTAssertTrue(vm.hasFullyRevealed(.coordinate))
        vm.goBack()
        XCTAssertEqual(vm.screen, .ghost)
        XCTAssertTrue(vm.hasFullyRevealed(.ghost))
        vm.goBack()
        XCTAssertEqual(vm.screen, .locationPrimer)
        XCTAssertTrue(vm.hasFullyRevealed(.locationPrimer))
        // First screen — no further back.
        vm.goBack()
        XCTAssertEqual(vm.screen, .locationPrimer)
    }

    func testGoBackMarksDestinationFullyRevealed() async {
        let vm = makeVM(auth: .whenInUse)
        await vm.enableLocation()
        // First visit to ghost has not finished cascade yet in unit test.
        XCTAssertFalse(vm.hasFullyRevealed(.locationPrimer))
        vm.goBack()
        // Back from ghost → primer is marked fully revealed for instant layout.
        XCTAssertEqual(vm.screen, .locationPrimer)
        XCTAssertTrue(vm.hasFullyRevealed(.locationPrimer))
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

    private func makeVM(
        auth: LocationAuthorizationState,
        contacts: ContactsProviding? = nil
    ) -> PostAuthOnboardingViewModel {
        let container = AppDataContainer(seed: .standard())
        let session = FakeLocationSession(
            state: LocationTrackingState(authorization: auth)
        )
        return PostAuthOnboardingViewModel(
            container: container,
            locationSession: session,
            contacts: contacts ?? NullContactsProvider()
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
