//
//  DeterministicDwellDetector.swift
//  Push
//
//  Issue #99 (I1) / #100 (I2) — incremental dwell state machine with
//  arrival/departure lifecycle. Pure / Sendable; no Core Location, network, or UI.
//

import Foundation

/// Deterministic place-cluster detector with arrival/departure hysteresis.
///
/// Consumes validated app-owned observations one at a time and emits
/// `moving` / `candidateDwell` / `dwelling` plus one-shot `arrived` /
/// `departed` transitions and completed session metadata.
/// Does not infer venues, activity labels, or availability.
struct DeterministicDwellDetector: DwellDetecting {
    private(set) var state: DwellDetectionState = .moving

    private var working: DwellWorkingCluster?
    private var consecutiveOutliers = 0
    private var activeSession: DwellLifecycleSession?
    private var lastCompletedSession: DwellLifecycleSession?
    private var departureStreak: DwellDepartureStreak?

    mutating func process(
        _ observation: LocationObservation,
        at evaluationTime: Date
    ) -> DwellDetectionState {
        _ = evaluationTime
        guard hasUsableAccuracy(observation) else {
            // Poor / non-finite accuracy — ignore entirely (no inlier, no departure).
            return republish(transition: nil)
        }

        switch state.phase {
        case .moving:
            if isClearlyMoving(observation) {
                return republish(transition: nil)
            }
            beginCandidate(with: observation)
            return state

        case .candidateDwell:
            if isClearlyMoving(observation) {
                // Speed ends an unconfirmed stop without lifecycle events.
                registerCandidateOutlier(seedNewCandidate: nil)
                return state
            }
            handleCandidate(observation)
            return state

        case .dwelling:
            handleDwelling(observation)
            return state
        }
    }

    mutating func reset() {
        state = .moving
        working = nil
        consecutiveOutliers = 0
        activeSession = nil
        lastCompletedSession = nil
        departureStreak = nil
    }

    // MARK: - Quality

    private func hasUsableAccuracy(_ observation: LocationObservation) -> Bool {
        guard observation.latitude.isFinite, observation.longitude.isFinite else {
            return false
        }
        let accuracy = observation.horizontalAccuracyMeters
        guard accuracy.isFinite, accuracy > 0 else { return false }
        return accuracy <= DwellDetectionConfiguration.maxHorizontalAccuracyMeters
    }

    private func isClearlyMoving(_ observation: LocationObservation) -> Bool {
        guard let speed = observation.speedMetersPerSecond, speed.isFinite else {
            return false
        }
        return speed > DwellDetectionConfiguration.maxSpeedMetersPerSecond
    }

    // MARK: - Candidate (I1)

    private mutating func beginCandidate(
        with observation: LocationObservation,
        transition: DwellTransition? = nil
    ) {
        var cluster = DwellWorkingCluster(
            startedAt: observation.recordedAt,
            centroidLocked: false
        )
        cluster.accept(observation)
        working = cluster
        consecutiveOutliers = 0
        departureStreak = nil
        activeSession = nil
        publish(
            phase: .candidateDwell,
            from: cluster,
            transition: transition,
            active: nil
        )
    }

    private mutating func handleCandidate(_ observation: LocationObservation) {
        guard var cluster = working else {
            beginCandidate(with: observation)
            return
        }

        let distance = distanceFromCentroid(cluster, to: observation)
        if distance <= DwellDetectionConfiguration.dwellRadiusMeters {
            consecutiveOutliers = 0
            cluster.accept(observation)
            working = cluster
            if shouldConfirm(cluster.snapshot) {
                promoteToDwelling(cluster: cluster, at: observation.recordedAt)
            } else {
                publish(
                    phase: .candidateDwell,
                    from: cluster,
                    transition: nil,
                    active: nil
                )
            }
            return
        }

        registerCandidateOutlier(seedNewCandidate: observation)
    }

    private mutating func registerCandidateOutlier(seedNewCandidate: LocationObservation?) {
        consecutiveOutliers += 1
        guard consecutiveOutliers > DwellDetectionConfiguration.maxConsecutiveOutliers else {
            _ = republish(transition: nil)
            return
        }
        clearWorkingCluster()
        if let seedNewCandidate, !isClearlyMoving(seedNewCandidate) {
            beginCandidate(with: seedNewCandidate)
        } else {
            publishMoving(transition: nil)
        }
    }

    // MARK: - Dwelling + departure (I2)

    private mutating func promoteToDwelling(cluster: DwellWorkingCluster, at arrivedAt: Date) {
        var locked = cluster
        locked.centroidLocked = true
        working = locked
        consecutiveOutliers = 0
        departureStreak = nil

        let snapshot = locked.snapshot
        let session = DwellLifecycleSession(
            id: DwellLifecycleSession.makeID(
                startedAt: snapshot.startedAt,
                latitude: snapshot.centroidLatitude,
                longitude: snapshot.centroidLongitude
            ),
            centroidLatitude: snapshot.centroidLatitude,
            centroidLongitude: snapshot.centroidLongitude,
            startedAt: snapshot.startedAt,
            arrivedAt: arrivedAt,
            departedAt: nil,
            lastConfirmedAt: snapshot.lastConfirmedAt,
            sampleCount: snapshot.sampleCount,
            representativeAccuracyMeters: snapshot.representativeAccuracyMeters
        )
        activeSession = session
        publish(
            phase: .dwelling,
            from: locked,
            transition: .arrived,
            active: session
        )
    }

