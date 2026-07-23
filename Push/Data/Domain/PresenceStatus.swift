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
///
/// Ghost is **not** availability. Target model uses orthogonal `isPublished`.
/// Legacy `FriendAvailabilityState.ghost` still exists for Profile/persistence
/// transition; use `isEffectivelyPublished` for friend-visibility decisions.
struct PresenceStatus: Identifiable, Codable, Equatable {
    enum Confidence: String, Codable { case high, medium, low }
    enum Source: String, Codable { case seed, location, manualOverride, inference }

    let id: String
    let personID: Person.ID
    /// Social free/busy chip — **not** Ghost. Ghost is `isPublished`.
    let availability: FriendAvailabilityState
    /// Orthogonal publish kill-switch. When false, friends must not see this presence.
    let isPublished: Bool
    let activity: PresenceActivity
    let placeID: Place.ID?
    let statusNote: String?
    let confidence: Confidence
    let observedAt: Date
    let updatedAt: Date
    let expiresAt: Date?
    let source: Source

    init(
        id: String,
        personID: Person.ID,
        availability: FriendAvailabilityState,
        activity: PresenceActivity,
        placeID: Place.ID?,
        statusNote: String?,
        confidence: Confidence,
        observedAt: Date,
        updatedAt: Date,
        expiresAt: Date?,
        source: Source,
        isPublished: Bool = true
    ) {
        self.id = id
        self.personID = personID
        self.availability = availability
        self.isPublished = isPublished
        self.activity = activity
        self.placeID = placeID
        self.statusNote = statusNote
        self.confidence = confidence
        self.observedAt = observedAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.source = source
    }

    /// Friend-visible publish flag after legacy Ghost mapping.
    /// - Explicit `isPublished == false` → unpublished.
    /// - Transitional: availability `.ghost` still means unpublished even if
    ///   `isPublished` was left true by older writers.
    var isEffectivelyPublished: Bool {
        guard isPublished else { return false }
        if availability == .ghost { return false }
        return true
    }

    /// Classifies freshness for friend-visible pipeline filtering / copy.
    func freshnessState(at now: Date = Date()) -> PresenceFreshnessState {
        PresenceFreshness.classify(
            isEffectivelyPublished: isEffectivelyPublished,
            updatedAt: updatedAt,
            expiresAt: expiresAt,
            now: now
        )
    }
}
