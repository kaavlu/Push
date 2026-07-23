//
//  LocationTracking.swift
//  Push
//
//  Authorization + runtime tracking surface for settings/UI and LocationSession.
//

import Foundation

/// OS authorization projection (app-owned; not `CLAuthorizationStatus`).
enum LocationAuthorizationState: String, Codable, Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case whenInUse
    /// Phase 1 may only request when-in-use; always is reserved for later.
    case always

    /// Whether the OS would allow foreground location updates.
    var allowsWhenInUseUpdates: Bool {
        switch self {
        case .whenInUse, .always:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        }
    }
}

/// What level of permission the session should request.
enum LocationAuthorizationRequest: String, Codable, Sendable, Equatable {
    case whenInUse
    // case always — not Phase 1
}

/// App-owned scene phase for location lifetime (avoids SwiftUI import in domain).
enum LocationLifecyclePhase: String, Codable, Sendable, Equatable {
    case active
    case inactive
    case background
}

/// Runtime tracking + publish surface owned by `LocationSessioning`.
struct LocationTrackingState: Equatable, Sendable {
    var authorization: LocationAuthorizationState
    /// User intent + signed in + auth OK (not merely OS authorization).
    var isTrackingEnabled: Bool
    /// Orthogonal Ghost off when true. Independent of availability.
    var isPresencePublishingEnabled: Bool
    var lastObservation: LocationObservation?
    var lastAcceptedAt: Date?
    var lastUploadAt: Date?
    /// `PushLog`-safe code, never a localized OS string.
    var lastErrorCode: String?

    init(
        authorization: LocationAuthorizationState = .notDetermined,
        isTrackingEnabled: Bool = false,
        isPresencePublishingEnabled: Bool = true,
        lastObservation: LocationObservation? = nil,
        lastAcceptedAt: Date? = nil,
        lastUploadAt: Date? = nil,
        lastErrorCode: String? = nil
    ) {
        self.authorization = authorization
        self.isTrackingEnabled = isTrackingEnabled
        self.isPresencePublishingEnabled = isPresencePublishingEnabled
        self.lastObservation = lastObservation
        self.lastAcceptedAt = lastAcceptedAt
        self.lastUploadAt = lastUploadAt
        self.lastErrorCode = lastErrorCode
    }

    /// Eligible to start GPS consumption and presence publish (not Ghost).
    var isEligibleToPublish: Bool {
        isTrackingEnabled
            && isPresencePublishingEnabled
            && authorization.allowsWhenInUseUpdates
    }
}
