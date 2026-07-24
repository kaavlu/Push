//
//  CurrentPresenceWriteMapping.swift
//  Push
//
//  Draft → PostgREST upsert payload for `current_presence` (Issue #75).
//  Keeps snake_case encoding and availability/source mapping out of the buffer.
//

import Foundation

/// Upsert body for `current_presence`. Property names match table columns.
/// Optional fields always encode (including null) so clear-on-unpublish works
/// when a full row is replaced via write-through from the returned select.
struct CurrentPresenceUpsertPayload: Encodable, Equatable {
    let user_id: String
    let availability: String
    let is_published: Bool
    let activity_name: String
    let activity_symbol: String
    let place_id: String?
    let status_note: String?
    let latitude: Double?
    let longitude: Double?
    let vague_latitude: Double?
    let vague_longitude: Double?
    let confidence: String
    let observed_at: String
    let updated_at: String
    let expires_at: String?
    let source: String

    private enum CodingKeys: String, CodingKey {
        case user_id, availability, is_published
        case activity_name, activity_symbol, place_id, status_note
        case latitude, longitude, vague_latitude, vague_longitude
        case confidence, observed_at, updated_at, expires_at, source
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(availability, forKey: .availability)
        try container.encode(is_published, forKey: .is_published)
        try container.encode(activity_name, forKey: .activity_name)
        try container.encode(activity_symbol, forKey: .activity_symbol)
        try container.encode(place_id, forKey: .place_id)
        try container.encode(status_note, forKey: .status_note)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(vague_latitude, forKey: .vague_latitude)
        try container.encode(vague_longitude, forKey: .vague_longitude)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(observed_at, forKey: .observed_at)
        try container.encode(updated_at, forKey: .updated_at)
        try container.encode(expires_at, forKey: .expires_at)
        try container.encode(source, forKey: .source)
    }
}

enum CurrentPresenceWriteMapping {
    /// Build a publish upsert. Requires exact coordinates when `isPublished`.
    static func payload(
        userID: String,
        draft: PresenceStatusDraft,
        now: Date = Date()
    ) -> CurrentPresenceUpsertPayload {
        let expiresAt: Date? = draft.isPublished
            ? now.addingTimeInterval(PresenceFreshness.hardExpire)
            : now
        let (vagueLat, vagueLng) = resolvedVague(
            exactLat: draft.latitude,
            exactLng: draft.longitude,
            vagueLat: draft.vagueLatitude,
            vagueLng: draft.vagueLongitude
        )
        return CurrentPresenceUpsertPayload(
            user_id: userID.lowercased(),
            availability: availabilityRaw(draft.availability),
            is_published: draft.isPublished,
            activity_name: draft.activity.name,
            activity_symbol: draft.activity.symbolName,
            place_id: draft.placeID,
            status_note: draft.statusNote,
            latitude: draft.isPublished ? draft.latitude : nil,
            longitude: draft.isPublished ? draft.longitude : nil,
            vague_latitude: draft.isPublished ? vagueLat : nil,
            vague_longitude: draft.isPublished ? vagueLng : nil,
            confidence: confidenceRaw(draft.confidence),
            observed_at: PushDateFormatting.string(draft.observedAt),
            updated_at: PushDateFormatting.string(now),
            expires_at: expiresAt.map(PushDateFormatting.string),
            source: sourceRaw(draft.source)
        )
    }

    /// Local cache row after successful `unpublish_current_presence` RPC.
    static func unpublishedRow(
        from existing: CurrentPresenceRow?,
        userID: String,
        now: Date = Date()
    ) -> CurrentPresenceRow {
        let nowString = PushDateFormatting.string(now)
        if let existing {
            return CurrentPresenceRow(
                user_id: existing.user_id,
                availability: existing.availability,
                is_published: false,
                activity_name: existing.activity_name,
                activity_symbol: existing.activity_symbol,
                place_id: existing.place_id,
                status_note: existing.status_note,
                latitude: nil,
                longitude: nil,
                vague_latitude: nil,
                vague_longitude: nil,
                confidence: existing.confidence,
                observed_at: existing.observed_at,
                updated_at: nowString,
                expires_at: nowString,
                source: existing.source
            )
        }
        return CurrentPresenceRow(
            user_id: userID.lowercased(),
            availability: "free_now",
            is_published: false,
            activity_name: "",
            activity_symbol: "",
            place_id: nil,
            status_note: nil,
            latitude: nil,
            longitude: nil,
            vague_latitude: nil,
            vague_longitude: nil,
            confidence: "medium",
            observed_at: nowString,
            updated_at: nowString,
            expires_at: nowString,
            source: "location"
        )
    }

    static func availabilityRaw(_ availability: FriendAvailabilityState) -> String {
        switch availability {
        case .freeNow: return "free_now"
        case .freeSoon: return "free_soon"
        case .maybeDown: return "maybe_down"
        case .busy: return "busy"
        case .joinable: return "joinable"
        case .driving: return "driving"
        case .unavailable: return "unavailable"
        case .ghost: return "ghost"
        }
    }

    static func confidenceRaw(_ confidence: PresenceStatus.Confidence) -> String {
        switch confidence {
        case .high: return "high"
        case .medium: return "medium"
        case .low: return "low"
        }
    }

    static func sourceRaw(_ source: PresenceStatus.Source) -> String {
        switch source {
        case .seed: return "seed"
        case .location: return "location"
        case .manualOverride: return "manual_override"
        case .inference: return "inference"
        }
    }

    private static func resolvedVague(
        exactLat: Double?,
        exactLng: Double?,
        vagueLat: Double?,
        vagueLng: Double?
    ) -> (Double?, Double?) {
        if let vagueLat, let vagueLng { return (vagueLat, vagueLng) }
        guard let exactLat, let exactLng else { return (nil, nil) }
        let q = LocationPipelineConstants.vagueCoordinateQuantumDegrees
        return ((exactLat / q).rounded() * q, (exactLng / q).rounded() * q)
    }
}
