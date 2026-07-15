//
//  PushRecipientResolver.swift
//  Push
//
//  Shared Start Push recipient-token parsing, used by both the mock and
//  Supabase push repositories so create/update behave identically
//  regardless of backend.
//

import Foundation

enum PushRecipientResolver {
    struct Parsed {
        let groupIDs: [FriendGroup.ID]
        let friendIDs: [Person.ID]

        /// A push whose only recipient is a single group is backed by that
        /// group (`audience == .group`); anything else is `.inviteesOnly`.
        var singleGroupOnly: Bool { groupIDs.count == 1 && friendIDs.isEmpty }
    }

    /// Recipient tokens are "group_<id>" / "friend_<id>" (see `PushDraft`).
    static func parse(_ recipientIDs: Set<String>) -> Parsed {
        let groupIDs = recipientIDs.compactMap { token in
            token.hasPrefix("group_") ? String(token.dropFirst("group_".count)) : nil
        }
        let friendIDs = recipientIDs.compactMap { token in
            token.hasPrefix("friend_") ? String(token.dropFirst("friend_".count)) : nil
        }
        return Parsed(groupIDs: groupIDs, friendIDs: friendIDs)
    }

    /// Selected friends plus active members of any selected groups, deduped,
    /// with the creator excluded (they get an explicit `.in` response elsewhere).
    static func invitees(
        groupIDs: [FriendGroup.ID],
        friendIDs: [Person.ID],
        memberships: [GroupMembership],
        creatorID: Person.ID
    ) -> Set<Person.ID> {
        let groupMemberIDs = memberships
            .filter { $0.membershipStatus == .active && groupIDs.contains($0.groupID) }
            .map(\.personID)
        var invitees = Set(friendIDs).union(groupMemberIDs)
        invitees.remove(creatorID)
        return invitees
    }
}
