//
//  DwellDetectionConfiguration.swift
//  Push
//
//  Issue #99 (I1) / #100 (I2) — centralized thresholds for dwell detection
//  and arrival/departure lifecycle.
//

import Foundation

/// Thresholds for local dwell detection. All magic numbers for the detector live here.
enum DwellDetectionConfiguration {
    // MARK: Cluster geometry (I1)

    /// Max great-circle distance (meters) from the locked/running centroid
    /// still treated as a tight place inlier.
    static let dwellRadiusMeters: Double = 40

    /// After this many accepted inliers, freeze the centroid so GPS drift
    /// cannot wander the cluster origin. Also frozen on promote-to-dwell.
    static let centroidLockSampleCount = 5

    // MARK: Confirmation gates (I1)

    /// Minimum wall-clock span of accepted inliers before `.dwelling`.
    /// Longer than a typical traffic light; shorter than a hangout.
    static let minimumDwellDuration: TimeInterval = 3 * 60

    /// Minimum accepted inliers before `.dwelling` (single fix never confirms).
    static let minimumSampleCount = 3

    // MARK: Quality gates (I1)

    /// Drop samples worse than this horizontal accuracy (meters).
    /// Stricter than the pipeline accept gate so dwells use cleaner fixes.
    static let maxHorizontalAccuracyMeters: Double = 50

    /// Reported ground speed above this (m/s) cannot join or start a cluster.
    static let maxSpeedMetersPerSecond: Double = 0.5

    // MARK: Candidate outlier tolerance (I1)

    /// Consecutive outside-radius samples allowed before exiting a *candidate*.
    /// Brief GPS blips must not reset start time on unconfirmed stops.
    static let maxConsecutiveOutliers = 2

    // MARK: Departure hysteresis (I2)

    /// Soft near-zone around a confirmed dwell (meters). Samples between
    /// `dwellRadiusMeters` and this value keep the user "at the place"
    /// (large venue / parking lot) and cancel any departure streak.
    static let departureRadiusMeters: Double = 100

    /// Minimum wall-clock span of sustained outside-zone evidence before
    /// confirming departure from an active dwell.
    static let minimumDepartureDuration: TimeInterval = 90

    /// Minimum consecutive outside-zone samples before confirming departure.
    static let minimumDepartureSampleCount = 3
}
