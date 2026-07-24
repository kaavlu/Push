//
//  DeterministicActivityInferenceTests.swift
//  PushTests
//
//  Issue #93 (I2) — deterministic movement / chilling inference rules.
//  No GPS hardware, Supabase, LocationSession, or UI.
//

import XCTest
@testable import Push

final class DeterministicActivityInferenceTests: XCTestCase {

    private let engine = DeterministicActivityInferenceEngine()
    private let base = ActivityInferenceFixtures.baseDate

    // MARK: - Core classifications

    func testStationarySequence() {
        let sequence = ActivityInferenceFixtures.stationarySequence()
        let at = evaluationTime(after: sequence)
        let result = engine.infer(from: sequence, at: at)
        XCTAssertEqual(result.kind, .stationary)
        XCTAssertNotEqual(result.confidence, .low)
    }

    func testWalkingSequence() {
        let sequence = ActivityInferenceFixtures.walkingSequence()
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        XCTAssertEqual(result.kind, .walking)
    }

    func testDrivingSequence() {
        let sequence = ActivityInferenceFixtures.drivingSequence()
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        XCTAssertEqual(result.kind, .driving)
    }

    func testGenericMovingSequence() {
        let sequence = ActivityInferenceFixtures.genericMovingSequence()
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        XCTAssertEqual(result.kind, .moving)
    }

    func testSustainedChillingSequence() {
        let sequence = ActivityInferenceFixtures.chillingSequence()
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        XCTAssertEqual(result.kind, .chilling)
        XCTAssertEqual(result.confidence, .high)
    }

    // MARK: - Noise / quality

    func testSpeedSpikeDoesNotForceDriving() {
        let sequence = ActivityInferenceFixtures.noisySpeedSpikeSequence()
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        XCTAssertEqual(result.kind, .stationary)
    }

    func testPoorAccuracyLowersConfidenceButStillClassifies() {
        let sequence = ActivityInferenceFixtures.poorAccuracySequence()
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        // 1.5 m/s in walking band, duration 45s.
        XCTAssertEqual(result.kind, .walking)
        XCTAssertEqual(result.confidence, .low)
    }

    func testOutOfOrderObservationsStillWalk() {
        let sequence = ActivityInferenceFixtures.outOfOrderSequence()
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        XCTAssertEqual(result.kind, .walking)
    }

    func testStaleObservationsReturnUnknown() {
        let sequence = ActivityInferenceFixtures.staleSingleObservation()
        // Evaluate at baseDate — stale sample is older than the window.
        let result = engine.infer(from: sequence, at: base)
        XCTAssertEqual(result.kind, .unknown)
        XCTAssertEqual(result.confidence, .low)
    }

    func testEmptyAndSingleObservationReturnUnknown() {
        XCTAssertEqual(
            engine.infer(from: [], at: base).kind,
            .unknown
        )
        let single = ActivityInferenceFixtures.stationarySequence(count: 1, interval: 0)
        XCTAssertEqual(
            engine.infer(from: single, at: base).kind,
            .unknown
        )
    }

    func testShortWindowBelowMinimumDurationIsUnknown() {
        // Two points 10s apart — below minimumWindowDuration (45s).
        let sequence = ActivityInferenceFixtures.stationarySequence(count: 2, interval: 10)
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        XCTAssertEqual(result.kind, .unknown)
    }

    // MARK: - Hysteresis / flip avoidance