    private mutating func handleDwelling(_ observation: LocationObservation) {
        guard var cluster = working, var session = activeSession else {
            // Recoverable inconsistency — treat as fresh candidate if slow.
            if isClearlyMoving(observation) {
                publishMoving(transition: nil)
            } else {
                beginCandidate(with: observation)
            }
            return
        }

        let distance = distanceFromCentroid(cluster, to: observation)
        let clearlyMoving = isClearlyMoving(observation)

        // Tight inlier zone: refresh cluster + cancel departure streak.
        if !clearlyMoving && distance <= DwellDetectionConfiguration.dwellRadiusMeters {
            departureStreak = nil
            cluster.accept(observation)
            working = cluster
            session = session.updating(from: cluster.snapshot)
            activeSession = session
            publish(
                phase: .dwelling,
                from: cluster,
                transition: nil,
                active: session
            )
            return
        }

        // Near zone (large venue / lot): stay dwelling, cancel departure.
        if !clearlyMoving && distance <= DwellDetectionConfiguration.departureRadiusMeters {
            departureStreak = nil
            session = session.refreshingLastConfirmed(at: observation.recordedAt)
            activeSession = session
            publish(
                phase: .dwelling,
                from: cluster,
                transition: nil,
                active: session
            )
            return
        }

        // Outside departure radius and/or clearly moving — accumulate leave evidence.
        accumulateDeparture(observation: observation, cluster: cluster, session: session)
    }

    private mutating func accumulateDeparture(
        observation: LocationObservation,
        cluster: DwellWorkingCluster,
        session: DwellLifecycleSession
    ) {
        var streak = departureStreak ?? DwellDepartureStreak(
            firstAt: observation.recordedAt,
            sampleCount: 0
        )
        streak.sampleCount += 1
        streak.lastAt = observation.recordedAt
        departureStreak = streak

        let duration = streak.lastAt.timeIntervalSince(streak.firstAt)
        let samplesOK = streak.sampleCount
            >= DwellDetectionConfiguration.minimumDepartureSampleCount
        let durationOK = duration
            >= DwellDetectionConfiguration.minimumDepartureDuration

        if samplesOK && durationOK {
            completeDeparture(
                observation: observation,
                cluster: cluster,
                session: session,
                departedAt: observation.recordedAt
            )
            return
        }

        // Still dwelling until hysteresis completes — no transition.
        publish(
            phase: .dwelling,
            from: cluster,
            transition: nil,
            active: session
        )
    }

    private mutating func completeDeparture(
        observation: LocationObservation,
        cluster: DwellWorkingCluster,
        session: DwellLifecycleSession,
        departedAt: Date
    ) {
        let completed = session.completing(
            departedAt: departedAt,
            lastConfirmedAt: session.lastConfirmedAt,
            sampleCount: cluster.sampleCount,
            representativeAccuracyMeters: cluster.snapshot.representativeAccuracyMeters
        )
        lastCompletedSession = completed
        activeSession = nil
        working = nil
        consecutiveOutliers = 0
        departureStreak = nil

        // Distance leave with low speed may seed a new candidate at the new place,
        // but this process() tick must still surface the one-shot `.departed`.
        if !isClearlyMoving(observation) {
            beginCandidate(with: observation, transition: .departed)
        } else {
            state = DwellDetectionState(
                phase: .moving,
                cluster: nil,
                transition: .departed,
                activeSession: nil,
                lastCompletedSession: completed
            )
        }
    }

    // MARK: - Publish helpers

    private func shouldConfirm(_ snapshot: DwellClusterSnapshot) -> Bool {
        snapshot.sampleCount >= DwellDetectionConfiguration.minimumSampleCount
            && snapshot.duration >= DwellDetectionConfiguration.minimumDwellDuration
    }

    private func distanceFromCentroid(
        _ cluster: DwellWorkingCluster,
        to observation: LocationObservation
    ) -> Double {
        GeoDistance.meters(
            fromLatitude: cluster.centroidLatitude,
            longitude: cluster.centroidLongitude,
            toLatitude: observation.latitude,
            longitude: observation.longitude
        )
    }

    private mutating func publish(
        phase: DwellPhase,
        from cluster: DwellWorkingCluster,
        transition: DwellTransition?,
        active: DwellLifecycleSession?
    ) {
        state = DwellDetectionState(
            phase: phase,
            cluster: cluster.snapshot,
            transition: transition,
            activeSession: active,
            lastCompletedSession: lastCompletedSession
        )
    }

    private mutating func publishMoving(transition: DwellTransition?) {
        working = nil
        consecutiveOutliers = 0
        departureStreak = nil
        activeSession = nil
        state = DwellDetectionState(
            phase: .moving,
            cluster: nil,
            transition: transition,
            activeSession: nil,
            lastCompletedSession: lastCompletedSession
        )
    }

    private mutating func clearWorkingCluster() {
        working = nil
        consecutiveOutliers = 0
        activeSession = nil
        departureStreak = nil
    }

    /// Re-emit current durable fields with a fresh (usually nil) transition.
    private mutating func republish(transition: DwellTransition?) -> DwellDetectionState {
        state = DwellDetectionState(
            phase: state.phase,
            cluster: state.cluster,
            transition: transition,
            activeSession: activeSession,
            lastCompletedSession: lastCompletedSession
        )
        return state
    }
}
