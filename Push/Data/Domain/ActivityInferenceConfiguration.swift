//
//  ActivityInferenceConfiguration.swift
//  Push
//
//  Issue #92 (I1) / #93 (I2) — centralized thresholds for activity inference.
//  All magic numbers for deterministic rules live here.
//

import Foundation

/// Thresholds and window sizes for local activity inference.
/// Grouped by concern so rule engines share one source of truth.
enum ActivityInferenceConfiguration {
    // MARK: Observation window

    /// Maximum age of an observation relative to evaluation time still
    /// considered for classification.
    static let maxObservationWindowAge: TimeInterval = 10 * 60
    /// Minimum number of points before non-unknown rules may fire (I2+).
    static let minimumObservationCount = 2
    /// Minimum wall-clock span of the window before sustained-state rules apply.
    static let minimumWindowDuration: TimeInterval = 45

    // MARK: Stationary / chilling

    /// Max great-circle displacement (meters) treated as "not moving."
    static let stationaryMaxDisplacementMeters: Double = 25
    /// Max mean speed (m/s) consistent with stationary / chilling.
    static let stationaryMaxSpeedMetersPerSecond: Double = 0.4
    /// Minimum dwell duration before `chilling` may replace raw `stationary`.
    static let chillingMinimumDuration: TimeInterval = 8 * 60

    // MARK: Walking

    /// Inclusive lower bound for pedestrian mean speed (m/s).
    static let walkingMinSpeedMetersPerSecond: Double = 0.7
    /// Inclusive upper bound for pedestrian mean speed (m/s).
    static let walkingMaxSpeedMetersPerSecond: Double = 2.5
    /// Minimum sustained duration before committing to `.walking`.
    static let walkingMinimumDuration: TimeInterval = 30

    // MARK: Driving

    /// Inclusive lower bound for vehicle mean speed (m/s) ≈ 5.4 km/h.
    static let drivingMinSpeedMetersPerSecond: Double = 4.0
    /// Soft upper bound (m/s) — still classify as driving below teleport gates.
    static let drivingMaxSpeedMetersPerSecond: Double = 40
    /// Minimum sustained duration before committing to `.driving`.
    static let drivingMinimumDuration: TimeInterval = 30

    // MARK: Generic moving

    /// Displacement (meters) that implies motion even when speed samples are nil.
    static let movingMinDisplacementMeters: Double = 40
    /// Minimum duration of ambiguous motion before `.moving` (not walking/driving).
    static let movingMinimumDuration: TimeInterval = 30

    // MARK: Accuracy & noise

    /// Prefer samples with accuracy at or better than this (meters).
    static let preferredHorizontalAccuracyMeters: Double = 50
    /// Drop samples worse than this from the inference window (meters).
    static let maxHorizontalAccuracyMeters: Double =
        LocationPipelineConstants.maxHorizontalAccuracyMeters
    /// Ignore single-sample speed spikes above this (m/s) when averaging.
    static let speedSpikeIgnoreThresholdMetersPerSecond: Double = 55

    // MARK: Hysteresis (I2)

    /// Extra duration a new kind must sustain before replacing the previous kind.
    static let kindChangeHysteresis: TimeInterval = 20
    /// Soft validity assigned to unknown results (caching seam).
    static let unknownResultValidity: TimeInterval = 60
    /// Soft validity for non-unknown results before consumers re-evaluate.
    static let classifiedResultValidity: TimeInterval = 90

    // MARK: Confidence mapping (I2)

    /// Window span at or above this with clean samples → high confidence.
    static let highConfidenceMinimumDuration: TimeInterval = 90
    /// Mean accuracy at or below this (meters) for high confidence.
    static let highConfidenceMaxMeanAccuracyMeters: Double = 25
    /// Mean accuracy at or below this (meters) for at least medium confidence.
    static let mediumConfidenceMaxMeanAccuracyMeters: Double = 50
}
