//
//  LivePresenceWriteTests.swift
//  PushTests
//
//  Issue #75 — Supabase presence writes, latest-draft buffer, unpublish RPC
//  write-through. No Core Location or real network.
//

import XCTest
@testable import Push

@MainActor
final class LivePresenceWriteTests: XCTestCase {

    private enum WriteFailure: Error { case expected }

    private let now = Date(timeIntervalSince1970: 1_893_501_000) // 2030-01-01T12:30:00Z
    private let selfID = "self"

    // MARK: - Draft mapping

    func testPayloadMapsDraftToSnakeCaseWithExpiry() {
        let draft = makeDraft(
            availability: .maybeDown,
            lat: 37.7749,
            lng: -122.4194,
            confidence: .high,
            source: .location
        )
        let payload = CurrentPresenceWriteMapping.payload(
            userID: "Self-UUID", draft: draft, now: now
        )

        XCTAssertEqual(payload.user_id, "self-uuid")
        XCTAssertEqual(payload.availability, "maybe_down")
        XCTAssertTrue(payload.is_published)
        XCTAssertEqual(payload.activity_name, "Nearby")
        XCTAssertEqual(payload.activity_symbol, "location.fill")
        XCTAssertEqual(payload.latitude, 37.7749)
        XCTAssertEqual(payload.longitude, -122.4194)
        XCTAssertEqual(payload.confidence, "high")
        XCTAssertEqual(payload.source, "location")
        XCTAssertEqual(
            payload.expires_at,
            PushDateFormatting.string(now.addingTimeInterval(PresenceFreshness.hardExpire))
        )
        // Vague pair filled when draft omitted it.
        XCTAssertEqual(payload.vague_latitude, 37.77)
        XCTAssertEqual(payload.vague_longitude, -122.42)
    }

    func testInferrerCopiesObservationCoordinatesOntoDraft() {
        let obs = LocationObservation(
            id: "o1",
            personID: selfID,
            latitude: 40.7128,
            longitude: -74.0060,
            horizontalAccuracyMeters: 10,
            recordedAt: now,
            receivedAt: now,
            provider: .simulated
        )
        let draft = PassthroughPresenceInferrer().infer(
            from: [ValidatedObservation(observation: obs, confidence: .high)],
            manualAvailability: .freeNow,
            isPublished: true,
            previous: nil
        )
        XCTAssertEqual(draft.latitude, 40.7128)
        XCTAssertEqual(draft.longitude, -74.0060)
        XCTAssertTrue(draft.hasExactCoordinates)
        XCTAssertEqual(draft.vagueLatitude, 40.71)
        XCTAssertEqual(draft.vagueLongitude, -74.01)
    }

    // MARK: - Store write-through

    func testSuccessfulUpsertReplacesOwnRowAndBumpsOnce() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceOwnerUserID = selfID
        loader.presenceRows = [
            CurrentPresenceRow.fixture(userID: "friend", lat: 1, lng: 2),
            CurrentPresenceRow.fixture(
                userID: selfID, isPublished: false, lat: nil, lng: nil, expiresAt: nil
            )
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let revisionBefore = store.revision

        let draft = makeDraft(lat: 37.78, lng: -122.41)
        let row = try await store.upsertOwnPresence(
            userID: selfID, draft: draft, now: now
        )

        XCTAssertEqual(loader.upsertPresenceCallCount, 1)
        XCTAssertEqual(row.latitude, 37.78)
        XCTAssertTrue(row.is_published)
        XCTAssertEqual(store.revision, revisionBefore + 1)

        let cached = try await store.currentPresence()
        let selfRow = try XCTUnwrap(cached.first {
            $0.user_id.caseInsensitiveCompare(selfID) == .orderedSame
        })
        XCTAssertEqual(selfRow.latitude, 37.78)
        XCTAssertEqual(selfRow.longitude, -122.41)
        XCTAssertTrue(selfRow.is_published)
        // Friend row preserved.
        XCTAssertEqual(cached.count, 2)
        // Cache hit — no second network load.
        XCTAssertEqual(loader.loadCounts[LiveDataLoaderSpy.Index.presence], 1)
    }

