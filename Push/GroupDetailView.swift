//
//  GroupDetailView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct GroupDetailView: View {
    let group: PushGroupData
    let members: [PushGroupMemberData]
    /// This-session-only photo picked during Add Group creation, if any. Nil
    /// on a fresh launch — see `GroupsViewModel.sessionImage(for:)`.
    let sessionImage: UIImage?
    let onStartPush: () -> Void
    let backAction: () -> Void

    init(
        group: PushGroupData,
        members: [PushGroupMemberData],
        sessionImage: UIImage? = nil,
        onStartPush: @escaping () -> Void,
        backAction: @escaping () -> Void
    ) {
        self.group = group
        self.members = members
        self.sessionImage = sessionImage
        self.onStartPush = onStartPush
        self.backAction = backAction
    }

    var body: some View {
        ZStack {
            FriendsBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GroupDetailLayout.sectionSpacing) {
                    GroupDetailHeader(group: group, sessionImage: sessionImage)
                    GroupDetailActions(onStartPush: onStartPush)
                    GroupMembersList(members: members)
                }
                .padding(.horizontal, GroupDetailLayout.horizontalPadding)
                .padding(.top, GroupDetailLayout.topPadding)
                .padding(.bottom, GroupDetailLayout.bottomPadding)
            }
        }
        .safeAreaInset(edge: .top) {
            GroupDetailBackButtonBar(action: backAction)
        }
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

private struct GroupDetailHeader: View {
    let group: PushGroupData
    let sessionImage: UIImage?

    var body: some View {
        VStack(spacing: GroupDetailLayout.headerSpacing) {
            GroupPhotoBadge(
                imageAssetName: group.imageAssetName,
                fallbackInitials: group.fallbackInitials,
                overrideImage: sessionImage
            )

            VStack(spacing: GroupDetailLayout.titleSpacing) {
                Text(group.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(GroupDetailLayout.minimumTextScale)
                    .multilineTextAlignment(.center)

                Text("\(group.memberCount) members")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct GroupDetailActions: View {
    let onStartPush: () -> Void

    var body: some View {
        HStack(spacing: GroupDetailLayout.actionSpacing) {
            GroupDetailActionButton(
                title: "Start push",
                symbolName: "calendar.badge.plus",
                isPrimary: true,
                action: onStartPush
            )
            GroupDetailActionButton(
                title: "Ping group",
                symbolName: "paperplane.fill",
                isPrimary: false,
                action: {}
            )
        }
    }
}

private struct GroupDetailActionButton: View {
    let title: String
    let symbolName: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: GroupDetailLayout.actionLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: GroupDetailLayout.actionIconSize, weight: .bold))

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(GroupDetailLayout.minimumTextScale)
            }
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, GroupDetailLayout.actionVerticalPadding)
            .background(actionBackground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var actionBackground: some View {
        RoundedRectangle(cornerRadius: GroupDetailLayout.actionCornerRadius, style: .continuous)
            .fill(isPrimary ? PushControlColors.activeFill : .white.opacity(GroupDetailColor.secondaryActionFillOpacity))
    }
}

private struct GroupMembersList: View {
    let members: [PushGroupMemberData]

    private var activeMembers: [PushGroupMemberData] { members.filter { !$0.isPending } }
    private var pendingMembers: [PushGroupMemberData] { members.filter(\.isPending) }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: FriendsLayout.listSpacing) {
            FriendsSectionHeader(title: "Members", count: activeMembers.count)

            ForEach(activeMembers) { member in
                FriendRowCard(row: member.friendRow, showsGroupLabel: false)
            }

            if !pendingMembers.isEmpty {
                FriendsSectionHeader(title: "Pending", count: pendingMembers.count)
                    .padding(.top, GroupDetailLayout.pendingSectionTopPadding)

                ForEach(pendingMembers) { member in
                    FriendRowCard(row: member.friendRow, showsGroupLabel: false)
                        .opacity(GroupDetailColor.pendingMemberOpacity)
                }
            }
        }
    }
}

private enum GroupDetailLayout {
    static let horizontalPadding: CGFloat = 18
    static let topPadding: CGFloat = 18
    static let bottomPadding: CGFloat = 88
    static let sectionSpacing: CGFloat = 18
    static let headerSpacing: CGFloat = 14
    static let titleSpacing: CGFloat = 3
    static let actionSpacing: CGFloat = 10
    static let actionLabelSpacing: CGFloat = 7
    static let actionIconSize: CGFloat = 14
    static let actionVerticalPadding: CGFloat = 14
    static let actionCornerRadius: CGFloat = 18
    static let minimumTextScale = 0.82
    static let pendingSectionTopPadding: CGFloat = 6
}

private enum GroupDetailColor {
    static let secondaryActionFillOpacity = 0.38
    /// De-emphasizes invited-but-not-yet-accepted members without hiding them.
    static let pendingMemberOpacity = 0.55
}

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
                    id: "chitty",
                    name: "Chitty",
                    avatarPlaceholder: "CH",
                    profileImageAssetName: "assets/friends/chitty.png",
                    availability: .freeNow
                ),
                PushGroupMemberData(
                    id: "nitin",
                    name: "Nitin",
                    avatarPlaceholder: "NI",
                    profileImageAssetName: "assets/friends/nitin.png",
                    availability: .maybeDown
                ),
                PushGroupMemberData(
                    id: "raj",
                    name: "Raj",
                    avatarPlaceholder: "RA",
                    profileImageAssetName: nil,
                    availability: nil,
                    isPending: true
                )
            ],
            onStartPush: {}
        ) {
        }
    }
}
