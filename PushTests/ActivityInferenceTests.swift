//
//  ActivityInferenceTests.swift
//  PushTests
//
//  Issue #92 (I1) — domain models, configuration, fixtures, unknown engine.
//  No GPS hardware, Supabase, LocationSession, or UI.
//

import XCTest
@testable import Push

final class ActivityInferenceTests: XCTestCase {

    /// Shortly after fixture sequences end (walking ends at base+50s) so
    /// `maxObservationWindowAge` still includes them while excluding stale fixtures.
    private let now = ActivityInferenceFixtures.baseDate.addingTimeInterval(90)

    // MARK: - InferredActivityKind

    func testActivityKindHasSixDurableStates() {
        let kinds = InferredActivityKind.allCases
        XCTAssertEqual(kinds.count, 6)
        XCTAssertEqual(
            Set(kinds.map(\.rawValue)),
            Set(["unknown", "stationary", "moving", "walking", "driving", "chilling"])
        )
    }

    func testActivityKindRoundTripsThroughCodable() throws {
        for kind in InferredActivityKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(InferredActivityKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    // MARK: - InferredActivityResult

    func testResultValueSemanticsAndValidity() {
        let validUntil = now.addingTimeInterval(60)
        let result = InferredActivityResult(
            kind: .walking,
            inferredAt: now,
            confidence: .medium,
            validUntil: validUntil
        )
        XCTAssertEqual(result.kind, .walking)
        XCTAssertEqual(result.confidence, .medium)
        XCTAssertTrue(result.isValid(at: now))
        XCTAssertTrue(result.isValid(at: now.addingTimeInterval(30)))
        XCTAssertFalse(result.isValid(at: validUntil))
        XCTAssertFalse(result.isValid(at: validUntil.addingTimeInterval(1)))
    }

    func testResultWithoutExpiryIsAlwaysValid() {
        let result = InferredActivityResult(
            kind: .stationary,
            inferredAt: now,
            confidence: .high,
            validUntil: nil
        )
        XCTAssertTrue(result.isValid(at: now.addingTimeInterval(10_000)))
    }

    func testUnknownFactory() {
        let result = InferredActivityResult.unknown(
            at: now,
            confidence: .low,
            validUntil: now.addingTimeInterval(30)
        )
        XCTAssertEqual(result.kind, .unknown)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(result.inferredAt, now)
    }

    func testResultRoundTripsThroughCodable() throws {
        let original = InferredActivityResult(
            kind: .driving,
            inferredAt: now,
            confidence: .high,
            validUntil: now.addingTimeInterval(120)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InferredActivityResult.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Configuration

    func testConfigurationThresholdsAreCoherent() {
        XCTAssertGreaterThan(ActivityInferenceConfiguration.maxObservationWindowAge, 0)
        XCTAssertGreaterThanOrEqual(
            ActivityInferenceConfiguration.minimumObservationCount,
            2
        )
        XCTAssertLessThan(
            ActivityInferenceConfiguration.walkingMinSpeedMetersPerSecond,
            ActivityInferenceConfiguration.walkingMaxSpeedMetersPerSecond
        )
        XCTAssertLessThan(
            ActivityInferenceConfiguration.walkingMaxSpeedMetersPerSecond,
            ActivityInferenceConfiguration.drivingMinSpeedMetersPerSecond
        )
        XCTAssertLessThan(
            ActivityInferenceConfiguration.drivingMinSpeedMetersPerSecond,
            ActivityInferenceConfiguration.drivingMaxSpeedMetersPerSecond
        )
        XCTAssertLessThan(
            ActivityInferenceConfiguration.stationaryMaxSpeedMetersPerSecond,
            ActivityInferenceConfiguration.walkingMinSpeedMetersPerSecond
        )
        XCTAssertGreaterThan(
            ActivityInferenceConfiguration.chillingMinimumDuration,
            ActivityInferenceConfiguration.minimumWindowDuration
        )
        XCTAssertEqual(
            ActivityInferenceConfiguration.maxHorizontalAccuracyMeters,
            LocationPipelineConstants.maxHorizontalAccuracyMeters
        )
        XCTAssertGreaterThan(ActivityInferenceConfiguration.kindChangeHysteresis, 0)
        XCTAssertGreaterThan(ActivityInferenceConfiguration.unknownResultValidity, 0)
    }

    // MARK: - Observation window helpers

    func testRecentWindowFiltersByAgeAndSorts() {
        let walking = ActivityInferenceFixtures.walkingSequence()
        let stale = ActivityInferenceFixtures.staleSingleObservation()
        let shuffled = ActivityInferenceFixtures.outOfOrderSequence()
        let combined = stale + shuffled

        // Evaluate just after the walking sequence so maxAge keeps walk samples
        // and drops the intentionally stale fix (older than maxObservationWindowAge).
        let evaluationTime = ActivityInferenceFixtures.baseDate.addingTimeInterval(60)
        let window = ActivityObservationWindow.recent(
            from: combined,
            at: evaluationTime,
            maxAge: ActivityInferenceConfiguration.maxObservationWindowAge
        )

        XCTAssertTrue(window.allSatisfy { obs in
            evaluationTime.timeIntervalSince(obs.recordedAt)
                <= ActivityInferenceConfiguration.maxObservationWindowAge
                + LocationPipelineConstants.futureTimestampTolerance
        })
        XCTAssertFalse(window.contains(where: { $0.id.hasPrefix("stale") }))
        // Sorted ascending.
        let times = window.map(\.recordedAt)
        XCTAssertEqual(times, times.sorted())
        XCTAssertEqual(window.count, walking.count)
    }

    func testWindowDurationAndDisplacement() {
        let stationary = ActivityInferenceFixtures.stationarySequence(count: 4, interval: 30)
        XCTAssertEqual(
            ActivityObservationWindow.duration(stationary),
            90,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ActivityObservationWindow.netDisplacementMeters(stationary),
            0,
            accuracy: 1
        )

        let walking = ActivityInferenceFixtures.walkingSequence()
        XCTAssertGreaterThan(ActivityObservationWindow.duration(walking), 0)
        XCTAssertGreaterThan(
            ActivityObservationWindow.netDisplacementMeters(walking),
            40
        )
    }

    func testMeanSpeedIgnoresSpikes() {
        let spiked = ActivityInferenceFixtures.noisySpeedSpikeSequence()
        let mean = ActivityObservationWindow.meanSpeedMetersPerSecond(spiked)
        XCTAssertNotNil(mean)
        // Without spike filter mean would be dominated by 80 m/s.
        XCTAssertLessThan(mean ?? 999, 1.0)

        let empty: [LocationObservation] = []
        XCTAssertNil(ActivityObservationWindow.meanSpeedMetersPerSecond(empty))
    }

    func testMeanHorizontalAccuracy() {
        let poor = ActivityInferenceFixtures.poorAccuracySequence()
        let mean = ActivityObservationWindow.meanHorizontalAccuracyMeters(poor)
        XCTAssertEqual(mean ?? 0, 90, accuracy: 0.1)
    }

    // MARK: - Fixtures produce usable sequences

    func testFixtureSequencesHaveExpectedShapes() {
        assertSequence(
            ActivityInferenceFixtures.stationarySequence(),
            minCount: 2,
            personID: ActivityInferenceFixtures.defaultPersonID
        )
        assertSequence(ActivityInferenceFixtures.chillingSequence(), minCount: 2)
        assertSequence(ActivityInferenceFixtures.walkingSequence(), minCount: 2)
        assertSequence(ActivityInferenceFixtures.drivingSequence(), minCount: 2)
        assertSequence(ActivityInferenceFixtures.genericMovingSequence(), minCount: 2)
        assertSequence(ActivityInferenceFixtures.noisySpeedSpikeSequence(), minCount: 2)
        assertSequence(ActivityInferenceFixtures.poorAccuracySequence(), minCount: 2)
        assertSequence(ActivityInferenceFixtures.outOfOrderSequence(), minCount: 2)
        XCTAssertEqual(ActivityInferenceFixtures.staleSingleObservation().count, 1)
    }

    func testDrivingSequenceIsFasterThanWalking() {
        let walkSpeed = ActivityObservationWindow.meanSpeedMetersPerSecond(
            ActivityInferenceFixtures.walkingSequence()
        )
        let driveSpeed = ActivityObservationWindow.meanSpeedMetersPerSecond(
            ActivityInferenceFixtures.drivingSequence()
        )
        XCTAssertNotNil(walkSpeed)
        XCTAssertNotNil(driveSpeed)
        XCTAssertLessThan(walkSpeed ?? 0, driveSpeed ?? 0)
        XCTAssertGreaterThanOrEqual(
            walkSpeed ?? 0,
            ActivityInferenceConfiguration.walkingMinSpeedMetersPerSecond
        )
        XCTAssertLessThanOrEqual(
            walkSpeed ?? 99,
            ActivityInferenceConfiguration.walkingMaxSpeedMetersPerSecond
        )
        XCTAssertGreaterThanOrEqual(
            driveSpeed ?? 0,
            ActivityInferenceConfiguration.drivingMinSpeedMetersPerSecond
        )
    }

    func testChillingSequenceExceedsChillingDuration() {
        let chill = ActivityInferenceFixtures.chillingSequence()
        XCTAssertGreaterThanOrEqual(
            ActivityObservationWindow.duration(chill),
            ActivityInferenceConfiguration.chillingMinimumDuration
        )
        XCTAssertLessThan(
            ActivityObservationWindow.netDisplacementMeters(chill),
            ActivityInferenceConfiguration.stationaryMaxDisplacementMeters
        )
    }

    // MARK: - Protocol / unknown engine

    func testUnknownEngineAlwaysReturnsUnknown() {
        let engine = UnknownActivityInferenceEngine()
        let sequences: [[LocationObservation]] = [
            [],
            ActivityInferenceFixtures.stationarySequence(),
            ActivityInferenceFixtures.walkingSequence(),
            ActivityInferenceFixtures.drivingSequence(),
            ActivityInferenceFixtures.chillingSequence(),
            ActivityInferenceFixtures.genericMovingSequence(),
            ActivityInferenceFixtures.noisySpeedSpikeSequence(),
        ]

        for sequence in sequences {
            let result = engine.infer(from: sequence, at: now)
            XCTAssertEqual(result.kind, .unknown)
            XCTAssertEqual(result.confidence, .low)
            XCTAssertEqual(result.inferredAt, now)
            XCTAssertEqual(
                result.validUntil,
                now.addingTimeInterval(ActivityInferenceConfiguration.unknownResultValidity)
            )
        }
    }

    func testUnknownEngineIsInjectableAsProtocol() {
        let engine: ActivityInferenceEngine = UnknownActivityInferenceEngine(
            resultValidity: 15
        )
        let result = engine.infer(
            from: ActivityInferenceFixtures.walkingSequence(),
            at: now
        )
        XCTAssertEqual(result.kind, .unknown)
        XCTAssertEqual(result.validUntil, now.addingTimeInterval(15))
    }

    func testObservationsUseAppOwnedDoublesOnly() {
        let obs = ActivityInferenceFixtures.walkingSequence()[0]
        let lat: Double = obs.latitude
        let lng: Double = obs.longitude
        let accuracy: Double = obs.horizontalAccuracyMeters
        XCTAssertTrue(lat.isFinite && lng.isFinite && accuracy.isFinite)
        XCTAssertEqual(obs.provider, .manualTest)
    }

    // MARK: - Helpers

    private func assertSequence(
        _ observations: [LocationObservation],
        minCount: Int,
        personID: Person.ID? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(observations.count, minCount, file: file, line: line)
        for observation in observations {
            XCTAssertTrue(observation.latitude.isFinite, file: file, line: line)
            XCTAssertTrue(observation.longitude.isFinite, file: file, line: line)
            if let personID {
                XCTAssertEqual(observation.personID, personID, file: file, line: line)
            }
        }
    }
}
