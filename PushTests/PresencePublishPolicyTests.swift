//
//  PresencePublishPolicyTests.swift
//  PushTests
//
//  Issue #76 — pure movement throttle + heartbeat schedule (no I/O).
//

import XCTest
@testable import Push

final class PresencePublishPolicyTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let personID: Person.ID = "policy-user"

    // MARK: - First fix / firstEligibleStart

    func testFirstFixPublishesImmediately() {
        let obs = observation(lat: 37.77, lng: -122.42)
        let decision = PresencePublishPolicy.decisionForMovement(
            observation: obs,
            now: t0,
            snapshot: PresencePublishSnapshot()
        )
        XCTAssertEqual(decision, .publish(.firstEligibleStart))
        XCTAssertTrue(PresenceSyncTrigger.firstEligibleStart.bypassesMovementThrottle)
    }

    func testAfterFirstWriteSmallMoveWithinIntervalSkips() {
        var snap = PresencePublishSnapshot()
        snap = PresencePublishPolicy.recordingSuccessfulWrite(
            on: snap, at: t0, latitude: 37.77, longitude: -122.42
        )
        // ~10m east, only 10s later — must not upload.
        let obs = observation(lat: 37.77, lng: -122.4199, at: t0.addingTimeInterval(10))
        let decision = PresencePublishPolicy.decisionForMovement(
            observation: obs,
            now: t0.addingTimeInterval(10),
            snapshot: snap
        )
        XCTAssertEqual(decision, .skip)
    }

    // MARK: - 60s / 50m matrix

    func testIntervalMetButDisplacementUnder50mSkips() {
        var snap = PresencePublishSnapshot()
        snap = PresencePublishPolicy.recordingSuccessfulWrite(
            on: snap, at: t0, latitude: 37.77, longitude: -122.42
        )
        // ~10m, 90s later.
        let obs = observation(lat: 37.77005, lng: -122.42, at: t0.addingTimeInterval(90))
        let decision = PresencePublishPolicy.decisionForMovement(
            observation: obs,
            now: t0.addingTimeInterval(90),
            snapshot: snap
        )
        XCTAssertEqual(decision, .skip)
    }

    func testDisplacementOver50mButIntervalUnder60sSkips() {
        var snap = PresencePublishSnapshot()
        snap = PresencePublishPolicy.recordingSuccessfulWrite(
            on: snap, at: t0, latitude: 37.77, longitude: -122.42
        )
        // ~100m north, only 30s later.
        let obs = observation(lat: 37.771, lng: -122.42, at: t0.addingTimeInterval(30))
        let decision = PresencePublishPolicy.decisionForMovement(
            observation: obs,
            now: t0.addingTimeInterval(30),
            snapshot: snap
        )
        XCTAssertEqual(decision, .skip)
    }

    func testIntervalAndDisplacementBothMetPublishesMovement() {
        var snap = PresencePublishSnapshot()
        snap = PresencePublishPolicy.recordingSuccessfulWrite(
            on: snap, at: t0, latitude: 37.77, longitude: -122.42
        )
        let later = t0.addingTimeInterval(90)
        // ~111m north.
        let obs = observation(lat: 37.771, lng: -122.42, at: later)
        let decision = PresencePublishPolicy.decisionForMovement(
            observation: obs,
            now: later,
            snapshot: snap
        )
        XCTAssertEqual(decision, .publish(.movement))
        XCTAssertFalse(PresenceSyncTrigger.movement.bypassesMovementThrottle)
    }

    // MARK: - Heartbeat

    func testHeartbeatNotDueBeforeInterval() {
        var snap = PresencePublishSnapshot()
        snap = PresencePublishPolicy.recordingSuccessfulWrite(
            on: snap, at: t0, latitude: 37.77, longitude: -122.42
        )
        let decision = PresencePublishPolicy.decisionForHeartbeat(
            now: t0.addingTimeInterval(14 * 60),
            snapshot: snap
        )
        XCTAssertEqual(decision, .skip)
    }

    func testHeartbeatDueAfter15MinutesEvenIfStationary() {
        var snap = PresencePublishSnapshot()
        snap = PresencePublishPolicy.recordingSuccessfulWrite(
            on: snap, at: t0, latitude: 37.77, longitude: -122.42
        )
        let decision = PresencePublishPolicy.decisionForHeartbeat(
            now: t0.addingTimeInterval(LocationPipelineConstants.presenceHeartbeatInterval),
            snapshot: snap
        )
        XCTAssertEqual(decision, .publish(.heartbeat))
        XCTAssertTrue(PresenceSyncTrigger.heartbeat.bypassesMovementThrottle)
    }

    func testHeartbeatSkippedBeforeFirstPublish() {
        let decision = PresencePublishPolicy.decisionForHeartbeat(
            now: t0.addingTimeInterval(30 * 60),
            snapshot: PresencePublishSnapshot()
        )
        XCTAssertEqual(decision, .skip)
    }

    // MARK: - Snapshot bookkeeping

    func testUnpublishResetsFirstEligibleSoNextFixPublishes() {
        var snap = PresencePublishSnapshot()
        snap = PresencePublishPolicy.recordingSuccessfulWrite(
            on: snap, at: t0, latitude: 37.77, longitude: -122.42
        )
        snap = PresencePublishPolicy.recordingUnpublish(on: snap)

        XCTAssertFalse(snap.hasCompletedFirstEligiblePublish)
        XCTAssertNil(snap.lastSuccessfulWriteAt)
        XCTAssertFalse(snap.hasUploadedCoordinates)

        let decision = PresencePublishPolicy.decisionForMovement(
            observation: observation(lat: 37.77, lng: -122.42),
            now: t0.addingTimeInterval(5),
            snapshot: snap
        )
        XCTAssertEqual(decision, .publish(.firstEligibleStart))
    }

    // MARK: - Bypass matrix (constants already covered; re-assert contract)

    func testPrivacyAndAvailabilityTriggersBypassMovementThrottle() {
        let bypasses: [PresenceSyncTrigger] = [
            .unpublish, .republish, .availabilityChange,
            .permissionRevoked, .sessionShutdown, .firstEligibleStart,
            .sharingPolicyReduced, .heartbeat
        ]
        for trigger in bypasses {
            XCTAssertTrue(
                trigger.bypassesMovementThrottle,
                "\(trigger) must bypass 60s/50m"
            )
        }
        XCTAssertFalse(PresenceSyncTrigger.movement.bypassesMovementThrottle)
    }

    // MARK: - Helpers

    private func observation(
        lat: Double,
        lng: Double,
        at date: Date? = nil
    ) -> LocationObservation {
        let when = date ?? t0
        return LocationObservation(
            id: "obs-\(lat)-\(lng)",
            personID: personID,
            latitude: lat,
            longitude: lng,
            horizontalAccuracyMeters: 10,
            recordedAt: when,
            receivedAt: when,
            provider: .manualTest
        )
    }
}
