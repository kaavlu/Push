//
//  LocationPresenceFoundationTests.swift
//  PushTests
//
//  Issue #66 — domain foundations for location / presence pipeline.
//  No GPS hardware, Supabase, Realtime, or UI automation.
//

import Combine
import XCTest
@testable import Push

final class LocationPresenceFoundationTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - LocationObservation

    func testLocationObservationValueSemantics() {
        let a = makeObservation(id: "obs-1", accuracy: 10)
        let b = makeObservation(id: "obs-1", accuracy: 10)
        let c = makeObservation(id: "obs-1", accuracy: 20)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(a.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(a.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertNil(a.altitudeMeters)
        XCTAssertEqual(a.provider, .manualTest)
    }

    func testLocationObservationUsesAppOwnedCoordinatesNotCoreLocationTypes() {
        let obs = makeObservation(id: "coord", accuracy: 5)
        // Structural: properties are Doubles (domain rule — no CLLocation in domain).
        let lat: Double = obs.latitude
        let lng: Double = obs.longitude
        let accuracy: Double = obs.horizontalAccuracyMeters
        XCTAssertTrue(lat.isFinite && lng.isFinite && accuracy.isFinite)
    }

    // MARK: - Authorization & tracking

    func testAuthorizationAllowsWhenInUseUpdates() {
        XCTAssertTrue(LocationAuthorizationState.whenInUse.allowsWhenInUseUpdates)
        XCTAssertTrue(LocationAuthorizationState.always.allowsWhenInUseUpdates)
        XCTAssertFalse(LocationAuthorizationState.notDetermined.allowsWhenInUseUpdates)
        XCTAssertFalse(LocationAuthorizationState.denied.allowsWhenInUseUpdates)
        XCTAssertFalse(LocationAuthorizationState.restricted.allowsWhenInUseUpdates)
    }

    func testTrackingStateEligibilityRequiresAuthTrackingAndPublish() {
        var state = LocationTrackingState(
            authorization: .whenInUse,
            isTrackingEnabled: true,
            isPresencePublishingEnabled: true
        )
        XCTAssertTrue(state.isEligibleToPublish)

        state.isPresencePublishingEnabled = false
        XCTAssertFalse(state.isEligibleToPublish)

        state.isPresencePublishingEnabled = true
        state.isTrackingEnabled = false
        XCTAssertFalse(state.isEligibleToPublish)

        state.isTrackingEnabled = true
        state.authorization = .denied
        XCTAssertFalse(state.isEligibleToPublish)
    }

    // MARK: - Publishing vs Ghost independence

    func testPresencePublishingIsIndependentFromAvailability() {
        let busyPublished = makeStatus(availability: .busy, isPublished: true)
        let busyGhost = makeStatus(availability: .busy, isPublished: false)
        let freeGhost = makeStatus(availability: .freeNow, isPublished: false)

        XCTAssertTrue(busyPublished.isEffectivelyPublished)
        XCTAssertEqual(busyPublished.availability, .busy)
        XCTAssertFalse(busyGhost.isEffectivelyPublished)
        XCTAssertEqual(busyGhost.availability, .busy)
        XCTAssertFalse(freeGhost.isEffectivelyPublished)
        XCTAssertEqual(freeGhost.availability, .freeNow)
    }

    func testLegacyGhostAvailabilityMapsToUnpublished() {
        // Transitional: older writers stored Ghost as availability.
        let legacy = makeStatus(availability: .ghost, isPublished: true)
        XCTAssertFalse(legacy.isEffectivelyPublished)
        XCTAssertEqual(legacy.freshnessState(at: now), .unpublished)
    }

    func testExplicitUnpublishedOverridesAvailabilityChip() {
        let status = makeStatus(availability: .freeNow, isPublished: false)
        XCTAssertFalse(status.isPublished)
        XCTAssertEqual(status.freshnessState(at: now), .unpublished)
        XCTAssertFalse(status.freshnessState(at: now).isFriendVisible)
    }

    // MARK: - Freshness classification

    func testFreshPresenceClassification() {
        let status = makeStatus(
            availability: .freeNow,
            isPublished: true,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(PresenceFreshness.hardExpire)
        )
        XCTAssertEqual(status.freshnessState(at: now), .fresh)
        XCTAssertTrue(status.freshnessState(at: now).isFriendVisible)
    }

    func testSoftStalePresenceStillFriendVisible() {
        let updatedAt = now.addingTimeInterval(-(PresenceFreshness.softStale + 60))
        let status = makeStatus(
            availability: .joinable,
            isPublished: true,
            updatedAt: updatedAt,
            expiresAt: now.addingTimeInterval(30 * 60)
        )
        XCTAssertEqual(status.freshnessState(at: now), .softStale)
        XCTAssertTrue(status.freshnessState(at: now).isFriendVisible)
    }

    func testHardExpiredPresenceNotFriendVisible() {
        let status = makeStatus(
            availability: .freeNow,
            isPublished: true,
            updatedAt: now.addingTimeInterval(-10),
            expiresAt: now.addingTimeInterval(-1)
        )
        XCTAssertEqual(status.freshnessState(at: now), .hardExpired)
        XCTAssertFalse(status.freshnessState(at: now).isFriendVisible)
    }

    func testNilExpiresAtNeverHardExpires() {
        let updatedAt = now.addingTimeInterval(-(PresenceFreshness.softStale + 1))
        let status = makeStatus(
            availability: .maybeDown,
            isPublished: true,
            updatedAt: updatedAt,
            expiresAt: nil
        )
        // Seed rows use nil expiresAt — soft-stale, not hard-expired.
        XCTAssertEqual(status.freshnessState(at: now), .softStale)
    }

    // MARK: - PresenceStatusDraft

    func testPresenceStatusDraftEqualityAndRequiredFields() {
        let activity = PresenceActivity(name: "Nearby", symbolName: "location.fill")
        let a = PresenceStatusDraft(
            availability: .freeNow,
            isPublished: true,
            activity: activity,
            placeID: "place-1",
            statusNote: "note",
            confidence: .high,
            observedAt: now,
            source: .location
        )
        let b = PresenceStatusDraft(
            availability: .freeNow,
            isPublished: true,
            activity: activity,
            placeID: "place-1",
            statusNote: "note",
            confidence: .high,
            observedAt: now,
            source: .location
        )
        let unpublished = PresenceStatusDraft(
            availability: .freeNow,
            isPublished: false,
            activity: activity,
            confidence: .high,
            observedAt: now,
            source: .location
        )

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, unpublished)
        XCTAssertEqual(a.availability, .freeNow)
        XCTAssertTrue(a.isPublished)
        XCTAssertEqual(a.source, .location)
        // Draft availability is social only — Ghost stays on isPublished.
        XCTAssertNotEqual(a.availability, .ghost)
    }

    // MARK: - Constants

    func testPhase1PipelineConstants() {
        XCTAssertEqual(LocationPipelineConstants.minUploadInterval, 60)
        XCTAssertEqual(LocationPipelineConstants.minDisplacementMeters, 50)
        XCTAssertEqual(LocationPipelineConstants.maxHorizontalAccuracyMeters, 100)
        XCTAssertEqual(LocationPipelineConstants.presenceHeartbeatIntervalDefault, 15 * 60)
        XCTAssertEqual(LocationPipelineConstants.presenceHeartbeatIntervalDogfood, 20)
        // Without `--fast-presence-heartbeat`, effective interval is production default.
        XCTAssertEqual(LocationPipelineConstants.presenceHeartbeatInterval, 15 * 60)
        XCTAssertEqual(LocationPipelineConstants.realtimePatchDebounce, 0.35, accuracy: 0.001)
        XCTAssertEqual(PresenceFreshness.softStale, 15 * 60)
        XCTAssertEqual(PresenceFreshness.hardExpire, 60 * 60)
        XCTAssertLessThan(
            LocationPipelineConstants.presenceHeartbeatIntervalDefault,
            PresenceFreshness.hardExpire
        )
    }

    func testSyncTriggerThrottleBypassMatrix() {
        XCTAssertFalse(PresenceSyncTrigger.movement.bypassesMovementThrottle)
        XCTAssertTrue(PresenceSyncTrigger.heartbeat.bypassesMovementThrottle)
        XCTAssertTrue(PresenceSyncTrigger.unpublish.bypassesMovementThrottle)
        XCTAssertTrue(PresenceSyncTrigger.republish.bypassesMovementThrottle)
        XCTAssertTrue(PresenceSyncTrigger.availabilityChange.bypassesMovementThrottle)
        XCTAssertTrue(PresenceSyncTrigger.permissionRevoked.bypassesMovementThrottle)
        XCTAssertTrue(PresenceSyncTrigger.sessionShutdown.bypassesMovementThrottle)
        XCTAssertTrue(PresenceSyncTrigger.firstEligibleStart.bypassesMovementThrottle)
        XCTAssertTrue(PresenceSyncTrigger.sharingPolicyReduced.bypassesMovementThrottle)
    }

    // MARK: - Protocol seams (fakes)

    @MainActor
    func testNullLocationProviderIsInjectable() async throws {
        let provider = NullLocationProvider()
        XCTAssertEqual(provider.authorizationState, .notDetermined)
        try await provider.startUpdating()
        XCTAssertTrue(provider.didStartUpdating)
        await provider.requestAuthorization(mode: .whenInUse)
        XCTAssertEqual(provider.authorizationState, .denied)
        provider.stopUpdating()
        XCTAssertTrue(provider.didStopUpdating)
    }

    @MainActor
    func testFakeLocationProviderEmitsObservations() async throws {
        let provider = FakeLocationProvider()
        let expectation = expectation(description: "observation")
        let stream = provider.observations

        let task = Task {
            for await obs in stream {
                XCTAssertEqual(obs.id, "emit-1")
                expectation.fulfill()
                break
            }
        }

        try await provider.startUpdating()
        provider.emit(makeObservation(id: "emit-1", accuracy: 8))
        await fulfillment(of: [expectation], timeout: 1)
        provider.stopUpdating()
        _ = await task.result
        XCTAssertEqual(provider.startCount, 1)
        XCTAssertEqual(provider.stopCount, 1)
    }

    @MainActor
    func testFakeLocationSessionShutdownIsIdempotent() async {
        let session = FakeLocationSession(
            state: LocationTrackingState(
                authorization: .whenInUse,
                isTrackingEnabled: true,
                isPresencePublishingEnabled: true
            )
        )
        await session.startIfEligible()
        XCTAssertEqual(session.startIfEligibleCount, 1)
        XCTAssertTrue(session.state.isTrackingEnabled)

        await session.setPresencePublishingEnabled(false)
        XCTAssertFalse(session.state.isEligibleToPublish)

        session.shutdown()
        session.shutdown()
        XCTAssertEqual(session.shutdownCount, 2)
        XCTAssertFalse(session.state.isTrackingEnabled)

        await session.handleLifecyclePhase(.background)
        XCTAssertEqual(session.lastLifecyclePhase, .background)
    }

    func testValidatorAndInferrerSeams() {
        let obs = makeObservation(id: "v1", accuracy: 12)
        let accepted = AcceptAllLocationValidator().accept(obs, previous: nil)
        XCTAssertEqual(accepted?.observation.id, "v1")
        XCTAssertEqual(accepted?.confidence, .high)

        XCTAssertNil(RejectAllLocationValidator().accept(obs, previous: nil))

        let draft = PassthroughPresenceInferrer().infer(
            from: [ValidatedObservation(observation: obs, confidence: .high)],
            manualAvailability: .busy,
            isPublished: true,
            previous: nil
        )
        XCTAssertEqual(draft.availability, .busy)
        XCTAssertTrue(draft.isPublished)
        XCTAssertEqual(draft.source, .location)
        XCTAssertEqual(draft.activity.name, "Nearby")
    }

    func testFakePresenceSyncRecordsUpsertsWithoutMainActor() async throws {
        let sync = FakePresenceSync()
        let draft = PresenceStatusDraft(
            availability: .freeNow,
            isPublished: true,
            activity: PresenceActivity(name: "Nearby", symbolName: "location.fill"),
            confidence: .medium,
            observedAt: now,
            source: .location
        )
        try await sync.upsertCurrentPresence(draft)
        try await sync.flushPending()
        XCTAssertEqual(sync.drafts.count, 1)
        XCTAssertEqual(sync.drafts.first?.availability, .freeNow)
        XCTAssertEqual(sync.flushCount, 1)
    }

    func testPresenceStatusDefaultIsPublishedPreservesSeedBehavior() {
        let status = PresenceStatus(
            id: "s1",
            personID: "p1",
            availability: .maybeDown,
            activity: PresenceActivity(name: "Park", symbolName: "leaf.fill"),
            placeID: "north-park",
            statusNote: nil,
            confidence: .high,
            observedAt: now,
            updatedAt: now,
            expiresAt: nil,
            source: .seed
        )
        XCTAssertTrue(status.isPublished)
        XCTAssertTrue(status.isEffectivelyPublished)
    }

    // MARK: - Helpers

    private func makeObservation(id: String, accuracy: Double) -> LocationObservation {
        LocationObservation(
            id: id,
            personID: "user-1",
            latitude: 37.7749,
            longitude: -122.4194,
            horizontalAccuracyMeters: accuracy,
            recordedAt: now,
            receivedAt: now,
            provider: .manualTest
        )
    }

    private func makeStatus(
        availability: FriendAvailabilityState,
        isPublished: Bool,
        updatedAt: Date? = nil,
        expiresAt: Date? = nil
    ) -> PresenceStatus {
        let stamp = updatedAt ?? now
        return PresenceStatus(
            id: "status-user-1",
            personID: "user-1",
            availability: availability,
            activity: PresenceActivity(name: "Coffee", symbolName: "cup.and.saucer.fill"),
            placeID: "cafe",
            statusNote: nil,
            confidence: .high,
            observedAt: stamp,
            updatedAt: stamp,
            expiresAt: expiresAt,
            source: .location,
            isPublished: isPublished
        )
    }
}
