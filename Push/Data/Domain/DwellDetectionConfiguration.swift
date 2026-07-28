//
//  DwellDetectionConfiguration.swift
//  Push
//
//  Issue #99 (I1) — centralized thresholds for deterministic dwell detection.
//

import Foundation

/// Thresholds for local dwell detection. All magic numbers for the detector live here.
enum DwellDetectionConfiguration {
    // MARK: Cluster geometry

    /// Max great-circle distance (meters) from the locked/running centroid
    /// still treated as the same place.
    static let dwellRadiusMeters: Double = 40

    /// After this many accepted inliers, freeze the centroid so GPS drift
    /// cannot wander the cluster origin. Also frozen on promote-to-dwell.
    static let centroidLockSampleCount = 5

    // MARK: Confirmation gates

    /// Minimum wall-clock span of accepted inliers before `.dwelling`.
    /// Longer than a typical traffic light; shorter than a hangout.
    static let minimumDwellDuration: TimeInterval = 3 * 60

    /// Minimum accepted inliers before `.dwelling` (single fix never confirms).
    static let minimumSampleCount = 3

    // MARK: Quality gates

    /// Drop samples worse than this horizontal accuracy (meters).
    /// Stricter than the pipeline accept gate so dwells use cleaner fixes.
    static let maxHorizontalAccuracyMeters: Double = 50

    /// Reported ground speed above this (m/s) cannot join or start a cluster.
    static let maxSpeedMetersPerSecond: Double = 0.5

    // MARK: Outlier tolerance

    /// Consecutive outside-radius samples allowed before exiting candidate/dwell.
    /// Brief GPS blips must not reset start time or end a confirmed dwell.
    static let maxConsecutiveOutliers = 2
}
