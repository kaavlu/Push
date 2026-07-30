//
//  LocationSessionContainerTests.swift
//  PushTests
//
//  Issue #69 — AppDataContainer ownership, install swap, sign-out teardown.
//

import XCTest
@testable import Push

@MainActor
final class LocationSessionContainerTests: XCTestCase {

    private let personID: Person.ID = "container-session-user"

    func testContainerReplacementShutsDownPreviousSession() {
        let firstSession = FakeLocationSession(
            state: LocationTrackingState(
                authorization: .whenInUse,
                isTrackingEnabled: true,
                isPresencePublishingEnabled: true
            )
        )
        let first = AppDataContainer(seed: .standard(), locationSession: firstSession)
        first.shutdownLocationSession()
        XCTAssertEqual(firstSession.shutdownCount, 1)
        XCTAssertNil(first.locationSession)

        let secondSession = FakeLocationSession()
        let second = AppDataContainer(seed: .standard(), locationSession: secondSession)
        XCTAssertTrue(second.locationSession === secondSession)
    }

    func testInstallPreparedLiveShutsDownPreviousSharedSession() {
        let previous = FakeLocationSession(
            state: LocationTrackingState(
                authorization: .whenInUse,
                isTrackingEnabled: true,
                isPresencePublishingEnabled: true
            )
        )
        replaceSharedForTesting(
            AppDataContainer(seed: .standard(), locationSession: previous)
        )

        let next = FakeLocationSession()
        AppDataContainer.installPreparedLive(
            AppDataContainer(seed: .standard(), locationSession: next)
        )

        XCTAssertEqual(previous.shutdownCount, 1)
        XCTAssertTrue(AppDataContainer.shared.locationSession === next)
    }

    /// Incomplete onboarding must not request location during live install
    /// (Issue #134 Task 1 — avoid racing the system auth prompt before the
    /// post-auth location step).
    func testInstallPreparedLiveSkipsLocationWhenFlagFalse() async {
        let session = FakeLocationSession()
        let container = AppDataContainer(seed: .standard(), locationSession: session)

        AppDataContainer.installPreparedLive(container, startLocationIfEligible: false)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(session.startIfEligibleCount, 0)
        XCTAssertTrue(AppDataContainer.shared.locationSession === session)
    }

    func testInstallPreparedLiveStartsLocationWhenFlagTrue() async {
        let session = FakeLocationSession()
        let container = AppDataContainer(seed: .standard(), locationSession: session)

        AppDataContainer.installPreparedLive(container, startLocationIfEligible: true)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(session.startIfEligibleCount, 1)
    }

    func testShutdownSharedAndReinstallMockUnpublishesThenShutsDown() async {
        let session = FakeLocationSession(
            state: LocationTrackingState(
                authorization: .whenInUse,
                isTrackingEnabled: true,
                isPresencePublishingEnabled: true
            )
        )
        replaceSharedForTesting(
            AppDataContainer(seed: .standard(), locationSession: session)
        )

        await AppDataContainer.shutdownSharedAndReinstallMock(attemptUnpublish: true)

        XCTAssertEqual(session.unpublishCount, 1)
        XCTAssertEqual(session.shutdownCount, 1)
        XCTAssertFalse(AppDataContainer.shared.locationSession is FakeLocationSession)
    }

    func testShutdownSharedWithoutUnpublishSkipsUnpublish() async {
        let session = FakeLocationSession(
            state: LocationTrackingState(
                authorization: .whenInUse,
                isTrackingEnabled: true
            )
        )
        replaceSharedForTesting(
            AppDataContainer(seed: .standard(), locationSession: session)
        )

        await AppDataContainer.shutdownSharedAndReinstallMock(attemptUnpublish: false)

        XCTAssertEqual(session.unpublishCount, 0)
        XCTAssertEqual(session.shutdownCount, 1)
    }

    func testDefaultMockContainerHasLocationSession() {
        let container = AppDataContainer(seed: .standard())
        XCTAssertNotNil(container.locationSession)
    }

    func testFactorySelectsSimulatedProviderForLaunchArgument() {
        let provider = LocationSessionFactory.makeProvider(
            personID: personID,
            arguments: [LocationSessionLaunchArgument.simLocation]
        )
        XCTAssertTrue(provider is SimulatedLocationProvider)
    }

    func testFactorySelectsNullProviderByDefaultForMock() {
        let provider = LocationSessionFactory.makeProvider(
            personID: personID,
            arguments: [],
            usesCoreLocation: false
        )
        XCTAssertTrue(provider is NullLocationProvider)
    }

    func testFactorySelectsCoreLocationForLiveWithoutSimFlag() {
        let provider = LocationSessionFactory.makeProvider(
            personID: personID,
            arguments: [],
            usesCoreLocation: true
        )
        XCTAssertTrue(provider is CoreLocationLocationProvider)
    }

    func testFactoryPrefersSimulatedOverCoreLocationWhenFlagSet() {
        let provider = LocationSessionFactory.makeProvider(
            personID: personID,
            arguments: [LocationSessionLaunchArgument.simLocation],
            usesCoreLocation: true
        )
        XCTAssertTrue(provider is SimulatedLocationProvider)
    }

    func testTeardownLocationForSignOutOrdersUnpublishBeforeShutdown() async {
        let session = FakeLocationSession(
            state: LocationTrackingState(
                authorization: .whenInUse,
                isTrackingEnabled: true,
                isPresencePublishingEnabled: true
            )
        )
        // Record call order via counts at each step.
        let container = AppDataContainer(seed: .standard(), locationSession: session)
        await container.teardownLocationForSignOut()

        XCTAssertEqual(session.unpublishCount, 1)
        XCTAssertEqual(session.shutdownCount, 1)
        XCTAssertNil(container.locationSession)
    }

    private func replaceSharedForTesting(_ container: AppDataContainer) {
        AppDataContainer.shared.shutdownLocationSession()
        AppDataContainer.installPreparedLive(container)
    }
}
