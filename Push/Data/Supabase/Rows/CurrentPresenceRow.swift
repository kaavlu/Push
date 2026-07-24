//
//  CurrentPresenceRow.swift
//  Push
//
//  PostgREST row for `current_presence` (Issue #73 / architecture PR5).
//  Maps into existing `PresenceStatus` + synthetic `Place` — never a second
//  live-presence domain type. DTOs stay in the Supabase layer.
//

import Foundation

/// PostgREST row shape for `current_presence`. Property names match snake_case
/// columns so no `CodingKeys` are needed. Timestamps decode as `String` because
/// PostgREST returns ISO-8601 with fractional seconds.
struct CurrentPresenceRow: Decodable, Equatable {
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
}

// MARK: - Domain mapping

extension CurrentPresenceRow {

    /// Stable synthetic place id for Phase 1a (no places catalog).
    static func syntheticPlaceID(for userID: String) -> Place.ID {
        "presence-\(userID.lowercased())"
    }

    /// Maps a single row into domain presence, or `nil` if malformed.
    /// Does not apply viewer/expiry filters — use `friendVisibleStatuses`.
    func presenceStatus() -> PresenceStatus? {
        guard let observedAt = PushDateFormatting.parse(observed_at),
              let updatedAt = PushDateFormatting.parse(updated_at)
        else { return nil }

        guard areExactCoordsValid else { return nil }
        guard areVagueCoordsValid else { return nil }

        let placeID: Place.ID? = hasExactCoordinates
            ? Self.syntheticPlaceID(for: user_id)
            : nil

        return PresenceStatus(
            id: "presence-\(user_id.lowercased())",
            personID: user_id,
            availability: mapAvailability(availability),
            activity: PresenceActivity(name: activity_name, symbolName: activity_symbol),
            placeID: placeID,
            statusNote: status_note,
            confidence: mapConfidence(confidence),
            observedAt: observedAt,
            updatedAt: updatedAt,
            expiresAt: expires_at.flatMap(PushDateFormatting.parse),
            source: mapSource(source),
            isPublished: is_published
        )
    }

    /// Synthetic place for map builders when exact coordinates exist.
    /// Prefer server vague pair; otherwise round exact coords to ~0.01°.
    func syntheticPlace() -> Place? {
        guard let latitude, let longitude, hasExactCoordinates else { return nil }
        guard areExactCoordsValid, areVagueCoordsValid else { return nil }

        let (vagueLat, vagueLng) = resolvedVagueCoordinates(
            exactLat: latitude, exactLng: longitude
        )
        let label = Self.nearbyLabel
        let activityTrimmed = activity_name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = activityTrimmed.isEmpty ? label : activityTrimmed

        return Place(
            id: Self.syntheticPlaceID(for: user_id),
            name: displayName,
            shortName: displayName,
            address: Self.sharedLocationAddress,
            vagueLabel: label,
            latitude: latitude,
            longitude: longitude,
            vagueLatitude: vagueLat,
            vagueLongitude: vagueLng
        )
    }

    /// Friend-visible statuses for a viewer: drop hard-expired for everyone;
    /// drop unpublished (incl. legacy Ghost) for non-self; keep self unpublished
    /// for app state. Malformed rows are omitted.
    static func friendVisibleStatuses(
        from rows: [CurrentPresenceRow],
        viewerID: String,
        now: Date = Date()
    ) -> [PresenceStatus] {
        rows.compactMap { row in
            guard let status = row.presenceStatus() else { return nil }
            let isSelf = status.personID.caseInsensitiveCompare(viewerID) == .orderedSame
            switch status.freshnessState(at: now) {
            case .hardExpired:
                return nil
            case .unpublished:
                return isSelf ? status : nil
            case .fresh, .softStale:
                return status
            }
        }
    }

    /// Synthetic places for statuses that remain friend-visible (or self).
    static func syntheticPlaces(
        from rows: [CurrentPresenceRow],
        viewerID: String,
        now: Date = Date()
    ) -> [Place] {
        let visibleIDs = Set(
            friendVisibleStatuses(from: rows, viewerID: viewerID, now: now)
                .compactMap(\.placeID)
        )
        return rows.compactMap { row -> Place? in
            guard let place = row.syntheticPlace() else { return nil }
            guard visibleIDs.contains(place.id) else { return nil }
            return place
        }
    }

    // MARK: - Constants

    static let nearbyLabel = "Nearby"
    static let sharedLocationAddress = "Shared location"
    /// ~1.1 km cells — Phase 1 default when server omits vague pair.
    static let vagueCoordinateQuantumDegrees = 0.01
}

// MARK: - Private helpers

private extension CurrentPresenceRow {
    var hasExactCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var areExactCoordsValid: Bool {
        switch (latitude, longitude) {
        case (nil, nil):
            return true
        case let (lat?, lng?):
            return (-90...90).contains(lat) && (-180...180).contains(lng)
        default:
            // Pair integrity violated (should be impossible via DB constraints).
            return false
        }
    }

    var areVagueCoordsValid: Bool {
        switch (vague_latitude, vague_longitude) {
        case (nil, nil):
            return true
        case let (lat?, lng?):
            return (-90...90).contains(lat) && (-180...180).contains(lng)
        default:
            return false
        }
    }

    func resolvedVagueCoordinates(exactLat: Double, exactLng: Double) -> (Double, Double) {
        if let vague_latitude, let vague_longitude {
            return (vague_latitude, vague_longitude)
        }
        let q = Self.vagueCoordinateQuantumDegrees
        return (
            (exactLat / q).rounded() * q,
            (exactLng / q).rounded() * q
        )
    }

    func mapAvailability(_ raw: String) -> FriendAvailabilityState {
        switch raw {
        case "free_now": return .freeNow
        case "free_soon": return .freeSoon
        case "maybe_down": return .maybeDown
        case "busy": return .busy
        case "joinable": return .joinable
        case "driving": return .driving
        case "unavailable": return .unavailable
        case "ghost": return .ghost
        default: return .freeNow
        }
    }

    func mapConfidence(_ raw: String) -> PresenceStatus.Confidence {
        switch raw {
        case "high": return .high
        case "low": return .low
        default: return .medium
        }
    }

    func mapSource(_ raw: String) -> PresenceStatus.Source {
        switch raw {
        case "seed": return .seed
        case "manual_override": return .manualOverride
        case "inference": return .inference
        default: return .location
        }
    }
}
