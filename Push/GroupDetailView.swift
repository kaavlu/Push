//
//  GroupDetailView.swift
//  Push
//
//  Group Detail management hub. Views stay dumb — all mutations go through
//  closures supplied by FriendsView / GroupsView from GroupsViewModel.
//

import PhotosUI
import SwiftUI

struct GroupDetailView: View {
    @Environment(\.pushLayout) private var layout

    let group: PushGroupData
    let members: [PushGroupMemberData]
    let isOwner: Bool
    let sessionImage: UIImage?
    let inviteCandidates: [Person]
    let actionError: ActionErrorState?

    let onStartPush: () -> Void
    let backAction: () -> Void
    let onDismissError: () -> Void
    let onRetryError: () -> Void
    let onRename: (String) -> Void
    let onUpdatePhoto: (Data) -> Void
    let onRemovePhoto: () -> Void
    let onInvite: ([String]) -> Void
    let onCancelInvite: (String) -> Void
    let onRemoveMember: (String) -> Void
    let onLeave: () -> Void
    let onTransfer: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var isPhotoMenuPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isInvitePresented = false
    @State private var isTransferPresented = false
    @State private var isLeaveConfirmPresented = false
    @State private var isDeleteConfirmPresented = false
    @State private var memberPendingRemove: PushGroupMemberData?
    @State private var memberPendingCancel: PushGroupMemberData?
    @State private var memberPendingTransfer: PushGroupMemberData?

    private var activeMembers: [PushGroupMemberData] { members.filter { !$0.isPending } }
    private var pendingMembers: [PushGroupMemberData] { members.filter(\.isPending) }
    private var transferCandidates: [PushGroupMemberData] { activeMembers.filter { !$0.isOwner } }
    private var canTransfer: Bool { isOwner && !transferCandidates.isEmpty }
    private var hasPhoto: Bool {
        sessionImage != nil || !(group.imageAssetName?.isEmpty ?? true)
    }

