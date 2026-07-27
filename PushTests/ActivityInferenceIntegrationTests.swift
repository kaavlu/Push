//
//  ActivityInferenceIntegrationTests.swift
//  PushTests
//
//  Issue #94 (I3) — activity inference wired through LocationSession → draft →
//  presence mapping / LiveDataStore remote apply. No real network or GPS.
//

import XCTest
@testable import Push

@MainActor
final class ActivityInferenceIntegrationTests: XCTestCase {

    private let personID: Person.ID = "activity-session-user"
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Publishing with inferred activity

    func testClassifiedActivityPublishedOnDraft() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let engine = FixedActivityInferenceEngine(
            result: InferredActivityResult(
                kind: .walking,
                inferredAt: base,
                confidence: .high,
                validUntil: base.addingTimeInterval(600)
            )
        )
        let session = makeSession(
            provider: provider,
            sync: sync,
            clock: clock,
            activityEngine: engine
        )

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "w0", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 && session.state.lastUploadAt != nil }

        XCTAssertEqual(sync.drafts.first?.activity.name, "Walking")
        XCTAssertEqual(sync.drafts.first?.activity.symbolName, "figure.walk")
        XCTAssertEqual(sync.drafts.first?.source, .inference)
        XCTAssertEqual(sync.drafts.first?.confidence, .high)
        XCTAssertEqual(sync.drafts.first?.availability, .freeNow)
        XCTAssertTrue(sync.drafts.first?.isPublished == true)
        XCTAssertEqual(session.lastValidInferredActivityForTesting?.kind, .walking)
    }

    func testDeterministicEngineWalkingOnSustainedMovementPublish() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            sync: sync,
            clock: clock,
            activityEngine: DeterministicActivityInferenceEngine()
        )

        await session.startIfEligible()
        await Task.yield()

        let walk = ActivityInferenceFixtures.walkingSequence(
            personID: personID,
            baseDate: base
        )
        // First point publishes immediately (insufficient window → Nearby).
        await emitAndWait(provider: provider, session: session, observation: walk[0])
        await waitUntil { sync.drafts.count == 1 }

        // Grow the inference window (throttled — no extra drafts yet).
        for observation in walk.dropFirst() {
            clock.now = observation.recordedAt
            await emitAndWait(provider: provider, session: session, observation: observation)
        }
        XCTAssertEqual(session.recentActivityObservationsForTesting.count, walk.count)

        // Movement publish after 60s + ≥50m.
        clock.now = walk.last!.recordedAt.addingTimeInterval(90)
        let far = observation(
            id: "walk-far",
            lat: walk.last!.latitude + 0.001,
            lng: walk.last!.longitude,
            at: clock.now,
            speed: 1.4
        )
        await emitAndWait(provider: provider, session: session, observation: far)
        await waitUntil { sync.drafts.count >= 2 }

        let published = sync.drafts.last
        XCTAssertEqual(published?.activity.name, "Walking")
        XCTAssertEqual(published?.source, .inference)
        XCTAssertEqual(session.lastValidInferredActivityForTesting?.kind, .walking)
    }

    func testUnknownEngineStillPublishesLocation() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            sync: sync,
            clock: clock,
            activityEngine: UnknownActivityInferenceEngine()
        )

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "u1", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 && session.state.lastUploadAt != nil }

        XCTAssertEqual(sync.drafts.count, 1)
        XCTAssertEqual(sync.drafts.first?.activity, .nearby)
        XCTAssertEqual(sync.drafts.first?.source, .location)
        XCTAssertEqual(sync.drafts.first?.latitude, 37.77)
        XCTAssertTrue(sync.drafts.first?.isPublished == true)
    }

    // MARK: - Heartbeat preserves activity

    func testHeartbeatPreservesLatestValidActivity() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let walkingResult = InferredActivityResult(
            kind: .walking,
            inferredAt: base,
            confidence: .medium,
            validUntil: base.addingTimeInterval(3_600)
        )
        let drivingResult = InferredActivityResult(
            kind: .driving,
            inferredAt: base,
            confidence: .medium,
            validUntil: base.addingTimeInterval(3_600)
        )
        // If heartbeat re-inferred instead of preserving, draft would flip to Driving.
        let engine = SwitchingActivityInferenceEngine(
            first: walkingResult,
            subsequent: drivingResult
        )
        let session = makeSession(
            provider: provider,
            sync: sync,
            clock: clock,
            activityEngine: engine
        )

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "hb0", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 && session.state.lastUploadAt != nil }
        XCTAssertEqual(sync.drafts.first?.activity.name, "Walking")
        XCTAssertEqual(session.lastValidInferredActivityForTesting?.kind, .walking)

        clock.now = clock.now.addingTimeInterval(
            LocationPipelineConstants.presenceHeartbeatInterval
        )
        session.checkHeartbeatDueForTesting()
        await waitUntil { sync.drafts.count == 2 }

        XCTAssertEqual(sync.drafts.last?.activity.name, "Walking")
        XCTAssertEqual(sync.drafts.last?.activity.symbolName, "figure.walk")
        XCTAssertEqual(sync.drafts.last?.availability, .freeNow)
        // Heartbeat path must not require a fresh classified inference.
        XCTAssertGreaterThanOrEqual(engine.inferCallCount, 1)
    }

    // MARK: - Ghost

    func testGhostDoesNotPublishAndLeavesAvailabilityUnchangedOnRepublish() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(
            provider: provider,
            sync: sync,
            clock: clock,
            availability: .busy
        )

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "g0", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 }
        XCTAssertEqual(sync.drafts.first?.availability, .busy)

        await session.setPresencePublishingEnabled(false)
        XCTAssertEqual(sync.unpublishCount, 1)

        clock.now = clock.now.addingTimeInterval(30)
        provider.emit(observation(id: "g1", lat: 37.771, lng: -122.42, at: clock.now))
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(sync.drafts.count, 1, "Ghost must not publish")

        await session.setPresencePublishingEnabled(true)
        await waitUntil { sync.drafts.count >= 2 }
        XCTAssertEqual(sync.drafts.last?.availability, .busy)
        XCTAssertTrue(sync.drafts.last?.isPublished == true)
    }

    // MARK: - Teardown

    func testShutdownClearsActivityStateAndStopsPublishing() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync, clock: clock)

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "t0", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 }
        XCTAssertFalse(session.recentActivityObservationsForTesting.isEmpty)

        session.shutdown()
        XCTAssertTrue(session.recentActivityObservationsForTesting.isEmpty)
        XCTAssertNil(session.lastValidInferredActivityForTesting)

        provider.emit(observation(id: "t1", lat: 37.78, lng: -122.42, at: clock.now))
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(sync.drafts.count, 1)
    }

    // MARK: - Remote activity patches LiveDataStore

    func testRemoteActivityUpdatePatchesLiveDataStore() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceOwnerUserID = "self"
        loader.presenceRows = [
            CurrentPresenceRow.fixture(
                userID: "friend",
                activityName: "Nearby",
                activitySymbol: "location.fill",
                lat: 37.77,
                lng: -122.42,
                updatedAt: "2030-01-01T12:00:00Z"
            ),
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()

        let updated = CurrentPresenceRow.fixture(
            userID: "friend",
            activityName: "Walking",
            activitySymbol: "figure.walk",
            lat: 37.771,
            lng: -122.42,
            updatedAt: "2030-01-01T12:05:00Z",
            source: "inference"
        )
        XCTAssertTrue(store.applyRemotePresenceRow(updated))

        let rows = try await store.currentPresence()
        let row = rows.first { $0.user_id == "friend" }
        XCTAssertEqual(row?.activity_name, "Walking")
        XCTAssertEqual(row?.activity_symbol, "figure.walk")
        XCTAssertEqual(row?.source, "inference")

        let domain = row?.presenceStatus()
        XCTAssertEqual(domain?.activity.name, "Walking")
        XCTAssertEqual(domain?.source, .inference)
    }

    // MARK: - Presentation / write mapping

    func testPresentationMapsKindsToPresenceActivity() {
        XCTAssertEqual(InferredActivityKind.walking.presenceActivity.name, "Walking")
        XCTAssertEqual(InferredActivityKind.driving.presenceActivity.name, "Driving")
        XCTAssertEqual(InferredActivityKind.chilling.presenceActivity.name, "Chilling")
        XCTAssertEqual(InferredActivityKind.moving.presenceActivity.name, "On the move")
        XCTAssertEqual(InferredActivityKind.stationary.presenceActivity, .nearby)
        XCTAssertEqual(InferredActivityKind.unknown.presenceActivity, .nearby)
        XCTAssertEqual(InferredActivityKind.walking.presenceSource, .inference)
        XCTAssertEqual(InferredActivityKind.unknown.presenceSource, .location)
    }

    func testPayloadCarriesInferredActivityThroughWriteMapping() {
        var draft = PresenceStatusDraft(
            availability: .freeNow,
            isPublished: true,
            activity: .nearby,
            latitude: 37.77,
            longitude: -122.42,
            confidence: .medium,
            observedAt: base,
            source: .location
        )
        let inferred = InferredActivityResult(
            kind: .driving,
            inferredAt: base,
            confidence: .high
        )
        ActivityInferencePresentation.apply(
            inferred,
            fallbackActivity: nil,
            to: &draft
        )
        let payload = CurrentPresenceWriteMapping.payload(
            userID: personID,
            draft: draft,
            now: base
        )
        XCTAssertEqual(payload.activity_name, "Driving")
        XCTAssertEqual(payload.activity_symbol, "car.fill")
        XCTAssertEqual(payload.source, "inference")
        XCTAssertEqual(payload.confidence, "high")
        XCTAssertEqual(payload.availability, "free_now")
    }

    // MARK: - Helpers

    private func makeSession(
        provider: LocationProviding,
        sync: PresenceSyncing,
        clock: Clock,
        activityEngine: ActivityInferenceEngine = DeterministicActivityInferenceEngine(),
        availability: FriendAvailabilityState = .freeNow
    ) -> LocationSession {
        LocationSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            inferrer: PassthroughPresenceInferrer(),
            activityEngine: activityEngine,
            sync: sync,
            availabilityProvider: { availability },
            isPresencePublishingEnabled: true,
            isTrackingDesired: true,
            now: { clock.now }
        )
    }

    private func observation(
        id: String,
        lat: Double,
        lng: Double,
        at: Date,
        speed: Double? = nil
    ) -> LocationObservation {
        LocationObservation(
            id: id,
            personID: personID,
            latitude: lat,
            longitude: lng,
            horizontalAccuracyMeters: 10,
            speedMetersPerSecond: speed,
            recordedAt: at,
            receivedAt: at,
            provider: .manualTest
        )
    }

    private func emitAndWait(
        provider: FakeLocationProvider,
        session: LocationSession,
        observation: LocationObservation
    ) async {
        provider.emit(observation)
        await waitUntil {
            session.recentActivityObservationsForTesting.contains { $0.id == observation.id }
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
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

    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }
}

// MARK: - Switching engine (heartbeat hold)

/// First `infer` returns `first`; later calls return `subsequent`.
private final class SwitchingActivityInferenceEngine: ActivityInferenceEngine, @unchecked Sendable {
    let first: InferredActivityResult
    let subsequent: InferredActivityResult
    private(set) var inferCallCount = 0

    init(first: InferredActivityResult, subsequent: InferredActivityResult) {
        self.first = first
        self.subsequent = subsequent
    }

    func infer(
        from observations: [LocationObservation],
        previous: InferredActivityResult?,
        at evaluationTime: Date
    ) -> InferredActivityResult {
        _ = observations
        _ = previous
        _ = evaluationTime
        inferCallCount += 1
        if inferCallCount == 1 {
            return first
        }
        return subsequent
    }
}
