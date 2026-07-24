//
//  PresencePublishPolicy.swift
//  Push
//
//  Pure publish decisions for movement throttle + stationary heartbeat.
//  No I/O — LocationSession owns when to call PresenceSyncing.
//

import Foundation

/// Snapshot of the last successful presence write used by throttle / heartbeat.
struct PresencePublishSnapshot: Equatable, Sendable {
    /// Wall time of the last successful presence write (upsert or heartbeat).
    var lastSuccessfulWriteAt: Date?
    /// Coordinates included in that write (nil after unpublish / never written).
    var lastUploadedLatitude: Double?
    var lastUploadedLongitude: Double?
    /// False until the first eligible accepted fix is published (firstEligibleStart).
    var hasCompletedFirstEligiblePublish: Bool

    init(
        lastSuccessfulWriteAt: Date? = nil,
        lastUploadedLatitude: Double? = nil,
        lastUploadedLongitude: Double? = nil,
        hasCompletedFirstEligiblePublish: Bool = false
    ) {
        self.lastSuccessfulWriteAt = lastSuccessfulWriteAt
        self.lastUploadedLatitude = lastUploadedLatitude
        self.lastUploadedLongitude = lastUploadedLongitude
        self.hasCompletedFirstEligiblePublish = hasCompletedFirstEligiblePublish
    }

    var hasUploadedCoordinates: Bool {
        lastUploadedLatitude != nil && lastUploadedLongitude != nil
    }
}

/// Why a location-derived publish should (or should not) hit the network.
enum PresencePublishDecision: Equatable, Sendable {
    case publish(PresenceSyncTrigger)
    case skip
}

/// Displacement throttle + heartbeat schedule (architecture §2.5).
enum PresencePublishPolicy {
    /// Movement path: first eligible fix, or ≥60s **and** (≥50m or no prior coords).
    static func decisionForMovement(
        observation: LocationObservation,
        now: Date,
        snapshot: PresencePublishSnapshot
    ) -> PresencePublishDecision {
        // Bootstrap / Ghost-off resume with no successful write yet.
        if !snapshot.hasCompletedFirstEligiblePublish || snapshot.lastSuccessfulWriteAt == nil {
            return .publish(.firstEligibleStart)
        }

        guard let lastAt = snapshot.lastSuccessfulWriteAt else {
            return .publish(.firstEligibleStart)
        }

        let elapsed = now.timeIntervalSince(lastAt)
        guard elapsed >= LocationPipelineConstants.minUploadInterval else {
            return .skip
        }

        // No prior coords (edge) → treat as first upload of a position.
        guard
            let lastLat = snapshot.lastUploadedLatitude,
            let lastLng = snapshot.lastUploadedLongitude
        else {
            return .publish(.movement)
        }

        let distance = GeoDistance.meters(
            fromLatitude: lastLat,
            longitude: lastLng,
            toLatitude: observation.latitude,
            longitude: observation.longitude
        )
        if distance >= LocationPipelineConstants.minDisplacementMeters {
            return .publish(.movement)
        }
        return .skip
    }

    /// Stationary heartbeat: re-touch when ≥15m since last successful write.
    static func decisionForHeartbeat(
        now: Date,
        snapshot: PresencePublishSnapshot
    ) -> PresencePublishDecision {
        guard snapshot.hasCompletedFirstEligiblePublish,
              let lastAt = snapshot.lastSuccessfulWriteAt
        else {
            return .skip
        }
        let elapsed = now.timeIntervalSince(lastAt)
        if elapsed >= LocationPipelineConstants.presenceHeartbeatInterval {
            return .publish(.heartbeat)
        }
        return .skip
    }

    /// Applies a successful write into the snapshot (movement or heartbeat).
    static func recordingSuccessfulWrite(
        on snapshot: PresencePublishSnapshot,
        at now: Date,
        latitude: Double?,
        longitude: Double?
    ) -> PresencePublishSnapshot {
        var next = snapshot
        next.lastSuccessfulWriteAt = now
        next.hasCompletedFirstEligiblePublish = true
        if let latitude, let longitude {
            next.lastUploadedLatitude = latitude
            next.lastUploadedLongitude = longitude
        }
        return next
    }

    /// Clears upload bookkeeping after unpublish (Ghost / permission / auth).
    static func recordingUnpublish(
        on snapshot: PresencePublishSnapshot
    ) -> PresencePublishSnapshot {
        var next = snapshot
        next.lastSuccessfulWriteAt = nil
        next.lastUploadedLatitude = nil
        next.lastUploadedLongitude = nil
        // Next eligible fix should publish immediately (firstEligibleStart / republish).
        next.hasCompletedFirstEligiblePublish = false
        return next
    }
}
