//
//  InMemoryDatabase+GroupLifecycle.swift
//  Push
//
//  Mock group lifecycle mutations mirroring 0015 SECURITY DEFINER RPC rules.
//

import Foundation

extension InMemoryDatabase {

    // MARK: - Rename / photo path

    func renameGroup(groupID: FriendGroup.ID, name: String) throws {
        try requireOwner(of: groupID)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GroupRepositoryError.invalidName }
        guard let existing = groupsByID[groupID] else {
            throw GroupRepositoryError.invalidTarget
        }
        replaceGroup(
            FriendGroup(id: existing.id, name: trimmed, imageAssetPath: existing.imageAssetPath)
        )
        didMutate()
    }

    func setGroupImagePath(groupID: FriendGroup.ID, imageAssetPath: String?) throws {
        try requireOwner(of: groupID)
        guard let existing = groupsByID[groupID] else {
            throw GroupRepositoryError.invalidTarget
        }
        replaceGroup(
            FriendGroup(id: existing.id, name: existing.name, imageAssetPath: imageAssetPath)
        )
        didMutate()
    }

    // MARK: - Invite / cancel

    /// Mock invite policy: skip self and rows that are already active/pending;
    /// invitees must exist in `peopleByID` (seed directory). Unknown IDs are
    /// skipped (not thrown). Does **not** require `acceptedFriendIDs` — more
    /// permissive than live `invite_to_group` so discoverable seed people work.
    func inviteToGroup(groupID: FriendGroup.ID, inviteeIDs: [Person.ID]) throws {
        try requireOwner(of: groupID)
        guard groupsByID[groupID] != nil else { throw GroupRepositoryError.invalidTarget }

        let now = Date()
        var inserted = false
        for inviteeID in inviteeIDs {
            if inviteeID == currentUserID { continue }
            guard peopleByID[inviteeID] != nil else { continue }
            if memberships.contains(where: {
                $0.groupID == groupID && $0.personID == inviteeID
            }) {
                continue
            }
            memberships.append(
                GroupMembership(
                    id: "membership-\(groupID)-\(inviteeID)",
                    personID: inviteeID,
                    groupID: groupID,
                    role: .member,
                    sharingLevel: .full,
                    membershipStatus: .invited,
                    joinedAt: now
                )
            )
            inserted = true
        }
        if inserted { didMutate() }
    }

    func cancelGroupInvite(membershipID: GroupMembership.ID) throws {
        guard let index = memberships.firstIndex(where: { $0.id == membershipID }) else {
            throw GroupRepositoryError.invalidTarget
        }
        let existing = memberships[index]
        try requireOwner(of: existing.groupID)
        guard existing.membershipStatus == .invited else {
            throw GroupRepositoryError.notPending
        }
        memberships.remove(at: index)
        didMutate()
    }

    // MARK: - Remove / leave

    func removeMember(groupID: FriendGroup.ID, personID: Person.ID) throws {
        try requireOwner(of: groupID)
        guard personID != currentUserID else { throw GroupRepositoryError.invalidTarget }
        guard let index = memberships.firstIndex(where: {
            $0.groupID == groupID && $0.personID == personID
        }) else {
            throw GroupRepositoryError.invalidTarget
        }
        let existing = memberships[index]
        guard existing.membershipStatus == .active else {
            throw GroupRepositoryError.invalidTarget
        }
        guard existing.role != .owner else { throw GroupRepositoryError.invalidTarget }
        memberships.remove(at: index)
        didMutate()
    }

    func leaveGroup(groupID: FriendGroup.ID) throws {
        guard let index = memberships.firstIndex(where: {
            $0.groupID == groupID && $0.personID == currentUserID
        }) else {
            throw GroupRepositoryError.notMember
        }
        let existing = memberships[index]
        guard existing.membershipStatus == .active else {
            throw GroupRepositoryError.notMember
        }

        if existing.role == .member {
            memberships.remove(at: index)
            didMutate()
            return
        }

        let activeCount = memberships.filter {
            $0.groupID == groupID && $0.membershipStatus == .active
        }.count
        if activeCount > 1 {
            throw GroupRepositoryError.transferRequired
        }

        purgeGroup(groupID)
        didMutate()
    }

    // MARK: - Transfer / delete

    func transferOwnership(groupID: FriendGroup.ID, newOwnerID: Person.ID) throws {
        try requireOwner(of: groupID)
        guard newOwnerID != currentUserID else { throw GroupRepositoryError.invalidTarget }
        guard let targetIndex = memberships.firstIndex(where: {
            $0.groupID == groupID && $0.personID == newOwnerID
        }) else {
            throw GroupRepositoryError.invalidTarget
        }
        let target = memberships[targetIndex]
        guard target.membershipStatus == .active else {
            throw GroupRepositoryError.invalidTarget
        }
        guard let selfIndex = memberships.firstIndex(where: {
            $0.groupID == groupID && $0.personID == currentUserID && $0.role == .owner
        }) else {
            throw GroupRepositoryError.notOwner
        }

        // Atomic demote + promote (never zero owners mid-mutation).
        memberships[selfIndex] = copyMembership(memberships[selfIndex], role: .member)
        memberships[targetIndex] = copyMembership(memberships[targetIndex], role: .owner)
        didMutate()
    }

    func deleteGroup(groupID: FriendGroup.ID) throws {
        try requireOwner(of: groupID)
        guard groupsByID[groupID] != nil else { throw GroupRepositoryError.invalidTarget }
        purgeGroup(groupID)
        didMutate()
    }

    // MARK: - Helpers

    private func requireOwner(of groupID: FriendGroup.ID) throws {
        let isOwner = memberships.contains {
            $0.groupID == groupID
                && $0.personID == currentUserID
                && $0.membershipStatus == .active
                && $0.role == .owner
        }
        guard isOwner else { throw GroupRepositoryError.notOwner }
    }

    private func replaceGroup(_ group: FriendGroup) {
        groupsByID[group.id] = group
        if let index = orderedGroups.firstIndex(where: { $0.id == group.id }) {
            orderedGroups[index] = group
        }
    }

    /// Hard-delete group + memberships; null `PushPlan.groupID` (mirrors FK SET NULL).
    private func purgeGroup(_ groupID: FriendGroup.ID) {
        groupsByID[groupID] = nil
        orderedGroups.removeAll { $0.id == groupID }
        memberships.removeAll { $0.groupID == groupID }

        let planIDs = plansByID.values
            .filter { $0.groupID == groupID }
            .map(\.id)
        for planID in planIDs {
            guard let existing = plansByID[planID] else { continue }
            let cleared = planClearingGroup(existing)
            plansByID[planID] = cleared
            if let index = orderedPlans.firstIndex(where: { $0.id == planID }) {
                orderedPlans[index] = cleared
            }
        }
    }

    private func copyMembership(
        _ membership: GroupMembership, role: GroupMembership.Role
    ) -> GroupMembership {
        GroupMembership(
            id: membership.id,
            personID: membership.personID,
            groupID: membership.groupID,
            role: role,
            sharingLevel: membership.sharingLevel,
            membershipStatus: membership.membershipStatus,
            joinedAt: membership.joinedAt
        )
    }

    private func planClearingGroup(_ plan: PushPlan) -> PushPlan {
        PushPlan(
            id: plan.id,
            title: plan.title,
            groupID: nil,
            creatorID: plan.creatorID,
            createdAt: plan.createdAt,
            updatedAt: plan.updatedAt,
            startsAt: plan.startsAt,
            hasExplicitTime: plan.hasExplicitTime,
            isApproximateTime: plan.isApproximateTime,
            expiresAt: plan.expiresAt,
            cancelledAt: plan.cancelledAt,
            placeID: plan.placeID,
            placeIsSuggested: plan.placeIsSuggested,
            state: plan.state,
            audience: plan.audience,
            note: plan.note,
            locationText: plan.locationText
        )
    }
}
