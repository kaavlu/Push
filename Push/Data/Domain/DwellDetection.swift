//
//  DwellDetection.swift
//  Push
//
//  Issue #99 (I1) — domain types for local dwell detection.
//  Parallel to activity inference; does not own presence drafts or labels.
//

import Foundation

// MARK: - Phase

/// Incremental dwell lifecycle for a single user location stream.
enum DwellPhase: String, Codable, Sendable, Equatable, CaseIterable {
    /// Not building a dwell (transit, cold start, or exited).
    case moving
    /// Low-motion cluster forming; not yet confirmed.
    case candidateDwell
    /// Confirmed dwell with a stable centroid.
    case dwelling
}

// MARK: - Cluster snapshot

/// Place-cluster metrics shared by candidate and confirmed dwells.
/// Internal pipeline type — not friend-facing copy or a venue.
struct DwellClusterSnapshot: Codable, Equatable, Sendable {
    let centroidLatitude: Double
    let centroidLongitude: Double
    /// First accepted inlier of this cluster.
    let startedAt: Date
    /// Most recent accepted inlier.
    let lastConfirmedAt: Date
    /// Accepted inliers only (outliers and quality-dropped samples excluded).
    let sampleCount: Int
    /// Mean horizontal accuracy of accepted inliers (meters).
    let representativeAccuracyMeters: Double

    /// Wall-clock span of accepted inliers.
    var duration: TimeInterval {
        max(0, lastConfirmedAt.timeIntervalSince(startedAt))
    }

    init(
        centroidLatitude: Double,
        centroidLongitude: Double,
        startedAt: Date,
        lastConfirmedAt: Date,
        sampleCount: Int,
        representativeAccuracyMeters: Double
    ) {
        self.centroidLatitude = centroidLatitude
        self.centroidLongitude = centroidLongitude
        self.startedAt = startedAt
        self.lastConfirmedAt = lastConfirmedAt
        self.sampleCount = sampleCount
        self.representativeAccuracyMeters = representativeAccuracyMeters
    }
}

// MARK: - State

/// Latest detector output after processing zero or more observations.
struct DwellDetectionState: Codable, Equatable, Sendable {
    let phase: DwellPhase
    /// Present for `.candidateDwell` and `.dwelling`.
    let cluster: DwellClusterSnapshot?

    static let moving = DwellDetectionState(phase: .moving, cluster: nil)

    init(phase: DwellPhase, cluster: DwellClusterSnapshot?) {
        self.phase = phase
        switch phase {
        case .moving:
            self.cluster = nil
        case .candidateDwell, .dwelling:
            self.cluster = cluster
        }
    }

    /// Convenience when phase is known to carry a cluster.
    var isDwelling: Bool { phase == .dwelling }

    var confirmedDwell: DwellClusterSnapshot? {
        phase == .dwelling ? cluster : nil
    }
}

// MARK: - Detector protocol

/// Pure / injectable seam for incremental dwell detection.
/// Implementations must stay free of Core Location, network I/O, and UI.
protocol DwellDetecting: Sendable {
    /// Latest phase + cluster after all processed observations.
    var state: DwellDetectionState { get }

    /// Consume one observation and return the updated state.
    mutating func process(
        _ observation: LocationObservation,
        at evaluationTime: Date
    ) -> DwellDetectionState

    /// Drop all cluster memory (session shutdown / test isolation).
    mutating func reset()
}

// MARK: - No-op

/// Always stays `.moving`. Useful for tests that disable dwell tracking.
struct NoOpDwellDetector: DwellDetecting {
    private(set) var state: DwellDetectionState = .moving

    mutating func process(
        _ observation: LocationObservation,
        at evaluationTime: Date
    ) -> DwellDetectionState {
        _ = observation
        _ = evaluationTime
        return state
    }

    mutating func reset() {
        state = .moving
    }
}
