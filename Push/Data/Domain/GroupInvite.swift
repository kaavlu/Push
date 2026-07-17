//
//  GroupInvite.swift
//  Push
//

import Foundation

/// A pending invite to join a group, surfaced on Alerts under "Group Requests".
/// Enriched (group name/image, inviter identity, member count) because the
/// invitee can't yet read the group directly — `private.is_group_member`
/// only counts `active` memberships, so `incoming_group_invites()` hands
/// over everything the row needs up front.
struct GroupInvite: Identifiable, Equatable {
    let id: String            // membership id
    let groupID: String
    let groupName: String
    let imageAssetPath: String?
    let inviterID: String
    let inviterName: String
    let inviterImageAssetPath: String?
    let memberCount: Int
    let createdAt: Date
}
