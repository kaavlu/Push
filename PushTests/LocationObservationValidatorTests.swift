//
//  LocationObservationValidatorTests.swift
//  PushTests
//
//  Issue #68 — LocationObservationValidator decisions.
//  Thresholds come only from LocationPipelineConstants.
//

import XCTest
@testable import Push

final class LocationObservationValidatorTests: XCTestCase {

    private let now = SimulatedLocationRouteFixtures.baseDate
    private lazy var validator = LocationObservationValidator(now: { [now] in now })

    // MARK: - Accept paths

    func testAcceptsNormalFirstObservation() {
        let obs = makeObservation(
            id: "first",
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: now
        )
        let accepted = validator.accept(obs, previous: nil)
        XCTAssertEqual(accepted?.observation.id, "first")
        XCTAssertEqual(accepted?.confidence, .high)
    }

    func testAcceptsPlausibleSequentialMovement() {
        let walking = SimulatedLocationRouteFixtures.normalWalking(baseDate: now)
        assertAcceptsSequence(walking.observations)
    }

    func testAcceptsDrivingLikeSequentialMovement() {
        let driving = SimulatedLocationRouteFixtures.drivingLike(baseDate: now)
        assertAcceptsSequence(driving.observations)
    }

    func testAcceptsStationarySequenceWithSpacing() {
        let stationary = SimulatedLocationRouteFixtures.stationary(baseDate: now)
        assertAcceptsSequence(stationary.observations)
    }

    func testAcceptsGapBetweenObservations() {
        let gaps = SimulatedLocationRouteFixtures.gapsBetweenObservations(baseDate: now)
        assertAcceptsSequence(gaps.observations)
    }

    // MARK: - Reject paths

    func testRejectsInvalidCoordinates() {
        let badLat = makeObservation(
            id: "bad-lat",
            latitude: 91,
            longitude: -122.4,
            accuracy: 10,
            recordedAt: now
        )
        let badLon = makeObservation(
            id: "bad-lon",
            latitude: 37.7,
            longitude: -181,
            accuracy: 10,
            recordedAt: now
        )
        XCTAssertNil(validator.accept(badLat, previous: nil))
        XCTAssertNil(validator.accept(badLon, previous: nil))
    }

    func testRejectsNonFiniteValues() {
        let nanLat = makeObservation(
            id: "nan",
            latitude: .nan,
            longitude: -122.4,
            accuracy: 10,
            recordedAt: now
        )
        let infAccuracy = makeObservation(
            id: "inf-acc",
            latitude: 37.7,
            longitude: -122.4,
            accuracy: .infinity,
            recordedAt: now
        )
        let negativeAccuracy = makeObservation(
            id: "neg-acc",
            latitude: 37.7,
            longitude: -122.4,
            accuracy: -5,
            recordedAt: now
        )
        XCTAssertNil(validator.accept(nanLat, previous: nil))
        XCTAssertNil(validator.accept(infAccuracy, previous: nil))
        XCTAssertNil(validator.accept(negativeAccuracy, previous: nil))
    }

    func testRejectsPoorAccuracy() {
        let poor = SimulatedLocationRouteFixtures.poorAccuracy(baseDate: now).observations[0]
        XCTAssertGreaterThan(
            poor.horizontalAccuracyMeters,
            LocationPipelineConstants.maxHorizontalAccuracyMeters
        )
        XCTAssertNil(validator.accept(poor, previous: nil))
    }

    func testRejectsStaleObservations() {
        let stale = SimulatedLocationRouteFixtures.staleReadings(baseDate: now).observations[0]
        XCTAssertNil(validator.accept(stale, previous: nil))
    }

    func testRejectsUnreasonablyFutureDatedObservations() {
        let future = makeObservation(
            id: "future",
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: now.addingTimeInterval(
                LocationPipelineConstants.futureTimestampTolerance + 30
            )
        )
        XCTAssertNil(validator.accept(future, previous: nil))
    }

