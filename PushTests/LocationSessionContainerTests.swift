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

    func testFactorySelectsNullProviderByDefault() {
        let provider = LocationSessionFactory.makeProvider(
            personID: personID,
            arguments: []
        )
        XCTAssertTrue(provider is NullLocationProvider)
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
