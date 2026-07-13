//
//  SharingPolicyRow.swift
//  Push
//

import Foundation

/// PostgREST row shape for `sharing_policies` — the SINGLE source of truth
/// for presence visibility (R3). Property names match the table's
/// snake_case columns directly so no `CodingKeys` are needed.
///
/// `expires_at` is decoded as `String?`, not `Date?`: `JSONDecoder`'s default
/// date strategy expects a numeric timestamp and would fail to decode an
/// ISO-8601 string, and real PostgREST responses use fractional-second
/// timestamps (e.g. "2026-07-13T11:24:18.230123+00:00"). Decoding as a
/// plain optional string sidesteps the decoder's date strategy entirely and
/// lets `parsedExpiresAt()` handle both forms explicitly.
struct SharingPolicyRow: Decodable {
    let id: String
    let owner_person_id: String
    let audience_type: String
    let audience_id: String?
    let location_visibility: String
    let activity_visibility: String
    let availability_visibility: String
    let expires_at: String?

    // PostgREST returns fractional-second timestamps in production, but
    // fixtures/tests commonly use the plain form — try fractional first,
    // then fall back to plain, so both are handled without guessing.
    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // expiresAt is optional in the domain model, so an unparseable value
    // should fall back to nil (no expiry) rather than an epoch sentinel.
    private func parsedExpiresAt() -> Date? {
        guard let expires_at else { return nil }
        return Self.isoFractional.date(from: expires_at)
            ?? Self.isoPlain.date(from: expires_at)
    }

    func policy() -> SharingPolicy {
        SharingPolicy(
            id: id,
            ownerPersonID: owner_person_id,
            audienceType: mapAudience(audience_type),
            audienceID: audience_id,
            locationVisibility: SharingPolicy.LocationVisibility(rawValue: location_visibility) ?? .hidden,
            activityVisibility: SharingPolicy.DetailVisibility(rawValue: activity_visibility) ?? .hidden,
            availabilityVisibility: SharingPolicy.AvailabilityVisibility(rawValue: availability_visibility) ?? .hidden,
            expiresAt: parsedExpiresAt()
        )
    }

    // "global_default" isn't a valid Swift identifier, so AudienceType's
    // rawValue is camelCase (`globalDefault`) and can't round-trip through
    // `init(rawValue:)` — this explicit mapping bridges the two spellings.
    private func mapAudience(_ raw: String) -> SharingPolicy.AudienceType {
        switch raw {
        case "friend": return .friend
        case "group": return .group
        default: return .globalDefault   // "global_default"
        }
    }
}
