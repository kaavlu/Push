//
//  GroupDetailHost.swift
//  Push
//
//  Wires GroupDetailView to GroupsViewModel mutation methods. Keeps
//  FriendsView / GroupsView free of long closure boilerplate.
//

import SwiftUI

struct GroupDetailHost: View {
    @ObservedObject var viewModel: GroupsViewModel
    let group: PushGroupData
    let onStartPush: () -> Void

    var body: some View {
        let groupID = group.id
        GroupDetailView(
            group: group,
            members: viewModel.members(for: group),
            isOwner: viewModel.isCurrentUserOwner(of: groupID),
            sessionImage: viewModel.sessionImage(for: group),
            inviteCandidates: viewModel.inviteCandidates(for: groupID),
            actionError: viewModel.actionError,
            onStartPush: onStartPush,
            backAction: { viewModel.closeDetail() },
            onDismissError: { viewModel.dismissActionError() },
            onRetryError: { Task { await viewModel.retryActionError() } },
            onRename: { name in
                Task { await viewModel.renameGroup(groupID: groupID, name: name) }
            },
            onUpdatePhoto: { data in
                Task { await viewModel.updateGroupPhoto(groupID: groupID, jpegData: data) }
            },
            onRemovePhoto: {
                Task { await viewModel.removeGroupPhoto(groupID: groupID) }
            },
            onInvite: { ids in
                Task { await viewModel.inviteFriends(groupID: groupID, friendIDs: ids) }
            },
            onCancelInvite: { membershipID in
                Task { await viewModel.cancelInvite(membershipID: membershipID) }
            },
            onRemoveMember: { personID in
                Task { await viewModel.removeMember(groupID: groupID, personID: personID) }
            },
            onLeave: {
                Task { await viewModel.leaveGroup(groupID: groupID) }
            },
            onTransfer: { newOwnerID in
                Task {
                    await viewModel.transferOwnership(
                        groupID: groupID,
                        newOwnerID: newOwnerID
                    )
                }
            },
            onDelete: {
                Task { await viewModel.deleteGroup(groupID: groupID) }
            }
        )
    }
}