    func testHysteresisAvoidsRapidStateFlipping() {
        let walking = ActivityInferenceFixtures.walkingSequence()
        let walkAt = evaluationTime(after: walking)
        let walkResult = engine.infer(from: walking, at: walkAt)
        XCTAssertEqual(walkResult.kind, .walking)

        // Brief stationary window (45s) is enough for raw stationary but not
        // stationary min + hysteresis (45 + 20 = 65) when switching from walking.
        let briefStationary = ActivityInferenceFixtures.stationarySequence(
            baseDate: walkAt,
            count: 4,
            interval: 15
        )
        let briefAt = evaluationTime(after: briefStationary)
        let held = engine.infer(
            from: briefStationary,
            previous: walkResult,
            at: briefAt
        )
        XCTAssertEqual(held.kind, .walking, "Should hold walking under hysteresis")

        // Sustained stationary long enough to clear min duration + hysteresis.
        let sustainedStationary = ActivityInferenceFixtures.stationarySequence(
            baseDate: briefAt,
            count: 4,
            interval: 30
        )
        let sustainedAt = evaluationTime(after: sustainedStationary)
        // previous must still be valid at sustainedAt
        let previousStillValid = InferredActivityResult(
            kind: .walking,
            inferredAt: walkAt,
            confidence: .medium,
            validUntil: sustainedAt.addingTimeInterval(60)
        )
        let switched = engine.infer(
            from: sustainedStationary,
            previous: previousStillValid,
            at: sustainedAt
        )
        XCTAssertEqual(switched.kind, .stationary)
    }

    func testValidPreviousHeldWhenWindowBecomesEmpty() {
        let walking = ActivityInferenceFixtures.walkingSequence()
        let walkAt = evaluationTime(after: walking)
        let walkResult = engine.infer(from: walking, at: walkAt)
        XCTAssertEqual(walkResult.kind, .walking)

        let held = engine.infer(
            from: [],
            previous: walkResult,
            at: walkAt.addingTimeInterval(10)
        )
        XCTAssertEqual(held.kind, .walking)
        XCTAssertEqual(held.confidence, .low)
    }

    func testExpiredPreviousDoesNotBlockNewKind() {
        let walking = ActivityInferenceFixtures.walkingSequence()
        let walkAt = evaluationTime(after: walking)
        let expired = InferredActivityResult(
            kind: .driving,
            inferredAt: walkAt.addingTimeInterval(-120),
            confidence: .medium,
            validUntil: walkAt.addingTimeInterval(-1)
        )
        let result = engine.infer(
            from: walking,
            previous: expired,
            at: walkAt
        )
        XCTAssertEqual(result.kind, .walking)
    }

    func testSameKindDoesNotRequireExtraHysteresis() {
        let walking = ActivityInferenceFixtures.walkingSequence()
        let walkAt = evaluationTime(after: walking)
        let first = engine.infer(from: walking, at: walkAt)
        let second = engine.infer(
            from: walking,
            previous: first,
            at: walkAt.addingTimeInterval(5)
        )
        XCTAssertEqual(second.kind, .walking)
    }

    // MARK: - Displacement-only (nil speed)

    func testWalkingFromDisplacementWhenSpeedNil() {
        let sequence = nilSpeedWalkSequence()
        let result = engine.infer(from: sequence, at: evaluationTime(after: sequence))
        XCTAssertEqual(result.kind, .walking)
    }

    // MARK: - Protocol seam

    func testEngineIsInjectableAsProtocol() {
        let injected: ActivityInferenceEngine = DeterministicActivityInferenceEngine()
        let sequence = ActivityInferenceFixtures.drivingSequence()
        let result = injected.infer(
            from: sequence,
            previous: nil,
            at: evaluationTime(after: sequence)
        )
        XCTAssertEqual(result.kind, .driving)
    }

    // MARK: - Helpers

    private func evaluationTime(after sequence: [LocationObservation]) -> Date {
        let last = sequence.map(\.recordedAt).max() ?? base
        return last.addingTimeInterval(1)
    }

    /// Pedestrian path with nil speed — classification uses path length / duration.
    private func nilSpeedWalkSequence() -> [LocationObservation] {
        // ~14 m north per 10 s ≈ 1.4 m/s, six points, 50s span.
        (0..<6).map { index in
            LocationObservation(
                id: "nil-speed-walk-\(index)",
                personID: ActivityInferenceFixtures.defaultPersonID,
                latitude: 37.77490 + (Double(index) * 0.00013),
                longitude: -122.41940,
                horizontalAccuracyMeters: 12,
                altitudeMeters: nil,
                speedMetersPerSecond: nil,
                courseDegrees: nil,
                recordedAt: base.addingTimeInterval(TimeInterval(index * 10)),
                receivedAt: base.addingTimeInterval(TimeInterval(index * 10)),
                provider: .manualTest
            )
        }
    }
}
