//
//  GroupInviteRow.swift
//  Push
//

import Foundation

/// Return shape of the `incoming_group_invites()` RPC. Property names match
/// the function's declared output columns directly so no `CodingKeys` are
/// needed. `inviter_id`/`inviter_first_name`/`inviter_image` are optional
/// because the left join degrades gracefully if a group's owner membership
/// is ever missing (should not happen in practice, but the SQL allows it).
struct GroupInviteRow: Decodable {
    let membership_id: String
    let group_id: String
    let group_name: String
    let image_asset_path: String?
    let inviter_id: String?
    let inviter_first_name: String?
    let inviter_image: String?
    let member_count: Int
    let created_at: String

    // Same rationale as `GroupMembershipRow.parsedJoinedAt()`: PostgREST emits
    // fractional-second ISO-8601 timestamps; try that form first, then plain.
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

    private func parsedCreatedAt() -> Date {
        Self.isoFractional.date(from: created_at)
            ?? Self.isoPlain.date(from: created_at)
            ?? Date(timeIntervalSince1970: 0)
    }

    func groupInvite() -> GroupInvite {
        GroupInvite(
            id: membership_id,
            groupID: group_id,
            groupName: group_name,
            imageAssetPath: image_asset_path,
            inviterID: inviter_id ?? "",
            inviterName: inviter_first_name ?? "",
            inviterImageAssetPath: inviter_image,
            memberCount: member_count,
            createdAt: parsedCreatedAt()
        )
    }
}
