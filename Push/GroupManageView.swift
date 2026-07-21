//
//  GroupManageView.swift
//  Push
//
//  Group settings page: invite / transfer / leave / delete. Opened from
//  Group Detail’s Manage button. Top bar matches cream-page chrome: title
//  leading, glass X trailing (same control as Friends / Profile modals).
//

import SwiftUI

struct GroupManageView: View {
    @Environment(\.pushLayout) private var layout

    let isOwner: Bool
    let canTransfer: Bool
    let inviteCandidates: [Person]
    let transferCandidates: [PushGroupMemberData]
    let actionError: ActionErrorState?

    let dismissAction: () -> Void
    let onDismissError: () -> Void
    let onRetryError: () -> Void
    let onInvite: ([String]) -> Void
    let onTransfer: (String) -> Void
    let onLeave: () -> Void
    let onDelete: () -> Void

    @State private var isInvitePresented = false
    @State private var isTransferPresented = false
    @State private var isLeaveConfirmPresented = false
    @State private var isDeleteConfirmPresented = false
    @State private var pendingTransferMember: PushGroupMemberData?
    @State private var memberPendingTransfer: PushGroupMemberData?

    var body: some View {
        ZStack {
            FriendsBackground()
            ScrollView(showsIndicators: false) {
                GroupDetailManageSection(
                    isOwner: isOwner,
                    canTransfer: canTransfer,
                    onInvite: { isInvitePresented = true },
                    onTransfer: { isTransferPresented = true },
                    onLeave: { isLeaveConfirmPresented = true },
                    onDelete: { isDeleteConfirmPresented = true }
                )
                .padding(.horizontal, GroupDetailLayout.horizontalPadding)
                .padding(.top, GroupDetailLayout.topPadding)
                .padding(.bottom, GroupDetailLayout.bottomPadding)
            }
        }
        .safeAreaInset(edge: .top) {
            GroupManageHeaderBar(onClose: dismissAction)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let actionError {
                ActionErrorBanner(
                    message: actionError.message,
                    onRetry: onRetryError,
                    onDismiss: onDismissError
                )
                .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
                .padding(.bottom, FriendsLayout.bottomPadding(layout))
            }
        }
        .sheet(isPresented: $isInvitePresented) {
            GroupInviteSheet(candidates: inviteCandidates, onInvite: onInvite)
        }
        .sheet(isPresented: $isTransferPresented, onDismiss: {
            if let member = pendingTransferMember {
                pendingTransferMember = nil
                memberPendingTransfer = member
            }
        }) {
            GroupTransferSheet(candidates: transferCandidates) { member in
                pendingTransferMember = member
            }
        }
        .confirmationDialog(
            GroupDetailCopy.leaveTitle,
            isPresented: $isLeaveConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Leave group", role: .destructive, action: onLeave)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(GroupDetailCopy.leaveMessage)
        }
        .confirmationDialog(
            GroupDetailCopy.deleteTitle,
            isPresented: $isDeleteConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Delete group", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(GroupDetailCopy.deleteMessage)
        }
        .confirmationDialog(
            memberPendingTransfer.map { "Make \($0.name) the owner?" } ?? "Transfer ownership?",
            isPresented: Binding(
                get: { memberPendingTransfer != nil },
                set: { if !$0 { memberPendingTransfer = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Transfer", role: .destructive) {
                if let member = memberPendingTransfer { onTransfer(member.id) }
                memberPendingTransfer = nil
            }
            Button("Cancel", role: .cancel) { memberPendingTransfer = nil }
        } message: {
            if let member = memberPendingTransfer {
                Text(GroupDetailCopy.transferMessage(name: member.name))
            } else {
                Text("")
            }
        }
    }
}

/// Title leading + glass X trailing — same control family as Friends / Profile.
private struct GroupManageHeaderBar: View {
    @Environment(\.pushLayout) private var layout
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Manage group")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .lineLimit(1)
                .minimumScaleFactor(GroupDetailLayout.minimumTextScale)

            Spacer(minLength: 0)

            FriendsCircleButton(
                systemImageName: "xmark",
                accessibilityLabel: "Close manage group",
                action: onClose
            )
        }
        .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
        .padding(.top, ProfileLayout.closeTopPadding)
        .padding(.bottom, ProfileLayout.closeBottomPadding)
    }
}

#if DEBUG
struct GroupManageView_Previews: PreviewProvider {
    static var previews: some View {
        GroupManageView(
            isOwner: true,
            canTransfer: true,
            inviteCandidates: [],
            transferCandidates: [],
            actionError: nil,
            dismissAction: {},
            onDismissError: {},
            onRetryError: {},
            onInvite: { _ in },
            onTransfer: { _ in },
            onLeave: {},
            onDelete: {}
        )
    }
}
#endif
