//
//  PresenceStatus.swift
//  Push
//

import Foundation

struct PresenceActivity: Codable, Equatable {
    let name: String
    let symbolName: String
}

/// Canonical internal presence — what Push knows. Exactly one per person.
/// UI never consumes this directly; it consumes `VisiblePresence` after
/// sharing-policy resolution.
struct PresenceStatus: Identifiable, Codable, Equatable {
    enum Confidence: String, Codable { case high, medium, low }
    enum Source: String, Codable { case seed, location, manualOverride, inference }

    let id: String
    let personID: Person.ID
    let availability: FriendAvailabilityState
    let activity: PresenceActivity
    let placeID: Place.ID?
    let statusNote: String?
    let confidence: Confidence
    let observedAt: Date
    let updatedAt: Date
    let expiresAt: Date?
    let source: Source
}
