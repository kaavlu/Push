//
//  PushRow.swift
//  Push
//

import Foundation

/// PostgREST row shape for `pushes`. Property names match the table's
/// snake_case columns directly so no `CodingKeys` are needed.
///
/// Timestamps are decoded as `String`/`String?`, not `Date`/`Date?`:
/// `JSONDecoder`'s default date strategy expects a numeric timestamp and
/// would fail to decode an ISO-8601 string, and real PostgREST responses use
/// fractional-second timestamps (e.g. "2026-07-13T11:24:18.230123+00:00").
/// Decoding as a plain string sidesteps the decoder's date strategy entirely
/// and lets the `parsed*()` helpers handle both forms explicitly.
struct PushRow: Decodable {
    let id: String
    let title: String
    let group_id: String?
    let creator_id: String
    let created_at: String
    let updated_at: String
    let starts_at: String
    let has_explicit_time: Bool
    let is_approximate_time: Bool
    let expires_at: String
    let cancelled_at: String?
    let place_id: String?
    let place_is_suggested: Bool
    let state: String
    let audience: String
    let note: String?
    let location_text: String?

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

    private static func parsedDate(_ raw: String) -> Date {
        isoFractional.date(from: raw) ?? isoPlain.date(from: raw) ?? Date(timeIntervalSince1970: 0)
    }

    private static func parsedOptionalDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return isoFractional.date(from: raw) ?? isoPlain.date(from: raw)
    }

    func pushPlan() -> PushPlan {
        PushPlan(
            id: id,
            title: title,
            groupID: group_id,
            creatorID: creator_id,
            createdAt: Self.parsedDate(created_at),
            updatedAt: Self.parsedDate(updated_at),
            startsAt: Self.parsedDate(starts_at),
            hasExplicitTime: has_explicit_time,
            isApproximateTime: is_approximate_time,
            expiresAt: Self.parsedDate(expires_at),
            cancelledAt: Self.parsedOptionalDate(cancelled_at),
            placeID: place_id,
            placeIsSuggested: place_is_suggested,
            state: PushPlan.State(rawValue: state) ?? .collecting,
            audience: mapAudience(audience),
            note: note,
            locationText: location_text
        )
    }

    // "invitees_only" isn't a valid Swift identifier, so Audience's rawValue
    // is camelCase (`inviteesOnly`) and can't round-trip through
    // `init(rawValue:)` — this explicit mapping bridges the two spellings.
    private func mapAudience(_ raw: String) -> PushPlan.Audience {
        switch raw {
        case "group": return .group
        default: return .inviteesOnly   // "invitees_only"
        }
    }
}