    func testRejectsClearTeleportJumps() {
        let route = SimulatedLocationRouteFixtures.teleportJump(baseDate: now)
        let first = validator.accept(route.observations[0], previous: nil)
        XCTAssertNotNil(first)
        XCTAssertNil(validator.accept(route.observations[1], previous: first?.observation))
    }

    func testHandlesDuplicateObservationsPredictably() {
        let route = SimulatedLocationRouteFixtures.duplicates(baseDate: now)
        let first = validator.accept(route.observations[0], previous: nil)
        XCTAssertNotNil(first)
        // Near-duplicate within time + distance gates is rejected.
        XCTAssertNil(validator.accept(route.observations[1], previous: first?.observation))
    }

    func testRejectsMissingTimingWhenElapsedNegative() {
        let previous = makeObservation(
            id: "prev",
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: now
        )
        let earlier = makeObservation(
            id: "earlier",
            latitude: 37.7750,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: now.addingTimeInterval(-5)
        )
        let acceptedPrevious = validator.accept(previous, previous: nil)
        XCTAssertNotNil(acceptedPrevious)
        XCTAssertNil(validator.accept(earlier, previous: acceptedPrevious?.observation))
    }

    // MARK: - Confidence

    func testAssignsHighConfidenceForRecentAccurateReadings() {
        let obs = makeObservation(
            id: "high",
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: LocationPipelineConstants.highConfidenceAccuracyMeters,
            recordedAt: now
        )
        XCTAssertEqual(validator.accept(obs, previous: nil)?.confidence, .high)
    }

    func testAssignsMediumConfidenceForAcceptableButLessPreciseReadings() {
        let lessPrecise = makeObservation(
            id: "med-acc",
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 50,
            recordedAt: now
        )
        XCTAssertEqual(validator.accept(lessPrecise, previous: nil)?.confidence, .medium)

        let olderButAccurate = makeObservation(
            id: "med-age",
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: now.addingTimeInterval(
                -(LocationPipelineConstants.highConfidenceMaxAge + 5)
            )
        )
        XCTAssertEqual(validator.accept(olderButAccurate, previous: nil)?.confidence, .medium)
    }

    func testDoesNotMutatePreviousObservations() {
        let previous = makeObservation(
            id: "prev",
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: now
        )
        let next = makeObservation(
            id: "next",
            latitude: 37.7750,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: now.addingTimeInterval(10)
        )
        let snapshot = previous
        _ = validator.accept(next, previous: previous)
        XCTAssertEqual(previous, snapshot)
    }

    func testBoundaryAccuracyAtMaxIsAccepted() {
        let atMax = makeObservation(
            id: "at-max",
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: LocationPipelineConstants.maxHorizontalAccuracyMeters,
            recordedAt: now
        )
        XCTAssertEqual(validator.accept(atMax, previous: nil)?.confidence, .medium)
    }

    func testGeoDistanceKnownBaseline() {
        // Roughly 1° latitude ≈ 111 km.
        let meters = GeoDistance.meters(
            fromLatitude: 0,
            longitude: 0,
            toLatitude: 1,
            longitude: 0
        )
        XCTAssertEqual(meters, 111_195, accuracy: 50)
    }

    // MARK: - Helpers

    /// Evaluate the sequence with wall-clock `now` at the latest fix so earlier
    /// steps are not rejected as future-dated against a fixed epoch.
    private func assertAcceptsSequence(_ observations: [LocationObservation]) {
        guard let latest = observations.last?.recordedAt else {
            XCTFail("empty sequence")
            return
        }
        let sequenceValidator = LocationObservationValidator(now: { latest })
        var previous: LocationObservation?
        for observation in observations {
            let result = sequenceValidator.accept(observation, previous: previous)
            XCTAssertNotNil(result, "rejected \(observation.id)")
            previous = result?.observation
        }
    }

    private func makeObservation(
        id: String,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        recordedAt: Date
    ) -> LocationObservation {
        SimulatedLocationRouteFixtures.makeObservation(
            id: id,
            personID: "user-1",
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            recordedAt: recordedAt,
            receivedAt: now,
            provider: .manualTest
        )
    }
}
