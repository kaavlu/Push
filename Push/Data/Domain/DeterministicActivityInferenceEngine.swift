//
//  DeterministicActivityInferenceEngine.swift
//  Push
//
//  Issue #93 (I2) — local motion / chilling classification from location
//  observations. Pure / Sendable; no Core Location, network, or UI.
//

import Foundation

/// Deterministic activity rules over a recent observation window.
///
/// Uses elapsed time, displacement, path length, speed, accuracy, minimum
/// duration thresholds, and previous-result hysteresis. Does not infer
/// venues, co-presence, arrived/left, or availability.
struct DeterministicActivityInferenceEngine: ActivityInferenceEngine {
    func infer(
        from observations: [LocationObservation],
        previous: InferredActivityResult?,
        at evaluationTime: Date
    ) -> InferredActivityResult {
        let window = prepareWindow(from: observations, at: evaluationTime)
        guard let metrics = WindowMetrics.make(from: window) else {
            return holdOrUnknown(previous: previous, at: evaluationTime)
        }

        let rawKind = classify(metrics)
        let kind = applyHysteresis(
            rawKind: rawKind,
            metrics: metrics,
            previous: previous,
            at: evaluationTime
        )
        let confidence = confidence(for: kind, metrics: metrics)
        let validity = kind == .unknown
            ? ActivityInferenceConfiguration.unknownResultValidity
            : ActivityInferenceConfiguration.classifiedResultValidity

        return InferredActivityResult(
            kind: kind,
            inferredAt: evaluationTime,
            confidence: confidence,
            validUntil: evaluationTime.addingTimeInterval(validity)
        )
    }

    // MARK: - Window preparation

    private func prepareWindow(
        from observations: [LocationObservation],
        at evaluationTime: Date
    ) -> [LocationObservation] {
        let recent = ActivityObservationWindow.recent(
            from: observations,
            at: evaluationTime
        )
        return ActivityObservationWindow.accuracyFiltered(recent)
    }

    // MARK: - Classification

    private func classify(_ metrics: WindowMetrics) -> InferredActivityKind {
        guard metrics.count >= ActivityInferenceConfiguration.minimumObservationCount else {
            return .unknown
        }
        guard metrics.duration >= ActivityInferenceConfiguration.minimumWindowDuration else {
            return .unknown
        }

        if isStationaryLike(metrics) {
            if metrics.duration >= ActivityInferenceConfiguration.chillingMinimumDuration {
                return .chilling
            }
            return .stationary
        }

        if isDriving(metrics) {
            return .driving
        }
        if isWalking(metrics) {
            return .walking
        }
        if isMoving(metrics) {
            return .moving
        }
        return .unknown
    }

    private func isStationaryLike(_ metrics: WindowMetrics) -> Bool {
        let maxDisplacement = ActivityInferenceConfiguration.stationaryMaxDisplacementMeters
        let maxSpeed = ActivityInferenceConfiguration.stationaryMaxSpeedMetersPerSecond
        let lowNet = metrics.netDisplacementMeters <= maxDisplacement
        let lowPath = metrics.pathLengthMeters <= maxDisplacement * 2
        let sampleSpeedOK = metrics.meanSampleSpeed.map { $0 <= maxSpeed } ?? true
        let effectiveOK = metrics.effectiveSpeedMetersPerSecond <= maxSpeed
            || metrics.effectiveSpeedMetersPerSecond
                < ActivityInferenceConfiguration.walkingMinSpeedMetersPerSecond
        return lowNet && lowPath && sampleSpeedOK && effectiveOK
    }

    private func isDriving(_ metrics: WindowMetrics) -> Bool {
        guard metrics.duration >= ActivityInferenceConfiguration.drivingMinimumDuration else {
            return false
        }
        let min = ActivityInferenceConfiguration.drivingMinSpeedMetersPerSecond
        let max = ActivityInferenceConfiguration.drivingMaxSpeedMetersPerSecond
        if speedInBand(metrics, min: min, max: max) {
            return true
        }
        // Displacement-only vehicle motion when speed samples are sparse.
        return metrics.effectiveSpeedMetersPerSecond >= min
            && metrics.effectiveSpeedMetersPerSecond <= max
            && metrics.netDisplacementMeters
                >= ActivityInferenceConfiguration.movingMinDisplacementMeters
    }

    private func isWalking(_ metrics: WindowMetrics) -> Bool {
        guard metrics.duration >= ActivityInferenceConfiguration.walkingMinimumDuration else {
            return false
        }
        let min = ActivityInferenceConfiguration.walkingMinSpeedMetersPerSecond
        let max = ActivityInferenceConfiguration.walkingMaxSpeedMetersPerSecond
        if speedInBand(metrics, min: min, max: max) {
            return true
        }
        return metrics.effectiveSpeedMetersPerSecond >= min
            && metrics.effectiveSpeedMetersPerSecond <= max
            && metrics.pathLengthMeters
                >= ActivityInferenceConfiguration.movingMinDisplacementMeters
    }