    var body: some View {
        ZStack {
            FriendsBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GroupDetailLayout.sectionSpacing) {
                    header
                    GroupDetailActions(onStartPush: onStartPush)
                    membersList
                    GroupDetailManageSection(
                        isOwner: isOwner,
                        canTransfer: canTransfer,
                        onInvite: { isInvitePresented = true },
                        onTransfer: { isTransferPresented = true },
                        onLeave: { isLeaveConfirmPresented = true },
                        onDelete: { isDeleteConfirmPresented = true }
                    )
                }
                .padding(.horizontal, GroupDetailLayout.horizontalPadding)
                .padding(.top, GroupDetailLayout.topPadding)
                .padding(.bottom, GroupDetailLayout.bottomPadding)
            }
        }
        .safeAreaInset(edge: .top) {
            GroupDetailBackButtonBar(action: backAction)
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
        .confirmationDialog(
            "Group photo",
            isPresented: $isPhotoMenuPresented,
            titleVisibility: .visible
        ) {
            Button("Choose Photo") { isPhotoPickerPresented = true }
            if hasPhoto {
                Button("Remove Photo", role: .destructive, action: onRemovePhoto)
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $photoPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: photoPickerItem) { item in
            guard let item else { return }
            Task { await processPickedPhoto(item) }
        }
        .sheet(isPresented: $isInvitePresented) {
            GroupInviteSheet(candidates: inviteCandidates, onInvite: onInvite)
        }
        .sheet(isPresented: $isTransferPresented) {
            GroupTransferSheet(candidates: transferCandidates) { member in
                memberPendingTransfer = member
            }
        }
        .modifier(
            GroupDetailConfirmationsModifier(
                isLeaveConfirmPresented: $isLeaveConfirmPresented,
                isDeleteConfirmPresented: $isDeleteConfirmPresented,
                memberPendingRemove: $memberPendingRemove,
                memberPendingCancel: $memberPendingCancel,
                memberPendingTransfer: $memberPendingTransfer,
                onLeave: onLeave,
                onDelete: onDelete,
                onRemoveMember: onRemoveMember,
                onCancelInvite: onCancelInvite,
                onTransfer: onTransfer
            )
        )
    }

    private var header: some View {
        VStack(spacing: GroupDetailLayout.headerSpacing) {
            photoBadge
            nameBlock
            Text("\(group.memberCount) members")
                .font(.callout.weight(.semibold))
                .foregroundStyle(PushControlColors.inactiveForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var photoBadge: some View {
        let badge = GroupPhotoBadge(
            imageAssetName: group.imageAssetName,
            fallbackInitials: group.fallbackInitials,
            overrideImage: sessionImage
        )
        if isOwner {
            Button { isPhotoMenuPresented = true } label: { badge }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit group photo")
        } else {
            badge
        }
    }

    @ViewBuilder
    private var nameBlock: some View {
        if isOwner, isEditingName {
            GroupDetailRenameField(
                draftName: $draftName,
                onSave: saveRename,
                onCancel: {
                    isEditingName = false
                    draftName = group.name
                }
            )
        } else if isOwner {
            Button {
                draftName = group.name
                isEditingName = true
            } label: {
                HStack(spacing: GroupDetailLayout.titleEditSpacing) {
                    Text(group.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(PushControlColors.activeForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(GroupDetailLayout.minimumTextScale)
                    Image(systemName: "pencil")
                        .font(.system(size: GroupDetailManageLayout.pencilSize, weight: .bold))
                        .foregroundStyle(PushControlColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename group")
        } else {
            Text(group.name)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .lineLimit(1)
                .minimumScaleFactor(GroupDetailLayout.minimumTextScale)
                .multilineTextAlignment(.center)
        }
    }

    private var membersList: some View {
        LazyVStack(alignment: .leading, spacing: FriendsLayout.listSpacing) {
            FriendsSectionHeader(title: "Members", count: activeMembers.count)
            ForEach(activeMembers) { member in
                FriendRowCard(
                    row: member.friendRow,
                    showsGroupLabel: false,
                    customTrailing: activeTrailing(for: member)
                )
            }
            if !pendingMembers.isEmpty {
                FriendsSectionHeader(title: "Pending", count: pendingMembers.count)
                    .padding(.top, GroupDetailLayout.pendingSectionTopPadding)
                ForEach(pendingMembers) { member in
                    FriendRowCard(
                        row: member.friendRow,
                        showsGroupLabel: false,
                        customTrailing: pendingTrailing(for: member)
                    )
                    .opacity(GroupDetailColor.pendingMemberOpacity)
                }
            }
        }
    }

    private func activeTrailing(for member: PushGroupMemberData) -> AnyView? {
        guard isOwner, !member.isOwner else { return nil }
        return AnyView(
            GroupMemberTrailingControl(kind: .remove) {
                memberPendingRemove = member
            }
        )
    }

    private func pendingTrailing(for member: PushGroupMemberData) -> AnyView? {
        guard isOwner else { return nil }
        return AnyView(
            GroupMemberTrailingControl(kind: .cancelInvite) {
                memberPendingCancel = member
            }
        )
    }

    private func saveRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isEditingName = false
        guard trimmed != group.name else { return }
        onRename(trimmed)
    }

    private func processPickedPhoto(_ item: PhotosPickerItem) async {
        defer { photoPickerItem = nil }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let jpeg = ProfilePhotoProcessor.jpegData(from: raw)
        else { return }
        onUpdatePhoto(jpeg)
    }
}

private struct GroupDetailBackButtonBar: View {
    @Environment(\.pushLayout) private var layout
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(.system(size: ProfileLayout.closeIconSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .frame(width: ProfileLayout.closeButtonSize, height: ProfileLayout.closeButtonSize)
                    .pushGlassBackground(cornerRadius: ProfileLayout.closeButtonSize / 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to groups")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ProfileLayout.horizontalPadding(layout))
        .padding(.top, ProfileLayout.closeTopPadding)
        .padding(.bottom, ProfileLayout.closeBottomPadding)
    }
}

enum GroupDetailLayout {
    static let horizontalPadding: CGFloat = 18
    static let topPadding: CGFloat = 18
    static let bottomPadding: CGFloat = 88
    static let sectionSpacing: CGFloat = 18
    static let headerSpacing: CGFloat = 14
    static let titleEditSpacing: CGFloat = 8
    static let actionSpacing: CGFloat = 10
    static let actionLabelSpacing: CGFloat = 7
    static let actionIconSize: CGFloat = 14
    static let actionVerticalPadding: CGFloat = 14
    static let actionCornerRadius: CGFloat = 18
    static let minimumTextScale = 0.82
    static let pendingSectionTopPadding: CGFloat = 6
}

enum GroupDetailColor {
    static let secondaryActionFillOpacity = 0.38
    static let pendingMemberOpacity = 0.55
}

#if DEBUG
struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GroupDetailView(
            group: PushGroupData(
                id: "india",
                name: "India",
                memberCount: 2,
                memberIDs: ["chitty", "nitin"],
                status: .activeNow,
                activeNowCount: 2,
                nearbyCount: 1,
                planCount: 1,
                imageAssetName: "assets/groups/India/chitty.png",
                fallbackSymbol: "I",
                fallbackInitials: "I"
            ),
            members: [
                PushGroupMemberData(
                    id: "chitty", name: "Chitty", avatarPlaceholder: "CH",
                    profileImageAssetName: "assets/friends/chitty.png",
                    availability: .freeNow, membershipID: "m1", isOwner: true
                ),
                PushGroupMemberData(
                    id: "nitin", name: "Nitin", avatarPlaceholder: "NI",
                    profileImageAssetName: "assets/friends/nitin.png",
                    availability: .maybeDown, membershipID: "m2"
                )
            ],
            isOwner: true,
            sessionImage: nil,
            inviteCandidates: [],
            actionError: nil,
            onStartPush: {},
            backAction: {},
            onDismissError: {},
            onRetryError: {},
            onRename: { _ in },
            onUpdatePhoto: { _ in },
            onRemovePhoto: {},
            onInvite: { _ in },
            onCancelInvite: { _ in },
            onRemoveMember: { _ in },
            onLeave: {},
            onTransfer: { _ in },
            onDelete: {}
        )
    }
}
#endif
