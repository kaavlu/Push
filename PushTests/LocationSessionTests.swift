//
//  LocationSessionTests.swift
//  PushTests
//
//  Issue #69 — LocationSession orchestration, eligibility, shutdown, container wiring.
//  No Core Location, Supabase schema, permission UI, or map changes.
//

import Combine
import XCTest
@testable import Push

@MainActor
final class LocationSessionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let personID: Person.ID = "session-user"

    // MARK: - Eligibility

    func testStartsWhenEligible() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let session = makeSession(provider: provider)

        await session.startIfEligible()

        XCTAssertTrue(session.state.isTrackingEnabled)
        XCTAssertEqual(provider.startCount, 1)
        XCTAssertTrue(session.state.isEligibleToPublish)
    }

    func testDoesNotStartWhenAuthorizationDenied() async {
        let provider = FakeLocationProvider(authorizationState: .denied)
        let session = makeSession(provider: provider)

        await session.startIfEligible()

        XCTAssertFalse(session.state.isTrackingEnabled)
        XCTAssertEqual(provider.startCount, 0)
        XCTAssertEqual(provider.requestAuthorizationCount, 0)
    }

    func testRequestsAuthorizationWhenNotDeterminedThenStarts() async {
        let provider = FakeLocationProvider(authorizationState: .notDetermined)
        let session = makeSession(provider: provider)

        await session.startIfEligible()

        XCTAssertEqual(provider.requestAuthorizationCount, 1)
        XCTAssertEqual(provider.authorizationState, .whenInUse)
        XCTAssertEqual(provider.startCount, 1)
        XCTAssertTrue(session.state.isTrackingEnabled)
    }

    func testAuthorizationRevokeUnpublishesOnlyAfterPreviouslyGranted() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync)

        await session.startIfEligible()
        XCTAssertEqual(provider.startCount, 1)

        provider.setAuthorization(.denied)
        await session.handleAuthorizationStateChanged()

        XCTAssertEqual(sync.unpublishCount, 1)
        XCTAssertEqual(provider.stopCount, 1)
        XCTAssertFalse(session.state.isTrackingEnabled)
    }

    func testInitialNotDeterminedAuthChangeDoesNotUnpublish() async {
        let provider = FakeLocationProvider(authorizationState: .notDetermined)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync)

        await session.handleAuthorizationStateChanged()

        XCTAssertEqual(sync.unpublishCount, 0)
        XCTAssertEqual(provider.startCount, 0)
    }

    func testDoesNotStartWhenPublishingDisabled() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let session = makeSession(
            provider: provider,
            isPresencePublishingEnabled: false
        )

        await session.startIfEligible()

        XCTAssertEqual(provider.startCount, 0)
        XCTAssertFalse(session.state.isEligibleToPublish)
    }

    func testDoesNotStartAfterShutdown() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let session = makeSession(provider: provider)
        session.shutdown()

        await session.startIfEligible()

        XCTAssertEqual(provider.startCount, 0)
        XCTAssertFalse(session.state.isTrackingEnabled)
    }

    func testDoesNotCreateDuplicateConsumptionTasks() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let session = makeSession(provider: provider)

        await session.startIfEligible()
        await session.startIfEligible()
        await session.startIfEligible()

        XCTAssertEqual(provider.startCount, 1)
    }

    // MARK: - Observation pipeline

    func testAcceptedObservationReachesInferrerAndSync() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            sync: sync
        )

        await session.startIfEligible()
        // Let the observation task attach to the stream.
        await Task.yield()

        provider.emit(makeObservation(id: "ok-1"))
        // Wait for sync + MainActor state write-through (not just draft append).
        await waitUntil(timeout: 1) {
            sync.drafts.count == 1 && session.state.lastUploadAt != nil
        }

        XCTAssertEqual(sync.drafts.count, 1)
        XCTAssertEqual(sync.drafts.first?.source, .location)
        XCTAssertTrue(sync.drafts.first?.isPublished == true)
        XCTAssertEqual(session.state.lastObservation?.id, "ok-1")
        XCTAssertNotNil(session.state.lastAcceptedAt)
        XCTAssertNotNil(session.state.lastUploadAt)
    }

    func testRejectedObservationsDoNotReachSync() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            validator: RejectAllLocationValidator(),
            sync: sync
        )

        await session.startIfEligible()
        await Task.yield()

        provider.emit(makeObservation(id: "bad-1"))
        // Give the pipeline a beat; drafts must stay empty.
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(sync.drafts.isEmpty)
        XCTAssertNil(session.state.lastObservation)
        XCTAssertNil(session.state.lastAcceptedAt)
    }

    func testStopPreventsFurtherProcessing() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            sync: sync
        )

        await session.startIfEligible()
        await Task.yield()
        provider.emit(makeObservation(id: "before-stop"))
        await waitUntil(timeout: 1) {
            sync.drafts.count == 1 && session.state.lastUploadAt != nil
        }

        session.stop()
        provider.emit(makeObservation(id: "after-stop"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(sync.drafts.count, 1)
        XCTAssertEqual(session.state.lastObservation?.id, "before-stop")
        XCTAssertFalse(session.state.isTrackingEnabled)
        XCTAssertEqual(provider.stopCount, 1)
    }

    func testRepeatedStartStopIsSafe() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            sync: sync
        )

        await session.startIfEligible()
        await Task.yield()
        session.stop()
        await session.startIfEligible()
        await Task.yield()
        provider.emit(makeObservation(id: "after-restart"))
        await waitUntil(timeout: 1) {
            sync.drafts.count == 1 && session.state.lastUploadAt != nil
        }

        XCTAssertEqual(provider.startCount, 2)
        XCTAssertEqual(sync.drafts.count, 1)
        XCTAssertEqual(session.state.lastObservation?.id, "after-restart")
    }

    // MARK: - Shutdown

    func testShutdownPreventsFutureProcessing() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            sync: sync
        )

        await session.startIfEligible()
        await Task.yield()
        session.shutdown()

        provider.emit(makeObservation(id: "after-shutdown"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(sync.drafts.isEmpty)
        XCTAssertNil(session.state.lastObservation)
        XCTAssertFalse(session.state.isTrackingEnabled)
    }

    func testShutdownIsIdempotent() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let session = makeSession(provider: provider)

        await session.startIfEligible()
        session.shutdown()
        session.shutdown()
        session.shutdown()

        await session.startIfEligible()
        XCTAssertEqual(provider.startCount, 1, "start after shutdown must be a no-op")
        XCTAssertFalse(session.state.isTrackingEnabled)
    }

    func testUnpublishBestEffortInvokesSync() async {
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: FakeLocationProvider(authorizationState: .whenInUse),
            sync: sync
        )

        await session.unpublishBestEffort()

        XCTAssertEqual(sync.unpublishCount, 1)
    }

    func testUnpublishFailureDoesNotThrowAndRecordsCode() async {
        let sync = FakePresenceSync()
        sync.unpublishErrorToThrow = URLError(.notConnectedToInternet)
        let session = makeSession(
            provider: FakeLocationProvider(authorizationState: .whenInUse),
            sync: sync
        )

        await session.unpublishBestEffort()

        XCTAssertEqual(session.state.lastErrorCode, LocationSessionErrorCode.unpublishFailed)
    }

    // MARK: - Simulated provider end-to-end

    func testSimulatedProviderDrivesFullPipeline() async {
        let route = SimulatedLocationRouteFixtures.stationary(
            personID: personID,
            baseDate: now
        )
        let provider = SimulatedLocationProvider(
            route: route,
            authorizationState: .whenInUse,
            mode: .manual
        )
        let sync = FakePresenceSync()
        // Accept-all avoids clock skew between fixture dates and wall clock.
        let session = makeSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            sync: sync
        )

        await session.startIfEligible()
        await Task.yield()

        XCTAssertTrue(provider.advance())
        await waitUntil(timeout: 1) {
            sync.drafts.count >= 1 && session.state.lastUploadAt != nil
        }

        XCTAssertFalse(sync.drafts.isEmpty)
        XCTAssertEqual(session.state.lastObservation?.provider, .simulated)
        XCTAssertNotNil(session.state.lastUploadAt)
    }

    func testNoUpsertsAfterSessionShutdown() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            sync: sync
        )

        await session.startIfEligible()
        await Task.yield()
        session.shutdown()
        provider.emit(makeObservation(id: "late"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(sync.drafts.isEmpty)
    }

    // MARK: - Helpers

    private func makeSession(
        provider: LocationProviding,
        validator: LocationObservationValidating = AcceptAllLocationValidator(),
        sync: PresenceSyncing = FakePresenceSync(),
        isPresencePublishingEnabled: Bool = true
    ) -> LocationSession {
        LocationSession(
            provider: provider,
            validator: validator,
            inferrer: PassthroughPresenceInferrer(),
            sync: sync,
            availabilityProvider: { .freeNow },
            isPresencePublishingEnabled: isPresencePublishingEnabled,
            isTrackingDesired: true,
            now: { self.now }
        )
    }

    private func makeObservation(id: String) -> LocationObservation {
        LocationObservation(
            id: id,
            personID: personID,
            latitude: 37.7749,
            longitude: -122.4194,
            horizontalAccuracyMeters: 10,
            recordedAt: now,
            receivedAt: now,
            provider: .manualTest
        )
    }

    private func waitUntil(
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line,
        predicate: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Condition not met within \(timeout)s", file: file, line: line)
    }
}
