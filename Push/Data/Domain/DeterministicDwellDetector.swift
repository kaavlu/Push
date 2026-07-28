//
//  DeterministicDwellDetector.swift
//  Push
//
//  Issue #99 (I1) — incremental dwell state machine from location observations.
//  Pure / Sendable; no Core Location, network, or UI.
//

import Foundation

/// Deterministic place-cluster detector.
///
/// Consumes validated app-owned observations one at a time and emits
/// `moving` / `candidateDwell` / `dwelling` with a stable centroid.
/// Does not infer venues, activity labels, or availability.
struct DeterministicDwellDetector: DwellDetecting {
    private(set) var state: DwellDetectionState = .moving

    private var working: WorkingCluster?
    private var consecutiveOutliers = 0

    mutating func process(
        _ observation: LocationObservation,
        at evaluationTime: Date
    ) -> DwellDetectionState {
        _ = evaluationTime
        guard hasUsableAccuracy(observation) else {
            // Poor / non-finite accuracy — ignore entirely (no inlier, no outlier).
            return state
        }

        if isClearlyMoving(observation) {
            // Speed above the dwell gate ends a cluster but does not seed a new one.
            if state.phase != .moving {
                registerOutlier(seedNewCandidate: nil)
            }
            return state
        }

        switch state.phase {
        case .moving:
            beginCandidate(with: observation)
        case .candidateDwell, .dwelling:
            handleClustered(observation)
        }
        return state
    }

    mutating func reset() {
        state = .moving
        working = nil
        consecutiveOutliers = 0
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

    // MARK: - Transitions

    private mutating func beginCandidate(with observation: LocationObservation) {
        var cluster = WorkingCluster(
            startedAt: observation.recordedAt,
            centroidLocked: false
        )
        cluster.accept(observation)
        working = cluster
        consecutiveOutliers = 0
        publish(phase: .candidateDwell, from: cluster)
    }

    private mutating func handleClustered(_ observation: LocationObservation) {
        guard var cluster = working else {
            beginCandidate(with: observation)
            return
        }

        let distance = GeoDistance.meters(
            fromLatitude: cluster.centroidLatitude,
            longitude: cluster.centroidLongitude,
            toLatitude: observation.latitude,
            longitude: observation.longitude
        )

        if distance <= DwellDetectionConfiguration.dwellRadiusMeters {
            consecutiveOutliers = 0
            cluster.accept(observation)
            working = cluster
            publishActivePhase(from: cluster)
            return
        }

        // Outside radius: count toward exit. After budget, seed a candidate at the
        // new place so a real departure continues the stream.
        registerOutlier(seedNewCandidate: observation)
    }

    /// - Parameter seedNewCandidate: When the outlier budget is exceeded, optionally
    ///   start a new candidate at this observation (distance exits). Pass `nil` for
    ///   pure motion exits so a single speeding sample does not seed a false dwell.
    private mutating func registerOutlier(seedNewCandidate: LocationObservation?) {
        consecutiveOutliers += 1
        guard consecutiveOutliers > DwellDetectionConfiguration.maxConsecutiveOutliers else {
            return
        }
        resetToMoving()
        if let seedNewCandidate {
            beginCandidate(with: seedNewCandidate)
        }
    }

    private mutating func publishActivePhase(from cluster: WorkingCluster) {
        let snapshot = cluster.snapshot
        if shouldConfirm(snapshot) {
            var locked = cluster
            locked.centroidLocked = true
            working = locked
            publish(phase: .dwelling, from: locked)
        } else if state.phase == .dwelling {
            // Already confirmed — stay dwelling with updated metrics.
            publish(phase: .dwelling, from: cluster)
        } else {
            publish(phase: .candidateDwell, from: cluster)
        }
    }

    private func shouldConfirm(_ snapshot: DwellClusterSnapshot) -> Bool {
        snapshot.sampleCount >= DwellDetectionConfiguration.minimumSampleCount
            && snapshot.duration >= DwellDetectionConfiguration.minimumDwellDuration
    }

    private mutating func publish(phase: DwellPhase, from cluster: WorkingCluster) {
        state = DwellDetectionState(phase: phase, cluster: cluster.snapshot)
    }

    private mutating func resetToMoving() {
        state = .moving
        working = nil
        consecutiveOutliers = 0
    }
}

// MARK: - Working cluster

private struct WorkingCluster {
    var startedAt: Date
    var lastConfirmedAt: Date
    var sampleCount: Int
    var sumLatitude: Double
    var sumLongitude: Double
    var sumAccuracy: Double
    /// Samples that still contribute to the running centroid mean.
    var unlockedSampleCount: Int
    var centroidLatitude: Double
    var centroidLongitude: Double
    var centroidLocked: Bool

    init(startedAt: Date, centroidLocked: Bool) {
        self.startedAt = startedAt
        self.lastConfirmedAt = startedAt
        self.sampleCount = 0
        self.sumLatitude = 0
        self.sumLongitude = 0
        self.sumAccuracy = 0
        self.unlockedSampleCount = 0
        self.centroidLatitude = 0
        self.centroidLongitude = 0
        self.centroidLocked = centroidLocked
    }

    mutating func accept(_ observation: LocationObservation) {
        lastConfirmedAt = observation.recordedAt
        sampleCount += 1
        sumAccuracy += observation.horizontalAccuracyMeters

        if !centroidLocked {
            sumLatitude += observation.latitude
            sumLongitude += observation.longitude
            unlockedSampleCount += 1
            centroidLatitude = sumLatitude / Double(unlockedSampleCount)
            centroidLongitude = sumLongitude / Double(unlockedSampleCount)
            if unlockedSampleCount >= DwellDetectionConfiguration.centroidLockSampleCount {
                centroidLocked = true
            }
        }
    }

    var snapshot: DwellClusterSnapshot {
        let accuracy = sampleCount > 0
            ? sumAccuracy / Double(sampleCount)
            : 0
        return DwellClusterSnapshot(
            centroidLatitude: centroidLatitude,
            centroidLongitude: centroidLongitude,
            startedAt: startedAt,
            lastConfirmedAt: lastConfirmedAt,
            sampleCount: sampleCount,
            representativeAccuracyMeters: accuracy
        )
    }
}
