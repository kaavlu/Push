//
//  LocationObservationValidator.swift
//  Push
//
//  Phase 1 observation gate: accuracy, age, coordinates, near-duplicates, teleports.
//  Pure / Sendable — no I/O, no Core Location.
//

import Foundation

/// Default `LocationObservationValidating` implementation for Phase 1.
/// Thresholds live in `LocationPipelineConstants` only.
struct LocationObservationValidator: LocationObservationValidating, Sendable {
    private let nowProvider: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.nowProvider = now
    }

    func accept(
        _ observation: LocationObservation,
        previous: LocationObservation?
    ) -> ValidatedObservation? {
        let now = nowProvider()
        guard hasValidCoordinates(observation) else { return nil }
        guard hasValidAccuracy(observation) else { return nil }
        guard hasValidTiming(observation, now: now) else { return nil }
        if let previous {
            guard passesMovementChecks(observation, previous: previous) else { return nil }
        }
        return ValidatedObservation(
            observation: observation,
            confidence: confidence(for: observation, now: now)
        )
    }

    // MARK: - Checks

    private func hasValidCoordinates(_ observation: LocationObservation) -> Bool {
        let lat = observation.latitude
        let lon = observation.longitude
        guard lat.isFinite, lon.isFinite else { return false }
        guard (-90...90).contains(lat) else { return false }
        guard (-180...180).contains(lon) else { return false }
        return true
    }

    private func hasValidAccuracy(_ observation: LocationObservation) -> Bool {
        let accuracy = observation.horizontalAccuracyMeters
        guard accuracy.isFinite, accuracy > 0 else { return false }
        return accuracy <= LocationPipelineConstants.maxHorizontalAccuracyMeters
    }

    private func hasValidTiming(_ observation: LocationObservation, now: Date) -> Bool {
        let recordedAt = observation.recordedAt
        let age = now.timeIntervalSince(recordedAt)
        if age > LocationPipelineConstants.maxObservationAge {
            return false
        }
        if age < -LocationPipelineConstants.futureTimestampTolerance {
            return false
        }
        return true
    }

    private func passesMovementChecks(
        _ observation: LocationObservation,
        previous: LocationObservation
    ) -> Bool {
        let elapsed = observation.recordedAt.timeIntervalSince(previous.recordedAt)
        if elapsed < 0 {
            return false
        }

        let distance = GeoDistance.meters(from: previous, to: observation)

        if elapsed <= LocationPipelineConstants.nearDuplicateTimeInterval
            && distance <= LocationPipelineConstants.nearDuplicateDistanceMeters
        {
            // Predictable near-duplicate handling: drop the redundant fix.
            return false
        }

        // Same-timestamp displacement is impossible (near-duplicates already rejected above).
        if elapsed == 0 {
            return false
        }

        let speed = distance / elapsed
        if speed > LocationPipelineConstants.maxPlausibleSpeedMetersPerSecond {
            return false
        }
        return true
    }

    private func confidence(
        for observation: LocationObservation,
        now: Date
    ) -> PresenceStatus.Confidence {
        let age = max(0, now.timeIntervalSince(observation.recordedAt))
        let accurateEnough =
            observation.horizontalAccuracyMeters
            <= LocationPipelineConstants.highConfidenceAccuracyMeters
        let freshEnough = age <= LocationPipelineConstants.highConfidenceMaxAge
        if accurateEnough && freshEnough {
            return .high
        }
        return .medium
    }
}