    private func isMoving(_ metrics: WindowMetrics) -> Bool {
        guard metrics.duration >= ActivityInferenceConfiguration.movingMinimumDuration else {
            return false
        }
        if metrics.netDisplacementMeters
            >= ActivityInferenceConfiguration.movingMinDisplacementMeters
        {
            return true
        }
        if metrics.pathLengthMeters
            >= ActivityInferenceConfiguration.movingMinDisplacementMeters
        {
            return true
        }
        if let sample = metrics.meanSampleSpeed,
           sample > ActivityInferenceConfiguration.stationaryMaxSpeedMetersPerSecond,
           sample < ActivityInferenceConfiguration.drivingMinSpeedMetersPerSecond
        {
            return true
        }
        let effective = metrics.effectiveSpeedMetersPerSecond
        return effective > ActivityInferenceConfiguration.stationaryMaxSpeedMetersPerSecond
            && effective < ActivityInferenceConfiguration.drivingMinSpeedMetersPerSecond
    }

    private func speedInBand(
        _ metrics: WindowMetrics,
        min: Double,
        max: Double
    ) -> Bool {
        if let sample = metrics.meanSampleSpeed, sample >= min, sample <= max {
            return true
        }
        let effective = metrics.effectiveSpeedMetersPerSecond
        return effective >= min && effective <= max
    }

    // MARK: - Hysteresis

    private func applyHysteresis(
        rawKind: InferredActivityKind,
        metrics: WindowMetrics,
        previous: InferredActivityResult?,
        at evaluationTime: Date
    ) -> InferredActivityKind {
        guard let previous, previous.isValid(at: evaluationTime) else {
            return rawKind
        }
        if previous.kind == rawKind {
            return rawKind
        }
        // Brief unknown / empty windows should not wipe a still-valid activity.
        if rawKind == .unknown {
            return previous.kind
        }
        // Require the new kind's minimum duration plus hysteresis before flipping.
        let required = minimumDuration(for: rawKind)
            + ActivityInferenceConfiguration.kindChangeHysteresis
        if metrics.duration >= required {
            return rawKind
        }
        return previous.kind
    }

    private func holdOrUnknown(
        previous: InferredActivityResult?,
        at evaluationTime: Date
    ) -> InferredActivityResult {
        if let previous, previous.isValid(at: evaluationTime), previous.kind != .unknown {
            return InferredActivityResult(
                kind: previous.kind,
                inferredAt: evaluationTime,
                confidence: .low,
                validUntil: previous.validUntil
            )
        }
        return .unknown(
            at: evaluationTime,
            confidence: .low,
            validUntil: evaluationTime.addingTimeInterval(
                ActivityInferenceConfiguration.unknownResultValidity
            )
        )
    }

    private func minimumDuration(for kind: InferredActivityKind) -> TimeInterval {
        switch kind {
        case .unknown:
            return 0
        case .stationary:
            return ActivityInferenceConfiguration.minimumWindowDuration
        case .chilling:
            return ActivityInferenceConfiguration.chillingMinimumDuration
        case .walking:
            return ActivityInferenceConfiguration.walkingMinimumDuration
        case .driving:
            return ActivityInferenceConfiguration.drivingMinimumDuration
        case .moving:
            return ActivityInferenceConfiguration.movingMinimumDuration
        }
    }

    // MARK: - Confidence

    private func confidence(
        for kind: InferredActivityKind,
        metrics: WindowMetrics
    ) -> PresenceStatus.Confidence {
        if kind == .unknown {
            return .low
        }
        let accuracy = metrics.meanAccuracyMeters
            ?? ActivityInferenceConfiguration.maxHorizontalAccuracyMeters
        let longEnough =
            metrics.duration >= ActivityInferenceConfiguration.highConfidenceMinimumDuration
        let accurateEnough =
            accuracy <= ActivityInferenceConfiguration.highConfidenceMaxMeanAccuracyMeters
        if longEnough && accurateEnough {
            return .high
        }
        if accuracy <= ActivityInferenceConfiguration.mediumConfidenceMaxMeanAccuracyMeters {
            return .medium
        }
        return .low
    }
}

// MARK: - Window metrics

private struct WindowMetrics {
    let count: Int
    let duration: TimeInterval
    let netDisplacementMeters: Double
    let pathLengthMeters: Double
    let meanSampleSpeed: Double?
    let meanAccuracyMeters: Double?

    /// Path-derived speed (m/s); 0 when duration is zero.
    var effectiveSpeedMetersPerSecond: Double {
        guard duration > 0 else { return 0 }
        return pathLengthMeters / duration
    }

    static func make(from observations: [LocationObservation]) -> WindowMetrics? {
        guard !observations.isEmpty else { return nil }
        return WindowMetrics(
            count: observations.count,
            duration: ActivityObservationWindow.duration(observations),
            netDisplacementMeters: ActivityObservationWindow.netDisplacementMeters(observations),
            pathLengthMeters: ActivityObservationWindow.pathLengthMeters(observations),
            meanSampleSpeed: ActivityObservationWindow.meanSpeedMetersPerSecond(observations),
            meanAccuracyMeters: ActivityObservationWindow.meanHorizontalAccuracyMeters(
                observations
            )
        )
    }
}
