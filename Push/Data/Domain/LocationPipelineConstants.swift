//
//  LocationPipelineConstants.swift
//  Push
//
//  Phase 1 defaults only — values and semantic grouping.
//  Throttling / heartbeat execution lives in later issues.
//

import Foundation

/// Accuracy, movement throttle, heartbeat, Realtime coalesce, and observation-validation defaults.
enum LocationPipelineConstants {
    /// Minimum time between displacement-throttled presence uploads.
    static let minUploadInterval: TimeInterval = 60
    /// Minimum movement (meters) before a displacement-throttled upload.
    static let minDisplacementMeters: Double = 50
    /// Reject fixes with horizontal accuracy worse than this (meters).
    static let maxHorizontalAccuracyMeters: Double = 100
    /// Production re-touch window for stationary users (must be < hardExpire).
    static let presenceHeartbeatIntervalDefault: TimeInterval = 15 * 60
    /// DEBUG dogfood only (`--fast-presence-heartbeat`) — short enough to observe without a 15m wait.
    static let presenceHeartbeatIntervalDogfood: TimeInterval = 20
    /// Re-touch `expires_at` / freshness while stationary.
    /// DEBUG may inject a shorter interval for dogfood; Release always uses the default.
    static var presenceHeartbeatInterval: TimeInterval {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(
            LocationSessionLaunchArgument.fastPresenceHeartbeat
        ) {
            return presenceHeartbeatIntervalDogfood
        }
        #endif
        return presenceHeartbeatIntervalDefault
    }
    /// Coalesce Realtime presence patches into one store revision.
    static let realtimePatchDebounce: TimeInterval = 0.35

    // MARK: Observation validation (PR2 / Issue #68)

    /// Maximum age of a fix (`now - recordedAt`) still accepted.
    static let maxObservationAge: TimeInterval = 5 * 60
    /// Allow small future skew between device fix time and evaluation clock.
    static let futureTimestampTolerance: TimeInterval = 60
    /// Horizontal accuracy at or below this (with fresh age) → high confidence.
    static let highConfidenceAccuracyMeters: Double = 20
    /// Age at or below this with high-confidence accuracy → high confidence.
    static let highConfidenceMaxAge: TimeInterval = 30
    /// Max plausible ground speed between accepted fixes (m/s).
    /// ~90 m/s ≈ 324 km/h — allows highway vehicles with margin; rejects teleports.
    /// Documented beyond architecture doc defaults (architecture locked accuracy/throttle only).
    static let maxPlausibleSpeedMetersPerSecond: Double = 90
    /// Near-duplicate distance gate (meters) vs previous accepted fix.
    static let nearDuplicateDistanceMeters: Double = 1
    /// Near-duplicate time gate (seconds) vs previous accepted fix.
    static let nearDuplicateTimeInterval: TimeInterval = 1
    /// Mean Earth radius for great-circle distance (WGS84 spherical approximation).
    static let earthRadiusMeters: Double = 6_371_000

    // MARK: Session lifecycle (PR3 / Issue #69)

    /// Cap wait for best-effort unpublish during sign-out (never block logout forever).
    static let unpublishBestEffortTimeout: TimeInterval = 3

    /// ~1.1 km cells — Phase 1 default when writing / synthesizing vague coords.
    static let vagueCoordinateQuantumDegrees = 0.01
}

/// PushLog-safe location session codes only — never localized OS strings.
enum LocationSessionErrorCode {
    static let providerStartFailed = "location_provider_start_failed"
    static let upsertFailed = "location_upsert_failed"
    static let unpublishFailed = "location_unpublish_failed"
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
