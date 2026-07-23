//
//  LocationPipelineConstants.swift
//  Push
//
//  Phase 1 defaults only — values and semantic grouping.
//  Throttling / heartbeat execution lives in later issues.
//

import Foundation

/// Accuracy, movement throttle, heartbeat, and Realtime coalesce defaults.
enum LocationPipelineConstants {
    /// Minimum time between displacement-throttled presence uploads.
    static let minUploadInterval: TimeInterval = 60
    /// Minimum movement (meters) before a displacement-throttled upload.
    static let minDisplacementMeters: Double = 50
    /// Reject fixes with horizontal accuracy worse than this (meters).
    static let maxHorizontalAccuracyMeters: Double = 100
    /// Re-touch `expires_at` / freshness while stationary (must be < hardExpire).
    static let presenceHeartbeatInterval: TimeInterval = 15 * 60
    /// Coalesce Realtime presence patches into one store revision.
    static let realtimePatchDebounce: TimeInterval = 0.35
}

/// Soft-stale vs hard-expiry windows for friend-visible presence.
enum PresenceFreshness {
    /// Soften relative copy / confidence only; still map-visible if policy allows and published.
    static let softStale: TimeInterval = 15 * 60
    /// Hard expiry window written to `expires_at` on each successful publish/heartbeat.
    static let hardExpire: TimeInterval = 60 * 60

    /// Classifies a presence row for pipeline filtering and presentation.
    static func classify(
        isEffectivelyPublished: Bool,
        updatedAt: Date,
        expiresAt: Date?,
        now: Date = Date()
    ) -> PresenceFreshnessState {
        if !isEffectivelyPublished {
            return .unpublished
        }
        if let expiresAt, expiresAt <= now {
            return .hardExpired
        }
        let age = now.timeIntervalSince(updatedAt)
        if age >= softStale {
            return .softStale
        }
        return .fresh
    }
}

/// Friend-visibility / presentation class for a presence row.
enum PresenceFreshnessState: String, Codable, Sendable, Equatable {
    /// Age < soft-stale, not expired, published — normal map path.
    case fresh
    /// Age ≥ soft-stale, still published and not hard-expired — still visible; soften copy only.
    case softStale
    /// `expiresAt <= now` — not friend-visible.
    case hardExpired
    /// Ghost / unpublished (including legacy `.ghost` availability mapping).
    case unpublished

    /// Whether friends may see this presence (subject to `SharingPolicy`).
    var isFriendVisible: Bool {
        switch self {
        case .fresh, .softStale:
            return true
        case .hardExpired, .unpublished:
            return false
        }
    }
}

/// Why a presence sync write was scheduled.
/// Movement is displacement-throttled; other triggers bypass 60s/50m GPS noise control.
enum PresenceSyncTrigger: String, Codable, Sendable, Equatable {
    case movement
    case heartbeat
    case unpublish
    case republish
    case availabilityChange
    case permissionRevoked
    case sessionShutdown
    case firstEligibleStart
    case sharingPolicyReduced

    /// Bypasses min-interval + min-displacement movement throttle.
    /// Heartbeat still spaces itself via `presenceHeartbeatInterval`.
    var bypassesMovementThrottle: Bool {
        switch self {
        case .movement:
            return false
        case .heartbeat, .unpublish, .republish, .availabilityChange,
             .permissionRevoked, .sessionShutdown, .firstEligibleStart,
             .sharingPolicyReduced:
            return true
        }
    }
}
