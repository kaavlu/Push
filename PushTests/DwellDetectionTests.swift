//
//  DwellDetectionTests.swift
//  PushTests
//
//  Issue #99 (I1) — deterministic dwell detection domain + silent session wiring.
//  No GPS hardware, Supabase, or UI.
//

import XCTest
@testable import Push

final class DwellDetectionTests: XCTestCase {

    private let base = DwellDetectionFixtures.baseDate

    // MARK: - Domain types

    func testPhaseHasThreeStates() {
        XCTAssertEqual(
            Set(DwellPhase.allCases.map(\.rawValue)),
            Set(["moving", "candidateDwell", "dwelling"])
        )
    }

    func testClusterDurationAndMovingHasNoCluster() {
        let started = base
        let last = base.addingTimeInterval(120)
        let cluster = DwellClusterSnapshot(
            centroidLatitude: 37.77,
            centroidLongitude: -122.42,
            startedAt: started,
            lastConfirmedAt: last,
            sampleCount: 4,
            representativeAccuracyMeters: 10
        )
        XCTAssertEqual(cluster.duration, 120, accuracy: 0.001)
        XCTAssertNil(DwellDetectionState.moving.cluster)
        XCTAssertTrue(
            DwellDetectionState(phase: .dwelling, cluster: cluster).isDwelling
        )
        XCTAssertEqual(
            DwellDetectionState(phase: .dwelling, cluster: cluster).confirmedDwell,
            cluster
        )
        XCTAssertNil(
            DwellDetectionState(phase: .candidateDwell, cluster: cluster).confirmedDwell
        )
    }

    func testNoOpDetectorStaysMoving() {
        var detector = NoOpDwellDetector()
        let sequence = DwellDetectionFixtures.sustainedDwellSequence()
        for observation in sequence {
            let state = detector.process(observation, at: observation.recordedAt)
            XCTAssertEqual(state.phase, .moving)
        }
    }

    // MARK: - Confirmation / rejection

    func testSustainedStationaryCreatesOneStableDwell() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.sustainedDwellSequence()
        let states = feed(sequence, into: &detector)
        XCTAssertEqual(states.last?.phase, .dwelling)

        let confirmed = states.last?.confirmedDwell
        XCTAssertNotNil(confirmed)
        XCTAssertGreaterThanOrEqual(
            confirmed!.sampleCount,
            DwellDetectionConfiguration.minimumSampleCount
        )
        XCTAssertGreaterThanOrEqual(
            confirmed!.duration,
            DwellDetectionConfiguration.minimumDwellDuration
        )
        XCTAssertEqual(confirmed!.startedAt, sequence.first!.recordedAt)

