//
//  LocationPresenceThrottleTests.swift
//  PushTests
//
//  Issue #76 — LocationSession movement throttle, heartbeat, Ghost unpublish/republish.
//

import XCTest
@testable import Push

@MainActor
final class LocationPresenceThrottleTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private let personID: Person.ID = "throttle-user"

    // MARK: - Movement throttle

    func testFirstValidFixPublishesImmediately() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync, clock: clock)

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "first", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 && session.state.lastUploadAt != nil }

        XCTAssertEqual(sync.drafts.count, 1)
        XCTAssertTrue(session.publishSnapshotForTesting.hasCompletedFirstEligiblePublish)
    }

    func testSmallMoveWithin60sIsThrottled() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync, clock: clock)

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "a", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 && session.state.lastUploadAt != nil }

        clock.now = base.addingTimeInterval(30)
        provider.emit(observation(id: "b", lat: 37.77005, lng: -122.42, at: clock.now))
        try? await Task.sleep(nanoseconds: 40_000_000)

        XCTAssertEqual(sync.drafts.count, 1, "sub-60s sub-50m must not upload")
    }

    func testMoveOver50mAfter60sPublishes() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync, clock: clock)

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "a", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 && session.state.lastUploadAt != nil }

        clock.now = base.addingTimeInterval(90)
        // ~111m north.
        provider.emit(observation(id: "b", lat: 37.771, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 2 }

        XCTAssertEqual(sync.drafts.count, 2)
        XCTAssertEqual(sync.drafts.last?.latitude, 37.771)
    }

    // MARK: - Heartbeat

    func testStationaryHeartbeatAfter15Minutes() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync, clock: clock)

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "park", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 && session.state.lastUploadAt != nil }

        clock.now = base.addingTimeInterval(LocationPipelineConstants.presenceHeartbeatInterval)
        session.checkHeartbeatDueForTesting()
        await waitUntil { sync.drafts.count == 2 }

        XCTAssertEqual(sync.drafts.count, 2)
        XCTAssertEqual(sync.drafts.last?.latitude, 37.77)
        XCTAssertEqual(sync.drafts.last?.longitude, -122.42)
    }

    func testHeartbeatDoesNotRunWhileGhosted() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync, clock: clock)

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "park", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 }

        await session.setPresencePublishingEnabled(false)
        XCTAssertEqual(sync.unpublishCount, 1)

        clock.now = base.addingTimeInterval(LocationPipelineConstants.presenceHeartbeatInterval * 2)
        session.checkHeartbeatDueForTesting()
        try? await Task.sleep(nanoseconds: 40_000_000)

        XCTAssertEqual(sync.drafts.count, 1, "heartbeat must stop while unpublished")
    }

    // MARK: - Ghost

    func testGhostUnpublishIsImmediateAndDoesNotChangeAvailability() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        var availability: FriendAvailabilityState = .busy
        let session = LocationSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            inferrer: PassthroughPresenceInferrer(),
            sync: sync,
            availabilityProvider: { availability },
            isPresencePublishingEnabled: true,
            now: { clock.now },
            sleep: parkUntilCancelled
        )

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "g1", lat: 37.77, lng: -122.42, at: clock.now))
        await waitUntil { sync.drafts.count == 1 }
        XCTAssertEqual(sync.drafts.first?.availability, .busy)

        await session.setPresencePublishingEnabled(false)

        XCTAssertEqual(sync.unpublishCount, 1)
        XCTAssertFalse(session.state.isPresencePublishingEnabled)
        XCTAssertEqual(availability, .busy, "Ghost must not mutate social availability")
    }

    func testDisablingGhostRepublishesLastAcceptedFix() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = makeSession(provider: provider, sync: sync, clock: clock)

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "r1", lat: 37.78, lng: -122.41, at: clock.now))
        await waitUntil { sync.drafts.count == 1 }

        await session.setPresencePublishingEnabled(false)
        XCTAssertEqual(sync.unpublishCount, 1)

        await session.setPresencePublishingEnabled(true)
        await waitUntil { sync.drafts.count == 2 }

        XCTAssertEqual(sync.drafts.last?.latitude, 37.78)
        XCTAssertEqual(sync.drafts.last?.longitude, -122.41)
        XCTAssertTrue(sync.drafts.last?.isPublished == true)
    }

    // MARK: - Availability mirror

    func testLocationDraftMirrorsProfileAvailabilityNeverInvents() async {
        let clock = Clock(base)
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        var availability: FriendAvailabilityState? = .joinable
        let session = LocationSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            inferrer: PassthroughPresenceInferrer(),
            sync: sync,
            availabilityProvider: { availability },
            now: { clock.now },
            sleep: parkUntilCancelled
        )

        await session.startIfEligible()
        await Task.yield()
        provider.emit(observation(id: "m1", lat: 1, lng: 2, at: clock.now))
        await waitUntil { sync.drafts.count == 1 }

        XCTAssertEqual(sync.drafts.first?.availability, .joinable)
    }

    // MARK: - Helpers

    private func makeSession(
        provider: FakeLocationProvider,
        sync: FakePresenceSync,
        clock: Clock
    ) -> LocationSession {
        LocationSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            inferrer: PassthroughPresenceInferrer(),
            sync: sync,
            availabilityProvider: { .freeNow },
            isPresencePublishingEnabled: true,
            now: { clock.now },
            // Park the heartbeat loop (do not no-op — that busy-loops MainActor).
            sleep: parkUntilCancelled
        )
    }

    /// Heartbeat loop sleep for unit tests: yield until cancelled, never spin.
    private func parkUntilCancelled(_ interval: TimeInterval) async {
        _ = interval
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
    }

    private func observation(
        id: String,
        lat: Double,
        lng: Double,
        at date: Date
    ) -> LocationObservation {
        LocationObservation(
            id: id,
            personID: personID,
            latitude: lat,
            longitude: lng,
            horizontalAccuracyMeters: 10,
            recordedAt: date,
            receivedAt: date,
            provider: .manualTest
        )
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
}

/// Mutable clock for throttle/heartbeat tests.
@MainActor
private final class Clock {
    var now: Date
    init(_ now: Date) { self.now = now }
}
