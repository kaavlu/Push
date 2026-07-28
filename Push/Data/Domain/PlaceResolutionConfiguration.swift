//
//  PlaceResolutionConfiguration.swift
//  Push
//
//  Issue #101 (I3) — thresholds for place search, ranking, and lookup cadence.
//

import Foundation

/// Centralized thresholds for dwell → place resolution.
enum PlaceResolutionConfiguration {
    // MARK: Search

    /// MapKit POI search radius around the dwell centroid (meters).
    static let searchRadiusMeters: Double = 120

    // MARK: Ranking / selection

    /// Minimum score required to auto-select a named POI.
    static let minScoreForSelection: Double = 0.72

    /// If the runner-up is within this score of the leader, treat as ambiguous.
    static let ambiguityScoreDelta: Double = 0.12

    /// Distance at which the distance component of the score reaches zero.
    static let scoreDistanceHorizonMeters: Double = 150

    /// Extra score for a candidate matching the previous confirmed place id.
    static let previousMatchBoost: Double = 0.12

    /// Soft boost when the candidate lies inside dwell radius + accuracy.
    static let insideLikelyAreaBoost: Double = 0.08

    /// Multiplier when the candidate is beyond likely area (still in search radius).
    static let outsideLikelyAreaPenalty: Double = 0.45

    /// Accuracy above this (meters) makes selection stricter (higher min score).
    static let poorAccuracyMeters: Double = 40

    /// Added to min score when representative accuracy is poor.
    static let poorAccuracyMinScoreLift: Double = 0.08

    // MARK: Session cadence

    /// Re-resolve when the locked centroid moves at least this far (meters).
    static let centroidChangeReresolveMeters: Double = 25

    /// Max resolve attempts per dwell session (arrival + retries + centroid moves
    /// each count; failures count toward this budget).
    static let maxResolveAttemptsPerDwell = 3
}
