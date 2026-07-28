//
//  PlaceCandidateRanker.swift
//  Push
//
//  Issue #101 (I3) — pure ranking of nearby place candidates for a dwell.
//  No MapKit, network, or UI.
//

import Foundation

/// Deterministic ranker over provider-fetched POIs.
enum PlaceCandidateRanker {
    /// Score, sort, and optionally select a confident place for the request.
    static func rank(
        request: PlaceResolutionRequest,
        payload: PlaceSearchPayload
    ) -> PlaceResolutionOutcome {
        let ranked = payload.candidates
            .compactMap { score(candidate: $0, request: request) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.distanceMeters != rhs.distanceMeters {
                    return lhs.distanceMeters < rhs.distanceMeters
                }
                return lhs.name < rhs.name
            }

        let status = selectionStatus(
            ranked: ranked,
            request: request,
            hasGeographicFallback: payload.geographicFallback != nil
        )
        let selected: ResolvedPlaceCandidate? = {
            guard status == .resolved, let top = ranked.first else { return nil }
            return top
        }()

        return PlaceResolutionOutcome(
            dwellSessionID: request.dwellSessionID,
            status: status,
            selected: selected,
            candidates: ranked,
            geographicFallback: payload.geographicFallback,
            resolvedAt: request.evaluationTime,
            centroidLatitude: request.centroidLatitude,
            centroidLongitude: request.centroidLongitude
        )
    }

    // MARK: - Scoring

    private static func score(
        candidate: UnrankedPlaceCandidate,
        request: PlaceResolutionRequest
    ) -> ResolvedPlaceCandidate? {
        let trimmed = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard candidate.latitude.isFinite, candidate.longitude.isFinite else { return nil }

        let distance = GeoDistance.meters(
            fromLatitude: request.centroidLatitude,
            longitude: request.centroidLongitude,
            toLatitude: candidate.latitude,
            longitude: candidate.longitude
        )

        let horizon = PlaceResolutionConfiguration.scoreDistanceHorizonMeters
        guard distance <= horizon else { return nil }

        var value = max(0, 1 - (distance / horizon))

        let likelyRadius = request.dwellRadiusMeters
            + max(0, request.representativeAccuracyMeters)
        if distance <= likelyRadius {
            value += PlaceResolutionConfiguration.insideLikelyAreaBoost
        } else {
            value *= PlaceResolutionConfiguration.outsideLikelyAreaPenalty
        }

        if let previous = request.previousResolvedPlaceID,
           previous == candidate.id
        {
            value += PlaceResolutionConfiguration.previousMatchBoost
        }

        if let category = candidate.category?.lowercased(),
           preferredCategories.contains(where: { category.contains($0) })
        {
            value += 0.04
        }

        // Soft ceiling above 1.0 so previous-match boost can still break ties
        // when both candidates would otherwise saturate at 1.0.
        let scoreCeiling = 1.0
            + PlaceResolutionConfiguration.previousMatchBoost
            + 0.05
        value = min(scoreCeiling, max(0, value))

        return ResolvedPlaceCandidate(
            id: candidate.id,
            name: trimmed,
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            category: candidate.category,
            distanceMeters: distance,
            score: value
        )
    }

    private static let preferredCategories: [String] = [
        "restaurant", "cafe", "coffee", "fitness", "gym", "store",
        "nightlife", "bakery", "brewery", "food",
    ]

    // MARK: - Selection

    private static func selectionStatus(
        ranked: [ResolvedPlaceCandidate],
        request: PlaceResolutionRequest,
        hasGeographicFallback: Bool
    ) -> PlaceResolutionStatus {
        guard let top = ranked.first else {
            return hasGeographicFallback ? .geographicOnly : .empty
        }

        let minScore = effectiveMinScore(accuracy: request.representativeAccuracyMeters)
        guard top.score >= minScore else {
            return hasGeographicFallback ? .geographicOnly : .empty
        }

        if let second = ranked.dropFirst().first {
            let margin = top.score - second.score
            if margin < PlaceResolutionConfiguration.ambiguityScoreDelta {
                return .ambiguous
            }
        }

        return .resolved
    }

    private static func effectiveMinScore(accuracy: Double) -> Double {
        var minScore = PlaceResolutionConfiguration.minScoreForSelection
        if accuracy > PlaceResolutionConfiguration.poorAccuracyMeters {
            minScore += PlaceResolutionConfiguration.poorAccuracyMinScoreLift
        }
        return min(0.95, minScore)
    }
}
