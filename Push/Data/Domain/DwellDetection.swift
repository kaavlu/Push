//
//  DwellDetection.swift
//  Push
//
//  Issue #99 (I1) / #100 (I2) — domain types for local dwell detection and
//  arrival/departure lifecycle. Parallel to activity inference; does not own
//  presence drafts or labels.
//

import Foundation

// MARK: - Phase

/// Incremental cluster state for a single user location stream.
enum DwellPhase: String, Codable, Sendable, Equatable, CaseIterable {
    /// Not building a dwell (transit, cold start, or after departure).
    case moving
    /// Low-motion cluster forming; not yet confirmed.
    case candidateDwell
    /// Confirmed dwell with a stable centroid (post-arrival).
    case dwelling
}

// MARK: - Transitions (I2)

/// Edge-triggered lifecycle events. Emitted at most once per process() call,
/// and at most once per dwell for each kind (arrival / departure).
enum DwellTransition: String, Codable, Sendable, Equatable, CaseIterable {
    /// Candidate just promoted to a confirmed dwell.
    case arrived
    /// Confirmed dwell ended after departure hysteresis.
    case departed
}

// MARK: - Cluster snapshot

/// Place-cluster metrics shared by candidate and confirmed dwells.
/// Internal pipeline type — not friend-facing copy or a venue.
struct DwellClusterSnapshot: Codable, Equatable, Sendable {
    let centroidLatitude: Double
    let centroidLongitude: Double
    /// First accepted inlier of this cluster.
    let startedAt: Date
    /// Most recent sample still attributed to the place.
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

// MARK: - Lifecycle session (I2)

/// One dwell stay with arrival/departure bounds for downstream place resolution.
struct DwellLifecycleSession: Codable, Equatable, Sendable {
    /// Stable id for this stay (deterministic from start + centroid seed).
    let id: String
    let centroidLatitude: Double
    let centroidLongitude: Double
    /// First accepted inlier of the underlying cluster.
    let startedAt: Date
    /// When the dwell was confirmed (arrival event time).
    let arrivedAt: Date
    /// When departure hysteresis completed; `nil` while still dwelling.
    let departedAt: Date?
    let lastConfirmedAt: Date
    let sampleCount: Int
    let representativeAccuracyMeters: Double

    var isComplete: Bool { departedAt != nil }

    /// Full stay span from first inlier through departure (or last confirm if open).
    var sessionDuration: TimeInterval {
        let end = departedAt ?? lastConfirmedAt
        return max(0, end.timeIntervalSince(startedAt))
    }

    /// Confirmed dwell span from arrival through departure (or last confirm if open).
    var confirmedDuration: TimeInterval {
        let end = departedAt ?? lastConfirmedAt
        return max(0, end.timeIntervalSince(arrivedAt))
    }

    init(
        id: String,
        centroidLatitude: Double,
        centroidLongitude: Double,
        startedAt: Date,
        arrivedAt: Date,
        departedAt: Date?,
        lastConfirmedAt: Date,
        sampleCount: Int,
        representativeAccuracyMeters: Double
    ) {
        self.id = id
        self.centroidLatitude = centroidLatitude
        self.centroidLongitude = centroidLongitude
        self.startedAt = startedAt
        self.arrivedAt = arrivedAt
        self.departedAt = departedAt
        self.lastConfirmedAt = lastConfirmedAt
        self.sampleCount = sampleCount
        self.representativeAccuracyMeters = representativeAccuracyMeters
    }

    static func makeID(
        startedAt: Date,
        latitude: Double,
        longitude: Double
    ) -> String {
        let t = Int(startedAt.timeIntervalSince1970)
        // Coarse quantize so id is stable across tiny float noise in tests/logs.
        let lat = Int((latitude * 1e5).rounded())
        let lon = Int((longitude * 1e5).rounded())
        return "dwell-\(t)-\(lat)-\(lon)"
    }
}

// MARK: - State

/// Latest detector output after processing zero or more observations.
struct DwellDetectionState: Codable, Equatable, Sendable {
    let phase: DwellPhase
    /// Present for `.candidateDwell` and `.dwelling`.
    let cluster: DwellClusterSnapshot?
    /// Edge-triggered; non-nil only on the process() that crossed the boundary.
    let transition: DwellTransition?
    /// Live stay while phase is `.dwelling`.
    let activeSession: DwellLifecycleSession?
    /// Most recently completed stay (venue-resolution seam). Cleared on reset.
    let lastCompletedSession: DwellLifecycleSession?

    static let moving = DwellDetectionState(
        phase: .moving,
        cluster: nil,
        transition: nil,
        activeSession: nil,
        lastCompletedSession: nil
    )

    init(
        phase: DwellPhase,
        cluster: DwellClusterSnapshot?,
        transition: DwellTransition? = nil,
        activeSession: DwellLifecycleSession? = nil,
        lastCompletedSession: DwellLifecycleSession? = nil
    ) {
        self.phase = phase
        self.transition = transition
        self.lastCompletedSession = lastCompletedSession
        switch phase {
        case .moving:
            self.cluster = nil
            self.activeSession = nil
        case .candidateDwell:
            self.cluster = cluster
            self.activeSession = nil
        case .dwelling:
            self.cluster = cluster
            self.activeSession = activeSession
        }
    }

    var isDwelling: Bool { phase == .dwelling }

    var confirmedDwell: DwellClusterSnapshot? {
        phase == .dwelling ? cluster : nil
    }
}

// MARK: - Detector protocol

/// Pure / injectable seam for incremental dwell detection + lifecycle.
/// Implementations must stay free of Core Location, network I/O, and UI.
protocol DwellDetecting: Sendable {
    /// Latest phase + cluster + lifecycle after all processed observations.
    var state: DwellDetectionState { get }

    /// Consume one observation and return the updated state.
    mutating func process(
        _ observation: LocationObservation,
        at evaluationTime: Date
    ) -> DwellDetectionState

    /// Drop all cluster and session memory (session shutdown / test isolation).
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
