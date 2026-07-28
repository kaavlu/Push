//
//  PlaceResolution.swift
//  Push
//
//  Issue #101 (I3) — resolve confirmed dwell centroids to nearby places.
//  Domain types only (Doubles); MapKit stays in infrastructure.
//  Friend-facing “At …” composition lives in ActivityInferencePresentation (#105).
//

import Foundation

// MARK: - Request

/// Inputs for a single place-resolution attempt against a confirmed dwell.
struct PlaceResolutionRequest: Equatable, Sendable {
    let dwellSessionID: String
    let centroidLatitude: Double
    let centroidLongitude: Double
    let representativeAccuracyMeters: Double
    let dwellRadiusMeters: Double
    /// Last confidently selected place id for this user (soft boost), if any.
    let previousResolvedPlaceID: String?
    let evaluationTime: Date

    init(
        dwellSessionID: String,
        centroidLatitude: Double,
        centroidLongitude: Double,
        representativeAccuracyMeters: Double,
        dwellRadiusMeters: Double = DwellDetectionConfiguration.dwellRadiusMeters,
        previousResolvedPlaceID: String? = nil,
        evaluationTime: Date
    ) {
        self.dwellSessionID = dwellSessionID
        self.centroidLatitude = centroidLatitude
        self.centroidLongitude = centroidLongitude
        self.representativeAccuracyMeters = representativeAccuracyMeters
        self.dwellRadiusMeters = dwellRadiusMeters
        self.previousResolvedPlaceID = previousResolvedPlaceID
        self.evaluationTime = evaluationTime
    }

    /// Build a request from an active dwell session snapshot.
    init(
        session: DwellLifecycleSession,
        previousResolvedPlaceID: String? = nil,
        evaluationTime: Date
    ) {
        self.init(
            dwellSessionID: session.id,
            centroidLatitude: session.centroidLatitude,
            centroidLongitude: session.centroidLongitude,
            representativeAccuracyMeters: session.representativeAccuracyMeters,
            dwellRadiusMeters: DwellDetectionConfiguration.dwellRadiusMeters,
            previousResolvedPlaceID: previousResolvedPlaceID,
            evaluationTime: evaluationTime
        )
    }
}

// MARK: - Candidate

/// One nearby POI candidate before or after ranking.
struct ResolvedPlaceCandidate: Codable, Equatable, Sendable {
    /// Stable provider id when available; otherwise a deterministic synthetic key.
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    /// Provider category string (e.g. MapKit POI category raw value); optional.
    let category: String?
    /// Great-circle distance from the dwell centroid (meters).
    let distanceMeters: Double
    /// Ranker score in `0...1` (higher is better).
    let score: Double

    init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        category: String?,
        distanceMeters: Double,
        score: Double
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.distanceMeters = distanceMeters
        self.score = score
    }
}

// MARK: - Geographic fallback

/// Human-readable reverse-geocode context when no POI is confidently selected.
/// Not a business identity — neighborhood / street level only.
struct GeographicPlaceContext: Codable, Equatable, Sendable {
    /// Best single label (locality, neighborhood, or thoroughfare).
    let displayName: String
    let locality: String?
    let thoroughfare: String?
    let administrativeArea: String?

    init(
        displayName: String,
        locality: String? = nil,
        thoroughfare: String? = nil,
        administrativeArea: String? = nil
    ) {
        self.displayName = displayName
        self.locality = locality
        self.thoroughfare = thoroughfare
        self.administrativeArea = administrativeArea
    }
}

// MARK: - Outcome

enum PlaceResolutionStatus: String, Codable, Sendable, Equatable, CaseIterable {
    /// One confident named POI selected.
    case resolved
    /// Multiple plausible POIs — no automatic selection.
    case ambiguous
    /// No confident POI; reverse-geocode context only.
    case geographicOnly
    /// Nothing useful to attach.
    case empty
}

/// Structured result attached to an active dwell (internal pipeline).
struct PlaceResolutionOutcome: Codable, Equatable, Sendable {
    let dwellSessionID: String
    let status: PlaceResolutionStatus
    /// Set only when status is `.resolved` (confidence sufficient).
    let selected: ResolvedPlaceCandidate?
    /// Ranked candidates (best first). May be non-empty when ambiguous.
    let candidates: [ResolvedPlaceCandidate]
    let geographicFallback: GeographicPlaceContext?
    let resolvedAt: Date
    let centroidLatitude: Double
    let centroidLongitude: Double

    /// Named place safe to surface later only when confidently resolved.
    var confidentPlaceName: String? {
        guard status == .resolved else { return nil }
        return selected?.name
    }

    init(
        dwellSessionID: String,
        status: PlaceResolutionStatus,
        selected: ResolvedPlaceCandidate?,
        candidates: [ResolvedPlaceCandidate],
        geographicFallback: GeographicPlaceContext?,
        resolvedAt: Date,
        centroidLatitude: Double,
        centroidLongitude: Double
    ) {
        self.dwellSessionID = dwellSessionID
        self.status = status
        self.selected = selected
        self.candidates = candidates
        self.geographicFallback = geographicFallback
        self.resolvedAt = resolvedAt
        self.centroidLatitude = centroidLatitude
        self.centroidLongitude = centroidLongitude
    }
}

// MARK: - Raw search payload (pre-rank)

/// Provider-fetched POIs before pure ranking.
struct PlaceSearchPayload: Equatable, Sendable {
    let candidates: [UnrankedPlaceCandidate]
    let geographicFallback: GeographicPlaceContext?

    init(
        candidates: [UnrankedPlaceCandidate] = [],
        geographicFallback: GeographicPlaceContext? = nil
    ) {
        self.candidates = candidates
        self.geographicFallback = geographicFallback
    }
}

struct UnrankedPlaceCandidate: Equatable, Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let category: String?

    init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        category: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
    }
}

// MARK: - Protocol

/// Injectable place lookup. Implementations may use MapKit / network; domain
/// callers only see Doubles and strings.
protocol PlaceResolving: Sendable {
    func resolve(_ request: PlaceResolutionRequest) async throws -> PlaceResolutionOutcome
}

// MARK: - No-op

/// Never contacts a provider. Mock default — presence pipeline unchanged.
struct NoOpPlaceResolver: PlaceResolving {
    func resolve(_ request: PlaceResolutionRequest) async throws -> PlaceResolutionOutcome {
        PlaceResolutionOutcome(
            dwellSessionID: request.dwellSessionID,
            status: .empty,
            selected: nil,
            candidates: [],
            geographicFallback: nil,
            resolvedAt: request.evaluationTime,
            centroidLatitude: request.centroidLatitude,
            centroidLongitude: request.centroidLongitude
        )
    }
}

// MARK: - Fixed (tests)

/// Returns a canned payload run through the pure ranker.
struct FixedPlaceResolver: PlaceResolving {
    var payload: PlaceSearchPayload
    /// When non-nil, `resolve` throws instead of ranking.
    var error: Error?

    init(payload: PlaceSearchPayload = PlaceSearchPayload(), error: Error? = nil) {
        self.payload = payload
        self.error = error
    }

    func resolve(_ request: PlaceResolutionRequest) async throws -> PlaceResolutionOutcome {
        if let error { throw error }
        return PlaceCandidateRanker.rank(request: request, payload: payload)
    }
}

enum PlaceResolutionError: Error, Equatable {
    case providerFailed
    case cancelled
}
