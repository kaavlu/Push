//
//  GroupMembershipRow.swift
//  Push
//

import Foundation

/// PostgREST row shape for `group_memberships`. Property names match the
/// table's snake_case columns directly so no `CodingKeys` are needed.
///
/// `joined_at` is decoded as `String`, not `Date`: `JSONDecoder`'s default
/// date strategy expects a numeric timestamp and would fail to decode an
/// ISO-8601 string, and real PostgREST responses use fractional-second
/// timestamps (e.g. "2026-07-13T11:24:18.230123+00:00"). Decoding as a
/// plain string sidesteps the decoder's date strategy entirely and lets
/// `parsedJoinedAt()` handle both forms explicitly.
struct GroupMembershipRow: Decodable {
    let id: String
    let person_id: String
    let group_id: String
    let role: String
    let membership_status: String
    let joined_at: String

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

    // Day-1 UI never displays joinedAt, so the epoch fallback for
    // unparseable input is acceptable — it never surfaces to the user.
    private func parsedJoinedAt() -> Date {
        Self.isoFractional.date(from: joined_at)
            ?? Self.isoPlain.date(from: joined_at)
            ?? Date(timeIntervalSince1970: 0)
    }

    func membership() -> GroupMembership {
        GroupMembership(
            id: id,
            personID: person_id,
            groupID: group_id,
            role: GroupMembership.Role(rawValue: role) ?? .member,
            sharingLevel: .full,   // R3: membership carries no visibility; sharing_policies is the sole source.
            membershipStatus: GroupMembership.Status(rawValue: membership_status) ?? .active,
            joinedAt: parsedJoinedAt()
        )
    }
}