    func testFailedUpsertDoesNotBumpRevisionOrMutateCache() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            CurrentPresenceRow.fixture(userID: selfID, lat: 10, lng: 20)
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let before = try await store.currentPresence()
        let revisionBefore = store.revision

        loader.writeError = WriteFailure.expected
        let draft = makeDraft(lat: 99, lng: 99)
        do {
            _ = try await store.upsertOwnPresence(userID: selfID, draft: draft, now: now)
            XCTFail("expected throw")
        } catch {
            // expected
        }

        XCTAssertEqual(store.revision, revisionBefore)
        let after = try await store.currentPresence()
        XCTAssertEqual(after.first?.latitude, before.first?.latitude)
        XCTAssertEqual(after.first?.longitude, before.first?.longitude)
    }

    func testUnpublishClearsCoordsAndPublishingStateOnce() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceOwnerUserID = selfID
        loader.presenceRows = [
            CurrentPresenceRow.fixture(userID: selfID, lat: 37.77, lng: -122.42),
            CurrentPresenceRow.fixture(userID: "friend", lat: 1, lng: 2)
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let revisionBefore = store.revision

        try await store.unpublishOwnPresence(userID: selfID, now: now)

        XCTAssertEqual(loader.unpublishPresenceCallCount, 1)
        XCTAssertEqual(store.revision, revisionBefore + 1)

        let cached = try await store.currentPresence()
        let selfRow = try XCTUnwrap(cached.first {
            $0.user_id.caseInsensitiveCompare(selfID) == .orderedSame
        })
        XCTAssertFalse(selfRow.is_published)
        XCTAssertNil(selfRow.latitude)
        XCTAssertNil(selfRow.longitude)
        // Friend unchanged.
        let friend = try XCTUnwrap(cached.first { $0.user_id == "friend" })
        XCTAssertEqual(friend.latitude, 1)
        XCTAssertTrue(friend.is_published)
    }

    // MARK: - Buffer coalesce / retry / shutdown

    func testFailedWriteRetainsNewestDraftOnly() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceOwnerUserID = selfID
        let store = LiveDataStore(loader: loader)
        let sync = SupabasePresenceSync(userID: selfID, store: store, now: { self.now })

        loader.writeError = WriteFailure.expected
        let older = makeDraft(lat: 1, lng: 1, observedAt: now.addingTimeInterval(-60))
        let newer = makeDraft(lat: 2, lng: 2, observedAt: now)

        do { try await sync.upsertCurrentPresence(older) } catch { /* expected */ }
        do { try await sync.upsertCurrentPresence(newer) } catch { /* expected */ }

        let pending = try XCTUnwrap(sync.pendingDraftForTesting)
        XCTAssertEqual(pending.latitude, 2)
        XCTAssertEqual(pending.longitude, 2)
        XCTAssertEqual(loader.upsertPresenceCallCount, 2)
        XCTAssertEqual(store.revision, 0, "failed writes must not look successful")
    }

    func testFlushPendingRetriesNewestDraftSuccessfully() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceOwnerUserID = selfID
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let sync = SupabasePresenceSync(userID: selfID, store: store, now: { self.now })

        loader.failNextPresenceWrite = true
        let draft = makeDraft(lat: 37.75, lng: -122.40)
        do {
            try await sync.upsertCurrentPresence(draft)
            XCTFail("expected first write to fail")
        } catch {
            // expected
        }
        XCTAssertNotNil(sync.pendingDraftForTesting)
        XCTAssertEqual(store.revision, 0)

        try await sync.flushPending()

        XCTAssertNil(sync.pendingDraftForTesting)
        XCTAssertEqual(loader.upsertPresenceCallCount, 2)
        XCTAssertEqual(store.revision, 1)
        let cached = try await store.currentPresence()
        XCTAssertEqual(cached.first?.latitude, 37.75)
    }

    func testShutdownStopsWritesAndDropsPending() async throws {
        let loader = LiveDataLoaderSpy()
        let store = LiveDataStore(loader: loader)
        let sync = SupabasePresenceSync(userID: selfID, store: store, now: { self.now })

        loader.writeError = WriteFailure.expected
        do { try await sync.upsertCurrentPresence(makeDraft(lat: 1, lng: 1)) } catch {}
        XCTAssertNotNil(sync.pendingDraftForTesting)

        sync.shutdown()
        XCTAssertTrue(sync.isShutDownForTesting)
        XCTAssertNil(sync.pendingDraftForTesting)

        loader.writeError = nil
        try await sync.upsertCurrentPresence(makeDraft(lat: 9, lng: 9))
        try await sync.flushPending()
        try await sync.unpublishCurrentPresence()

        XCTAssertEqual(loader.upsertPresenceCallCount, 1, "only the pre-shutdown attempt")
        XCTAssertEqual(loader.unpublishPresenceCallCount, 0)
        XCTAssertEqual(store.revision, 0)
    }

    func testLocationSessionShutdownPropagatesToPresenceSync() async {
        let sync = FakePresenceSync()
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let session = LocationSession(provider: provider, sync: sync)

        session.shutdown()
        session.shutdown()

        XCTAssertEqual(sync.shutdownCount, 2)
        XCTAssertTrue(sync.isShutDown)
    }

    func testPreparedLiveContainerWiresSupabasePresenceSync() async throws {
        let loader = LiveDataLoaderSpy()
        let container = try await AppDataContainer.prepareLive(
            loader: loader, currentUserID: selfID
        )
        let session = try XCTUnwrap(container.locationSession as? LocationSession)
        XCTAssertTrue(session.presenceSync is SupabasePresenceSync)
    }

    // MARK: - Availability dual-write (Issue #76)

    func testAvailabilityDualWriteUpdatesProfileAndPresenceOnce() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceOwnerUserID = selfID
        loader.presenceRows = [
            CurrentPresenceRow.fixture(
                userID: selfID, availability: "free_now", lat: 37.77, lng: -122.42
            )
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let revisionBefore = store.revision

        try await store.updateAvailability(userID: selfID, rawValue: "busy")

        XCTAssertEqual(loader.setAvailabilityChoiceCallCount, 1)
        XCTAssertEqual(loader.lastAvailabilityRawValue, "busy")
        XCTAssertEqual(store.revision, revisionBefore + 1, "one revision for dual-write")

        let profile = try await store.profile(userID: selfID)
        XCTAssertEqual(profile.availability_choice, "busy")

        let presence = try await store.currentPresence()
        let selfRow = try XCTUnwrap(presence.first {
            $0.user_id.caseInsensitiveCompare(selfID) == .orderedSame
        })
        XCTAssertEqual(selfRow.availability, "busy")
        XCTAssertTrue(selfRow.is_published, "availability must not flip publish flag")
        XCTAssertEqual(selfRow.latitude, 37.77)
    }

    func testFailedAvailabilityDoesNotBumpRevision() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            CurrentPresenceRow.fixture(userID: selfID, availability: "free_now", lat: 1, lng: 2)
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let revisionBefore = store.revision

        loader.writeError = WriteFailure.expected
        do {
            try await store.updateAvailability(userID: selfID, rawValue: "busy")
            XCTFail("expected throw")
        } catch {
            // expected
        }

        XCTAssertEqual(store.revision, revisionBefore)
        let profile = try await store.profile(userID: selfID)
        XCTAssertEqual(profile.availability_choice, "free_now")
    }

    // MARK: - Helpers

    private func makeDraft(
        availability: FriendAvailabilityState = .freeNow,
        lat: Double,
        lng: Double,
        confidence: PresenceStatus.Confidence = .medium,
        source: PresenceStatus.Source = .location,
        observedAt: Date? = nil
    ) -> PresenceStatusDraft {
        PresenceStatusDraft(
            availability: availability,
            isPublished: true,
            activity: PresenceActivity(name: "Nearby", symbolName: "location.fill"),
            latitude: lat,
            longitude: lng,
            confidence: confidence,
            observedAt: observedAt ?? now,
            source: source
        )
    }
}
