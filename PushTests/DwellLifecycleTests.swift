//
//  DwellLifecycleTests.swift
//  PushTests
//
//  Issue #100 (I2) — arrival / departure lifecycle on top of dwell detection.
//  No GPS hardware, Supabase, or UI.
//

import XCTest
@testable import Push

final class DwellLifecycleTests: XCTestCase {

    private let base = DwellDetectionFixtures.baseDate

    // MARK: - Types

    func testTransitionCases() {
        XCTAssertEqual(
            Set(DwellTransition.allCases.map(\.rawValue)),
            Set(["arrived", "departed"])
        )
    }

    func testCompletedSessionExposesVenueResolutionFields() {
        let started = base
        let arrived = base.addingTimeInterval(180)
        let departed = base.addingTimeInterval(600)
        let session = DwellLifecycleSession(
            id: "test",
            centroidLatitude: 37.77,
            centroidLongitude: -122.42,
            startedAt: started,
            arrivedAt: arrived,
            departedAt: departed,
            lastConfirmedAt: departed.addingTimeInterval(-30),
            sampleCount: 12,
            representativeAccuracyMeters: 9
        )
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.sessionDuration, 600, accuracy: 0.001)
        XCTAssertEqual(session.confirmedDuration, 420, accuracy: 0.001)
        XCTAssertGreaterThan(session.sampleCount, 0)
        XCTAssertFalse(session.id.isEmpty)
    }

    // MARK: - Arrival

    func testOneArrivalWhenDwellConfirms() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.sustainedDwellSequence()
        let states = feed(sequence, into: &detector)

        let arrivals = states.compactMap(\.transition).filter { $0 == .arrived }
        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(states.last?.phase, .dwelling)
        XCTAssertNotNil(states.last?.activeSession)
        XCTAssertEqual(states.last?.activeSession?.departedAt, nil)

        let arrivalIndex = states.firstIndex { $0.transition == .arrived }
        XCTAssertNotNil(arrivalIndex)
        // After arrival, further inliers do not re-emit arrived.
        let after = states.suffix(from: states.index(after: arrivalIndex!))
        XCTAssertFalse(after.contains { $0.transition == .arrived })
    }

    func testNoArrivalOnCandidateOnly() {
        var detector = DeterministicDwellDetector()
        let states = feed(
            DwellDetectionFixtures.trafficLightStopSequence(),
            into: &detector
        )
        XCTAssertTrue(states.allSatisfy { $0.transition == nil })
        XCTAssertEqual(states.last?.phase, .candidateDwell)
        XCTAssertNil(states.last?.activeSession)
    }

    // MARK: - Stay / near zone

    func testLargeVenueWanderDoesNotDepart() {
        var detector = DeterministicDwellDetector()
        let states = feed(
            DwellDetectionFixtures.largeVenueWanderSequence(),
            into: &detector
        )
        XCTAssertEqual(states.last?.phase, .dwelling)
        XCTAssertFalse(states.contains { $0.transition == .departed })
        XCTAssertNil(states.last?.lastCompletedSession)
        XCTAssertNotNil(states.last?.activeSession)
    }

    func testGpsDriftKeepsSingleArrivalAndNoDeparture() {
        var detector = DeterministicDwellDetector()
        let states = feed(
            DwellDetectionFixtures.gpsDriftSequence(),
            into: &detector
        )
        XCTAssertEqual(states.compactMap(\.transition).filter { $0 == .arrived }.count, 1)
        XCTAssertFalse(states.contains { $0.transition == .departed })
        XCTAssertEqual(states.last?.phase, .dwelling)
    }

    func testBriefLeaveThenReturnDoesNotDepart() {
        var detector = DeterministicDwellDetector()
        let states = feed(
            DwellDetectionFixtures.briefLeaveThenReturnSequence(),
            into: &detector
        )
        XCTAssertEqual(states.last?.phase, .dwelling)
        XCTAssertFalse(states.contains { $0.transition == .departed })
        XCTAssertNil(states.last?.lastCompletedSession)
    }

    func testSingleInaccurateFixDoesNotEndDwell() {
        var detector = DeterministicDwellDetector()
        let states = feed(
            DwellDetectionFixtures.dwellWithSingleBadFixSequence(),
            into: &detector
        )
        XCTAssertEqual(states.last?.phase, .dwelling)
        XCTAssertFalse(states.contains { $0.transition == .departed })
        // Bad accuracy sample is ignored — active session continues.
        XCTAssertNotNil(states.last?.activeSession)
    }

    // MARK: - Departure

    func testSustainedDepartureEmitsOnceAndPreservesSession() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.dwellThenExitSequence()
        let states = feed(sequence, into: &detector)

        let arrivals = states.compactMap(\.transition).filter { $0 == .arrived }
        let departures = states.compactMap(\.transition).filter { $0 == .departed }
        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(departures.count, 1)

        let completed = states.last?.lastCompletedSession
        XCTAssertNotNil(completed)
        XCTAssertTrue(completed!.isComplete)
        XCTAssertNotNil(completed!.departedAt)
        XCTAssertEqual(completed!.arrivedAt, states.first { $0.transition == .arrived }?
            .activeSession?.arrivedAt)
        XCTAssertGreaterThan(completed!.sampleCount, 0)
        XCTAssertEqual(states.last?.phase, .moving)
        XCTAssertNil(states.last?.activeSession)
    }

    func testReArrivalCreatesSecondSession() {
        var detector = DeterministicDwellDetector()
        let states = feed(
            DwellDetectionFixtures.reArrivalSequence(),
            into: &detector
        )

        let arrivals = states.enumerated().filter { $0.element.transition == .arrived }
        let departures = states.filter { $0.transition == .departed }
        XCTAssertEqual(arrivals.count, 2)
        XCTAssertEqual(departures.count, 1)
        XCTAssertEqual(states.last?.phase, .dwelling)

        let firstArrivalSession = arrivals[0].element.activeSession
        let secondArrivalSession = arrivals[1].element.activeSession
        XCTAssertNotNil(firstArrivalSession)
        XCTAssertNotNil(secondArrivalSession)
        XCTAssertNotEqual(firstArrivalSession?.id, secondArrivalSession?.id)
        // Completed first stay remains available for venue resolution.
        XCTAssertNotNil(states.last?.lastCompletedSession)
        XCTAssertEqual(states.last?.lastCompletedSession?.id, firstArrivalSession?.id)
    }

    // MARK: - Parking

    func testParkingThenStayCreatesOneDwell() {
        var detector = DeterministicDwellDetector()
        let states = feed(
            DwellDetectionFixtures.parkingThenStaySequence(),
            into: &detector
        )
        XCTAssertEqual(states.compactMap(\.transition).filter { $0 == .arrived }.count, 1)
        XCTAssertFalse(states.contains { $0.transition == .departed })
        XCTAssertEqual(states.last?.phase, .dwelling)
        // Driving prefix never produced a completed session.
        XCTAssertNil(states.last?.lastCompletedSession)
    }

    // MARK: - Config

    func testDepartureConfigWiderThanInlierRadius() {
        XCTAssertGreaterThan(
            DwellDetectionConfiguration.departureRadiusMeters,
            DwellDetectionConfiguration.dwellRadiusMeters
        )
        XCTAssertGreaterThan(DwellDetectionConfiguration.minimumDepartureDuration, 0)
        XCTAssertGreaterThanOrEqual(
            DwellDetectionConfiguration.minimumDepartureSampleCount,
            2
        )
    }

    // MARK: - Session wiring

    @MainActor
    func testSessionSurfacesCompletedDwellAfterDeparture() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let session = LocationSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            isPresencePublishingEnabled: true,
            isTrackingDesired: true,
            now: { self.base.addingTimeInterval(30 * 60) }
        )
        await session.startIfEligible()

        for observation in DwellDetectionFixtures.dwellThenExitSequence() {
            session.process(observation)
        }

        XCTAssertEqual(session.dwellStateForTesting.phase, .moving)
        XCTAssertEqual(session.dwellStateForTesting.transition, .departed)
        XCTAssertNotNil(session.lastCompletedDwellSessionForTesting)
        XCTAssertTrue(session.lastCompletedDwellSessionForTesting!.isComplete)

        session.shutdown()
        XCTAssertNil(session.lastCompletedDwellSessionForTesting)
    }

    // MARK: - Helpers

    private func feed(
        _ observations: [LocationObservation],
        into detector: inout DeterministicDwellDetector
    ) -> [DwellDetectionState] {
        observations.map { observation in
            detector.process(observation, at: observation.recordedAt)
        }
    }
}
