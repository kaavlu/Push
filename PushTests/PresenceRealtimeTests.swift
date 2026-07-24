//
//  PresenceRealtimeTests.swift
//  PushTests
//
//  Issue #84 — Realtime presence event mapping, LiveDataStore remote apply,
//  and PresenceRealtimeBridge lifecycle. No live Supabase project.
//

import XCTest
@testable import Push

@MainActor
final class PresenceRealtimeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_893_501_000) // 2030-01-01T12:30:00Z
    private let selfID = "self-uuid"
    private let friendID = "friend-uuid"

    // MARK: - Applicator

    func testInsertFriendPublishedYieldsUpsert() {
        let row = CurrentPresenceRow.fixture(userID: friendID)
        let op = PresenceRealtimeApplying.operation(
            from: .insert(row), currentUserID: selfID, now: now
        )
        XCTAssertEqual(op, .upsert(row))
    }

    func testInsertSelfIsIgnored() {
        let row = CurrentPresenceRow.fixture(userID: selfID)
        let op = PresenceRealtimeApplying.operation(
            from: .insert(row), currentUserID: selfID, now: now
        )
        XCTAssertNil(op)
    }

    func testInsertNilRowIsIgnored() {
        let op = PresenceRealtimeApplying.operation(
            from: .insert(nil), currentUserID: selfID, now: now
        )
        XCTAssertNil(op)
    }

    func testInsertUnpublishedYieldsRemove() {
        let row = CurrentPresenceRow.fixture(
            userID: friendID, isPublished: false, lat: nil, lng: nil, expiresAt: nil
        )
        let op = PresenceRealtimeApplying.operation(
            from: .insert(row), currentUserID: selfID, now: now
        )
        XCTAssertEqual(op, .remove(userID: friendID))
    }

    func testUpdatePublishedYieldsUpsert() {
        let row = CurrentPresenceRow.fixture(
            userID: friendID, availability: "maybe_down", lat: 37.78, lng: -122.41
        )
        let op = PresenceRealtimeApplying.operation(
            from: .update(new: row, oldUserID: friendID),
            currentUserID: selfID,
            now: now
        )
        XCTAssertEqual(op, .upsert(row))
    }

    func testUpdateGhostUnpublishYieldsRemove() {
        let row = CurrentPresenceRow.fixture(
            userID: friendID, isPublished: false, lat: nil, lng: nil, expiresAt: nil
        )
        let op = PresenceRealtimeApplying.operation(
            from: .update(new: row, oldUserID: friendID),
            currentUserID: selfID,
            now: now
        )
        XCTAssertEqual(op, .remove(userID: friendID))
    }

    func testUpdateNilNewWithOldUserIDYieldsRemove() {
        let op = PresenceRealtimeApplying.operation(
            from: .update(new: nil, oldUserID: friendID),
            currentUserID: selfID,
            now: now
        )
        XCTAssertEqual(op, .remove(userID: friendID))
    }

    func testUpdateNilNewAndNilOldYieldsReconcileHint() {
        let op = PresenceRealtimeApplying.operation(
            from: .update(new: nil, oldUserID: nil),
            currentUserID: selfID,
            now: now
        )
        XCTAssertEqual(op, .reconcileHint)
    }

    func testDeleteWithUserIDYieldsRemove() {
        let op = PresenceRealtimeApplying.operation(
            from: .delete(oldUserID: friendID),
            currentUserID: selfID,
            now: now
        )
        XCTAssertEqual(op, .remove(userID: friendID))
    }

    func testDeleteWithoutUserIDYieldsReconcileHint() {
        let op = PresenceRealtimeApplying.operation(
            from: .delete(oldUserID: nil),
            currentUserID: selfID,
            now: now
        )
        XCTAssertEqual(op, .reconcileHint)
    }

    func testDeleteSelfIsIgnored() {
        let op = PresenceRealtimeApplying.operation(
            from: .delete(oldUserID: selfID),
            currentUserID: selfID,
            now: now
        )
        XCTAssertNil(op)
    }

    // MARK: - Store remote apply

    func testApplyRemotePresenceRowAppendsAndReportsChange() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [CurrentPresenceRow.fixture(userID: selfID)]
        let store = LiveDataStore(loader: loader)
        try await store.warm()

        let friend = CurrentPresenceRow.fixture(userID: friendID, lat: 1, lng: 2)
        XCTAssertTrue(store.applyRemotePresenceRow(friend))

        let cached = try await store.currentPresence()
        XCTAssertTrue(cached.contains { $0.user_id == friendID })
    }

    func testApplyRemotePresenceRowReplacesNewer() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            CurrentPresenceRow.fixture(
                userID: friendID, lat: 1, lng: 2, updatedAt: "2030-01-01T12:00:00Z"
            )
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()

        let newer = CurrentPresenceRow.fixture(
            userID: friendID, lat: 9, lng: 9, updatedAt: "2030-01-01T12:20:00Z"
        )
        XCTAssertTrue(store.applyRemotePresenceRow(newer))
        let cached = try await store.currentPresence()
        XCTAssertEqual(cached.first?.latitude, 9)
    }

    func testApplyRemotePresenceRowRejectsStale() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            CurrentPresenceRow.fixture(
                userID: friendID, lat: 5, lng: 5, updatedAt: "2030-01-01T12:20:00Z"
            )
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()

        let stale = CurrentPresenceRow.fixture(
            userID: friendID, lat: 1, lng: 1, updatedAt: "2030-01-01T12:00:00Z"
        )
        XCTAssertFalse(store.applyRemotePresenceRow(stale))
        let cached = try await store.currentPresence()
        XCTAssertEqual(cached.first?.latitude, 5)
    }

    func testApplyRemotePresenceRowEqualIsNoChange() async throws {
        let row = CurrentPresenceRow.fixture(userID: friendID)
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [row]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        XCTAssertFalse(store.applyRemotePresenceRow(row))
    }

    func testRemoveRemotePresenceRemovesRow() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            CurrentPresenceRow.fixture(userID: friendID),
            CurrentPresenceRow.fixture(userID: selfID)
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()

        XCTAssertTrue(store.removeRemotePresence(userID: friendID))
        let cached = try await store.currentPresence()
        XCTAssertFalse(cached.contains { $0.user_id == friendID })
        XCTAssertTrue(cached.contains { $0.user_id == selfID })
    }

    func testRemoveRemotePresenceMissingIsNoChange() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [CurrentPresenceRow.fixture(userID: selfID)]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        XCTAssertFalse(store.removeRemotePresence(userID: friendID))
    }

    func testReconcilePresenceReplacesSnapshot() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [CurrentPresenceRow.fixture(userID: friendID, lat: 1, lng: 1)]
        let store = LiveDataStore(loader: loader)
        try await store.warm()

        loader.presenceRows = [
            CurrentPresenceRow.fixture(userID: friendID, lat: 2, lng: 2),
            CurrentPresenceRow.fixture(userID: selfID)
        ]
        let changed = try await store.reconcilePresence()
        XCTAssertTrue(changed)
        let cached = try await store.currentPresence()
        XCTAssertEqual(cached.count, 2)
        XCTAssertEqual(cached.first { $0.user_id == friendID }?.latitude, 2)
    }

    func testReconcilePresenceUnchangedReturnsFalse() async throws {
        let rows = [CurrentPresenceRow.fixture(userID: friendID)]
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = rows
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        // Same content from loader.
        let changed = try await store.reconcilePresence()
        XCTAssertFalse(changed)
    }

    func testPublishPresenceRevisionBumpsOnce() async throws {
        let store = LiveDataStore(loader: LiveDataLoaderSpy())
        try await store.warm()
        let before = store.revision
        store.publishPresenceRevision()
        XCTAssertEqual(store.revision, before + 1)
    }

    // MARK: - Bridge

    func testBridgeStartConnectsAndReconciles() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [CurrentPresenceRow.fixture(userID: friendID)]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let source = FakePresenceRealtimeSource()
        let bridge = PresenceRealtimeBridge(
            store: store,
            currentUserID: selfID,
            source: source,
            debounce: 0.01,
            now: { self.now }
        )

        await bridge.start()
        XCTAssertTrue(bridge.isRunning)
        XCTAssertEqual(source.connectCount, 1)
        // warm already had friend; reconcile same snapshot → no extra revision required
        await bridge.stop()
        XCTAssertFalse(bridge.isRunning)
        XCTAssertEqual(source.disconnectCount, 1)
    }

    func testBridgeSecondStartIsNoOp() async throws {
        let store = LiveDataStore(loader: LiveDataLoaderSpy())
        try await store.warm()
        let source = FakePresenceRealtimeSource()
        let bridge = PresenceRealtimeBridge(
            store: store, currentUserID: selfID, source: source, debounce: 0.01
        )
        await bridge.start()
        await bridge.start()
        XCTAssertEqual(source.connectCount, 1)
        await bridge.stop()
    }

    func testBridgeInsertPatchesCacheAndRevisionsOnce() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [CurrentPresenceRow.fixture(userID: selfID)]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let revisionBefore = store.revision

        let source = FakePresenceRealtimeSource()
        let bridge = PresenceRealtimeBridge(
            store: store,
            currentUserID: selfID,
            source: source,
            debounce: 0.02,
            now: { self.now }
        )
        await bridge.start()

        let friend = CurrentPresenceRow.fixture(userID: friendID, lat: 10, lng: 20)
        source.yield(.insert(friend))
        try await Task.sleep(nanoseconds: 80_000_000)

        let cached = try await store.currentPresence()
        XCTAssertTrue(cached.contains { $0.user_id == friendID && $0.latitude == 10 })
        XCTAssertEqual(store.revision, revisionBefore + 1)
        await bridge.stop()
    }

    func testBridgeIgnoresSelfEvents() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            CurrentPresenceRow.fixture(userID: selfID, lat: 1, lng: 1)
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let revisionBefore = store.revision

        let source = FakePresenceRealtimeSource()
        let bridge = PresenceRealtimeBridge(
            store: store,
            currentUserID: selfID,
            source: source,
            debounce: 0.02,
            now: { self.now }
        )
        await bridge.start()
        source.yield(.insert(CurrentPresenceRow.fixture(userID: selfID, lat: 9, lng: 9)))
        try await Task.sleep(nanoseconds: 80_000_000)

        let cached = try await store.currentPresence()
        XCTAssertEqual(cached.first?.latitude, 1)
        XCTAssertEqual(store.revision, revisionBefore)
        await bridge.stop()
    }

    func testBridgeGhostUpdateRemovesFriend() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            CurrentPresenceRow.fixture(userID: friendID, lat: 1, lng: 1),
            CurrentPresenceRow.fixture(userID: selfID)
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()

        let source = FakePresenceRealtimeSource()
        let bridge = PresenceRealtimeBridge(
            store: store,
            currentUserID: selfID,
            source: source,
            debounce: 0.02,
            now: { self.now }
        )
        await bridge.start()

        let unpublished = CurrentPresenceRow.fixture(
            userID: friendID, isPublished: false, lat: nil, lng: nil, expiresAt: nil
        )
        source.yield(.update(new: unpublished, oldUserID: friendID))
        try await Task.sleep(nanoseconds: 80_000_000)

        let cached = try await store.currentPresence()
        XCTAssertFalse(cached.contains { $0.user_id == friendID })
        await bridge.stop()
    }

    func testBridgeLateEventsAfterStopAreIgnored() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [CurrentPresenceRow.fixture(userID: selfID)]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let revisionBefore = store.revision

        let source = FakePresenceRealtimeSource()
        let bridge = PresenceRealtimeBridge(
            store: store,
            currentUserID: selfID,
            source: source,
            debounce: 0.02,
            now: { self.now }
        )
        await bridge.start()
        await bridge.stop()

        source.yield(.insert(CurrentPresenceRow.fixture(userID: friendID)))
        try await Task.sleep(nanoseconds: 80_000_000)

        let cached = try await store.currentPresence()
        XCTAssertFalse(cached.contains { $0.user_id == friendID })
        XCTAssertEqual(store.revision, revisionBefore)
    }

    func testBridgeStaleUpdateDoesNotBumpRevision() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            CurrentPresenceRow.fixture(
                userID: friendID, lat: 5, lng: 5, updatedAt: "2030-01-01T12:20:00Z"
            )
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let revisionBefore = store.revision

        let source = FakePresenceRealtimeSource()
        let bridge = PresenceRealtimeBridge(
            store: store,
            currentUserID: selfID,
            source: source,
            debounce: 0.02,
            now: { self.now }
        )
        await bridge.start()

        let stale = CurrentPresenceRow.fixture(
            userID: friendID, lat: 1, lng: 1, updatedAt: "2030-01-01T12:00:00Z"
        )
        source.yield(.update(new: stale, oldUserID: friendID))
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(store.revision, revisionBefore)
        let cached = try await store.currentPresence()
        XCTAssertEqual(cached.first?.latitude, 5)
        await bridge.stop()
    }

    func testMockContainerHasNoRealtimeBridge() {
        let container = AppDataContainer(seed: .standard())
        XCTAssertNil(container.presenceRealtimeBridge)
    }
}