        // Single stable dwell — no phase flip-flop after confirmation.
        let dwellingStates = states.filter { $0.phase == .dwelling }
        XCTAssertFalse(dwellingStates.isEmpty)
        let starts = Set(dwellingStates.compactMap { $0.cluster?.startedAt })
        XCTAssertEqual(starts.count, 1)
    }

    func testSingleStationaryFixDoesNotCreateDwell() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.singleStationaryFix()
        let states = feed(sequence, into: &detector)
        XCTAssertNotEqual(states.last?.phase, .dwelling)
        XCTAssertEqual(states.last?.phase, .candidateDwell)
        XCTAssertEqual(states.last?.cluster?.sampleCount, 1)
    }

    func testTrafficLightStopDoesNotConfirmDwell() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.trafficLightStopSequence()
        let states = feed(sequence, into: &detector)
        XCTAssertNotEqual(states.last?.phase, .dwelling)
        // 90s span is below minimumDwellDuration (180s).
        XCTAssertEqual(states.last?.phase, .candidateDwell)
        XCTAssertLessThan(
            states.last!.cluster!.duration,
            DwellDetectionConfiguration.minimumDwellDuration
        )
    }

    func testWalkByDoesNotCreateDwell() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.walkBySequence()
        let states = feed(sequence, into: &detector)
        XCTAssertFalse(states.contains { $0.phase == .dwelling })
        // Speeding samples never join a cluster.
        XCTAssertEqual(states.last?.phase, .moving)
    }

    func testPoorAccuracySamplesAreIgnored() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.poorAccuracySequence()
        let states = feed(sequence, into: &detector)
        XCTAssertEqual(states.last?.phase, .moving)
        XCTAssertTrue(states.allSatisfy { $0.phase == .moving })
    }

    // MARK: - Centroid stability / outliers

    func testGpsDriftDoesNotResetStartOrWanderLockedCentroid() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.gpsDriftSequence()
        let states = feed(sequence, into: &detector)
        XCTAssertEqual(states.last?.phase, .dwelling)

        let dwelling = states.filter { $0.phase == .dwelling }
        guard let firstDwell = dwelling.first?.cluster,
              let lastDwell = dwelling.last?.cluster
        else {
            return XCTFail("expected confirmed dwell")
        }

        XCTAssertEqual(firstDwell.startedAt, lastDwell.startedAt)
        // Locked centroid should not walk with jitter after lock/confirm.
        let drift = GeoDistance.meters(
            fromLatitude: firstDwell.centroidLatitude,
            longitude: firstDwell.centroidLongitude,
            toLatitude: lastDwell.centroidLatitude,
            longitude: lastDwell.centroidLongitude
        )
        XCTAssertEqual(drift, 0, accuracy: 0.01)
    }

    func testSingleBlipDoesNotResetCandidateStart() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.blipThenReturnSequence()
        let states = feed(sequence, into: &detector)
        XCTAssertEqual(states.last?.phase, .dwelling)
        XCTAssertEqual(
            states.last?.cluster?.startedAt,
            sequence.first?.recordedAt
        )
    }

    func testExitAfterDwellReturnsToMoving() {
        var detector = DeterministicDwellDetector()
        let sequence = DwellDetectionFixtures.dwellThenExitSequence()
        let states = feed(sequence, into: &detector)

        XCTAssertTrue(states.contains { $0.phase == .dwelling })
        // Exit samples have high speed — after outlier budget, phase is moving
        // (speed exits do not seed a new candidate).
        XCTAssertEqual(states.last?.phase, .moving)
        XCTAssertNil(states.last?.cluster)
    }

    // MARK: - Configuration sanity

    func testConfigurationGatesAreCoherent() {
        XCTAssertGreaterThan(DwellDetectionConfiguration.dwellRadiusMeters, 0)
        XCTAssertGreaterThan(DwellDetectionConfiguration.minimumDwellDuration, 60)
        XCTAssertGreaterThanOrEqual(DwellDetectionConfiguration.minimumSampleCount, 2)
        XCTAssertLessThan(
            DwellDetectionConfiguration.maxHorizontalAccuracyMeters,
            LocationPipelineConstants.maxHorizontalAccuracyMeters
        )
        XCTAssertGreaterThan(DwellDetectionConfiguration.maxConsecutiveOutliers, 0)
        XCTAssertGreaterThanOrEqual(
            DwellDetectionConfiguration.centroidLockSampleCount,
            DwellDetectionConfiguration.minimumSampleCount
        )
    }

    func testResetClearsCluster() {
        var detector = DeterministicDwellDetector()
        _ = feed(DwellDetectionFixtures.sustainedDwellSequence(), into: &detector)
        XCTAssertEqual(detector.state.phase, .dwelling)
        detector.reset()
        XCTAssertEqual(detector.state, .moving)
    }

    // MARK: - LocationSession silent wiring

    @MainActor
    func testSessionUpdatesDwellWithoutChangingActivityApplication() async {
        let personID: Person.ID = "dwell-session-user"
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let sync = FakePresenceSync()
        let session = LocationSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            activityEngine: DeterministicActivityInferenceEngine(),
            sync: sync,
            isPresencePublishingEnabled: true,
            isTrackingDesired: true,
            now: { self.base.addingTimeInterval(10 * 60) }
        )

        await session.startIfEligible()
        XCTAssertEqual(session.dwellStateForTesting.phase, .moving)

        let sequence = DwellDetectionFixtures.sustainedDwellSequence(personID: personID)
        for observation in sequence {
            // Same accept path as live consumption (validator → dwell → activity/publish).
            session.process(observation)
        }

        XCTAssertEqual(session.dwellStateForTesting.phase, .dwelling)
        XCTAssertNotNil(session.dwellStateForTesting.confirmedDwell)

        // Dwell is parallel: activity window still records the same accepted fixes.
        XCTAssertEqual(session.recentActivityObservationsForTesting.count, sequence.count)

        session.shutdown()
        XCTAssertEqual(session.dwellStateForTesting.phase, .moving)
        XCTAssertTrue(session.recentActivityObservationsForTesting.isEmpty)
    }

    @MainActor
    func testNoOpDwellDetectorLeavesSessionMoving() async {
        let provider = FakeLocationProvider(authorizationState: .whenInUse)
        let session = LocationSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            dwellDetector: NoOpDwellDetector(),
            isPresencePublishingEnabled: true,
            isTrackingDesired: true,
            now: { self.base.addingTimeInterval(10 * 60) }
        )
        await session.startIfEligible()
        for observation in DwellDetectionFixtures.sustainedDwellSequence() {
            session.process(observation)
        }
        XCTAssertEqual(session.dwellStateForTesting.phase, .moving)
        session.shutdown()
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
