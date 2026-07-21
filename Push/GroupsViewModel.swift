//
//  GroupsViewModel.swift
//  Push
//
//  Groups list + detail state and lifecycle mutations with ActionErrorState + retry.
//

import Combine
import Foundation
import UIKit

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published private(set) var groups: [PushGroupData] = []
    @Published private(set) var selectedGroupID: String?
    @Published private(set) var presentedGroupID: String?
    @Published private(set) var loadState: LoadState<[PushGroupData]> = .idle
    /// Recoverable mutation error with Retry via `retryActionError`.
    @Published private(set) var actionError: ActionErrorState?

    private let container: AppDataContainer?
    /// Test/seam override for mutations (and optional load isolation).
    private let groupsOverride: GroupRepository?
    private var membersByGroupID: [String: [PushGroupMemberData]] = [:]
    /// Raw memberships from the last successful `load()` — owner / invite helpers.
    private var cachedMemberships: [GroupMembership] = []
    private var cachedFriends: [Person] = []
    private var currentUserID: String = ""
    private var storeChangeSub: AnyCancellable?
    private var lastSeenRevision = 0
    /// Session-only photos (Add Group + in-flight photo updates).
    private var sessionImages: [String: UIImage] = [:]
    private var pendingAction: PendingGroupAction?

    private var groupRepo: GroupRepository? { groupsOverride ?? container?.groups }

    private enum PendingGroupAction {
        case rename(groupID: String, name: String)
        case updatePhoto(groupID: String, jpegData: Data)
        case removePhoto(groupID: String)
        case invite(groupID: String, friendIDs: [String])
        case cancelInvite(membershipID: String)
        case removeMember(groupID: String, personID: String)
        case leave(groupID: String)
        case transfer(groupID: String, newOwnerID: String)
        case delete(groupID: String)
    }

    // `container` defaults via `?? .shared` (not `= .shared`) — `.shared` is a
    // MainActor mutable static; fallback must live in the initializer body.
    init(container: AppDataContainer? = nil, groups: GroupRepository? = nil) {
        let container = container ?? .shared
        self.container = container
        self.groupsOverride = groups
        Task { await load() }
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
    }

    /// Preview/test seam. Optional `groupsRepository` for mutation failure tests.
    init(groups: [PushGroupData], groupsRepository: GroupRepository? = nil) {
        container = nil
        groupsOverride = groupsRepository
        self.groups = groups
        selectedGroupID = groups.first?.id
        loadState = .loaded(groups)
    }

    func load() async {
        guard let container else { return }
        if loadState.value == nil { loadState = .loading }
        do {
            let groupList = try await container.groups.groups()
            let memberships = try await container.groups.memberships()
            let statuses = try await container.friends.presenceStatuses()
            let plans = try await container.pushes.activePlans()
            let friendList = try await container.friends.friends()
            let user = try await container.friends.currentUser()
            let places = try await container.pushes.allPlaces()

            let statusesByPersonID = Dictionary(
                uniqueKeysWithValues: statuses.map { ($0.personID, $0) }
            )
            let peopleByID = Dictionary(
                uniqueKeysWithValues: (friendList + [user]).map { ($0.id, $0) }
            )
            let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
            let now = Date()
            let cards = GroupContentBuilder.groupCards(
                groups: groupList,
                memberships: memberships,
                statuses: statusesByPersonID,
                plans: plans,
                now: now
            )
            membersByGroupID = Dictionary(uniqueKeysWithValues: groupList.map { group in
                (
                    group.id,
                    GroupContentBuilder.members(
                        groupID: group.id,
                        memberships: memberships,
                        people: peopleByID,
                        statuses: statusesByPersonID,
                        places: placesByID,
                        now: now
                    )
                )
            })
            cachedMemberships = memberships
            cachedFriends = friendList
            currentUserID = user.id
            groups = cards
            if selectedGroupID == nil { selectedGroupID = cards.first?.id }
            loadState = .loaded(cards)
            lastSeenRevision = container.storeRevision
        } catch {
            loadState = .failed(error)
        }
    }

    func stats(for group: PushGroupData) -> [PushGroupStat] {
        [
            PushGroupStat(id: "active-now", value: group.activeNowCount, label: "Active now"),
            PushGroupStat(id: "nearby", value: group.nearbyCount, label: "Nearby"),
            PushGroupStat(id: "plans", value: group.planCount, label: "Pushes")
        ]
    }

    func isSelected(_ group: PushGroupData) -> Bool {
        selectedGroupID == group.id
    }

    func select(_ group: PushGroupData) {
        selectedGroupID = group.id
    }

    func openDetail(for group: PushGroupData) {
        selectedGroupID = group.id
        presentedGroupID = group.id
    }

    func closeDetail() {
        presentedGroupID = nil
    }

    func group(for id: String?) -> PushGroupData? {
        groups.first { $0.id == id }
    }

    func members(for group: PushGroupData) -> [PushGroupMemberData] {
        membersByGroupID[group.id] ?? []
    }

    /// Active membership for the signed-in user in `groupID`, if any.
    func currentUserMembership(in groupID: String) -> GroupMembership? {
        cachedMemberships.first {
            $0.groupID == groupID
                && $0.personID == currentUserID
                && $0.membershipStatus == .active
        }
    }

    func isCurrentUserOwner(of groupID: String) -> Bool {
        currentUserMembership(in: groupID)?.role == .owner
    }

    /// Direct friends who are neither active nor pending in `groupID`.
    func inviteCandidates(for groupID: String) -> [Person] {
        let occupied = Set(
            cachedMemberships
                .filter {
                    $0.groupID == groupID
                        && ($0.membershipStatus == .active || $0.membershipStatus == .invited)
                }
                .map(\.personID)
        )
        return cachedFriends.filter { !occupied.contains($0.id) }
    }

    /// Registers a picked photo for `id` so its detail view can show it this
    /// session even though it was never uploaded anywhere.
    func registerSessionImage(_ image: UIImage?, forGroupID id: String) {
        guard let image else { return }
        sessionImages[id] = image
    }

    func sessionImage(for group: PushGroupData) -> UIImage? {
        sessionImages[group.id]
    }

    // MARK: - Lifecycle mutations

    func dismissActionError() {
        actionError = nil
    }

    func retryActionError() async {
        guard let pendingAction else { return }
        switch pendingAction {
        case .rename(let groupID, let name):
            await renameGroup(groupID: groupID, name: name)
        case .updatePhoto(let groupID, let jpegData):
            await updateGroupPhoto(groupID: groupID, jpegData: jpegData)
        case .removePhoto(let groupID):
            await removeGroupPhoto(groupID: groupID)
        case .invite(let groupID, let friendIDs):
            await inviteFriends(groupID: groupID, friendIDs: friendIDs)
        case .cancelInvite(let membershipID):
            await cancelInvite(membershipID: membershipID)
        case .removeMember(let groupID, let personID):
            await removeMember(groupID: groupID, personID: personID)
        case .leave(let groupID):
            await leaveGroup(groupID: groupID)
        case .transfer(let groupID, let newOwnerID):
            await transferOwnership(groupID: groupID, newOwnerID: newOwnerID)
        case .delete(let groupID):
            await deleteGroup(groupID: groupID)
        }
    }

    func renameGroup(groupID: String, name: String) async {
        guard let groupRepo else { return }
        let previousName = groups.first { $0.id == groupID }?.name
        applyOptimisticName(groupID: groupID, name: name)
        do {
            try await groupRepo.renameGroup(groupID: groupID, name: name)
            await finishSuccess()
        } catch {
            if let previousName {
                applyOptimisticName(groupID: groupID, name: previousName)
            }
            fail(
                .rename(groupID: groupID, name: name),
                message: GroupsMutationCopy.renameFailed
            )
            await load()
        }
    }

    func updateGroupPhoto(groupID: String, jpegData: Data) async {
        guard let groupRepo else { return }
        let previousSession = sessionImages[groupID]
        if let image = UIImage(data: jpegData) {
            sessionImages[groupID] = image
        }
        do {
            try await groupRepo.updateGroupPhoto(groupID: groupID, jpegData: jpegData)
            await finishSuccess()
            // Remote path is on the card after load; drop the in-flight override.
            sessionImages.removeValue(forKey: groupID)
        } catch {
            if let previousSession {
                sessionImages[groupID] = previousSession
            } else {
                sessionImages.removeValue(forKey: groupID)
            }
            fail(
                .updatePhoto(groupID: groupID, jpegData: jpegData),
                message: GroupsMutationCopy.photoUpdateFailed
            )
        }
    }

    func removeGroupPhoto(groupID: String) async {
        guard let groupRepo else { return }
        let previousSession = sessionImages[groupID]
        sessionImages.removeValue(forKey: groupID)
        do {
            try await groupRepo.removeGroupPhoto(groupID: groupID)
            await finishSuccess()
        } catch {
            if let previousSession {
                sessionImages[groupID] = previousSession
            }
            fail(
                .removePhoto(groupID: groupID),
                message: GroupsMutationCopy.photoRemoveFailed
            )
        }
    }

    func inviteFriends(groupID: String, friendIDs: [String]) async {
        guard let groupRepo else { return }
        do {
            try await groupRepo.inviteToGroup(groupID: groupID, inviteeIDs: friendIDs)
            await finishSuccess()
        } catch {
            fail(
                .invite(groupID: groupID, friendIDs: friendIDs),
                message: GroupsMutationCopy.inviteFailed
            )
        }
    }

    func cancelInvite(membershipID: String) async {
        guard let groupRepo else { return }
        do {
            try await groupRepo.cancelGroupInvite(membershipID: membershipID)
            await finishSuccess()
        } catch {
            fail(
                .cancelInvite(membershipID: membershipID),
                message: GroupsMutationCopy.cancelInviteFailed
            )
        }
    }

    func removeMember(groupID: String, personID: String) async {
        guard let groupRepo else { return }
        do {
            try await groupRepo.removeMember(groupID: groupID, personID: personID)
            await finishSuccess()
        } catch {
            let name = membersByGroupID[groupID]?.first { $0.id == personID }?.name
            let message = name.map { "Couldn't remove \($0). Try again." }
                ?? GroupsMutationCopy.removeMemberFailed
            fail(.removeMember(groupID: groupID, personID: personID), message: message)
        }
    }

    func leaveGroup(groupID: String) async {
        guard let groupRepo else { return }
        do {
            try await groupRepo.leaveGroup(groupID: groupID)
            await finishSuccess(closeDetail: true)
        } catch {
            fail(.leave(groupID: groupID), message: GroupsMutationCopy.leaveFailed)
        }
    }

    func transferOwnership(groupID: String, newOwnerID: String) async {
        guard let groupRepo else { return }
        do {
            try await groupRepo.transferOwnership(groupID: groupID, newOwnerID: newOwnerID)
            await finishSuccess()
        } catch {
            fail(
                .transfer(groupID: groupID, newOwnerID: newOwnerID),
                message: GroupsMutationCopy.transferFailed
            )
        }
    }

    func deleteGroup(groupID: String) async {
        guard let groupRepo else { return }
        do {
            try await groupRepo.deleteGroup(groupID: groupID)
            await finishSuccess(closeDetail: true)
        } catch {
            fail(.delete(groupID: groupID), message: GroupsMutationCopy.deleteFailed)
        }
    }

    // MARK: - Mutation helpers

    private func finishSuccess(closeDetail: Bool = false) async {
        lastSeenRevision = container?.storeRevision ?? lastSeenRevision
        actionError = nil
        pendingAction = nil
        if closeDetail { self.closeDetail() }
        await load()
    }

    private func fail(_ action: PendingGroupAction, message: String) {
        pendingAction = action
        actionError = ActionErrorState(message: message)
    }

    private func applyOptimisticName(groupID: String, name: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let g = groups[index]
        groups[index] = PushGroupData(
            id: g.id,
            name: name,
            memberCount: g.memberCount,
            memberIDs: g.memberIDs,
            status: g.status,
            activeNowCount: g.activeNowCount,
            nearbyCount: g.nearbyCount,
            planCount: g.planCount,
            imageAssetName: g.imageAssetName,
            fallbackSymbol: g.fallbackSymbol,
            fallbackInitials: g.fallbackInitials
        )
    }
}

private enum GroupsMutationCopy {
    static let renameFailed = "Couldn't rename the group. Try again."
    static let photoUpdateFailed = "Couldn't update the photo. Try again."
    static let photoRemoveFailed = "Couldn't remove the photo. Try again."
    static let inviteFailed = "Couldn't send invites. Try again."
    static let cancelInviteFailed = "Couldn't cancel the invite. Try again."
    static let removeMemberFailed = "Couldn't remove that member. Try again."
    static let leaveFailed = "Couldn't leave the group. Try again."
    static let transferFailed = "Couldn't transfer ownership. Try again."
    static let deleteFailed = "Couldn't delete the group. Try again."
}
