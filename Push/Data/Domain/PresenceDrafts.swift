//
//  PresenceDrafts.swift
//  Push
//
//  Pipeline intermediates between validated fixes and canonical PresenceStatus.
//

import Foundation

/// Accepted observation after accuracy/age/teleport validation.
struct ValidatedObservation: Sendable, Equatable {
    let observation: LocationObservation
    let confidence: PresenceStatus.Confidence
}

/// Optional Phase 1.5+ enrichment before writing PresenceStatus.
/// Phase 1 inferrer builds drafts without rich venue/ML kinds.
struct InferredActivity: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case stationaryVenue
        case walking
        case driving
        case unknown
    }

    let name: String
    let symbolName: String
    let confidence: PresenceStatus.Confidence
    let placeID: Place.ID?
    let kind: Kind
}

/// Pre-persist presence write payload. Availability is mirrored from profile —
/// never invented from location, and never Ghost (Ghost is `isPublished`).
/// Coordinates are app-owned Doubles (not Core Location types).
struct PresenceStatusDraft: Equatable, Sendable {
    var availability: FriendAvailabilityState
    var isPublished: Bool
    var activity: PresenceActivity
    var placeID: Place.ID?
    var statusNote: String?
    var latitude: Double?
    var longitude: Double?
    var vagueLatitude: Double?
    var vagueLongitude: Double?
    var confidence: PresenceStatus.Confidence
    var observedAt: Date
    var source: PresenceStatus.Source

    init(
        availability: FriendAvailabilityState,
        isPublished: Bool,
        activity: PresenceActivity,
        placeID: Place.ID? = nil,
        statusNote: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        vagueLatitude: Double? = nil,
        vagueLongitude: Double? = nil,
        confidence: PresenceStatus.Confidence,
        observedAt: Date,
        source: PresenceStatus.Source
    ) {
        self.availability = availability
        self.isPublished = isPublished
        self.activity = activity
        self.placeID = placeID
        self.statusNote = statusNote
        self.latitude = latitude
        self.longitude = longitude
        self.vagueLatitude = vagueLatitude
        self.vagueLongitude = vagueLongitude
        self.confidence = confidence
        self.observedAt = observedAt
        self.source = source
    }

    /// Published drafts need a valid exact coordinate pair before network upsert.
    var hasExactCoordinates: Bool {
        guard let latitude, let longitude else { return false }
        return (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
