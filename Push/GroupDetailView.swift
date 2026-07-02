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
    let backAction: () -> Void

    var body: some View {
        ZStack {
            PushModalBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GroupDetailLayout.sectionSpacing) {
                    GroupDetailHeader(group: group)
                    GroupDetailActions()
                    GroupMembersCard(members: members)
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
        .padding(.horizontal, ProfileLayout.horizontalPadding)
        .padding(.top, ProfileLayout.closeTopPadding)
        .padding(.bottom, ProfileLayout.closeBottomPadding)
    }
}

private struct GroupDetailHeader: View {
    let group: PushGroupData

    var body: some View {
        VStack(spacing: GroupDetailLayout.headerSpacing) {
            GroupDetailImage(group: group)

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

private struct GroupDetailImage: View {
    let group: PushGroupData

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let image = PushImageAssets.image(named: group.imageAssetName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    GroupDetailFallbackTile(group: group)
                }
            }
            .frame(width: GroupDetailLayout.heroImageSize, height: GroupDetailLayout.heroImageSize)
            .clipShape(RoundedRectangle(cornerRadius: GroupDetailLayout.heroImageCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GroupDetailLayout.heroImageCornerRadius, style: .continuous)
                    .stroke(.white.opacity(GroupDetailColor.imageStrokeOpacity), lineWidth: GroupDetailLayout.imageStrokeWidth)
            }

            GroupDetailEditBadge()
                .offset(x: GroupDetailLayout.editBadgeOffset, y: GroupDetailLayout.editBadgeOffset)
        }
        .shadow(
            color: PushColorPalette.Accent.walnut.opacity(GroupDetailColor.imageShadowOpacity),
            radius: GroupDetailLayout.imageShadowRadius,
            y: GroupDetailLayout.imageShadowYOffset
        )
    }
}

private struct GroupDetailEditBadge: View {
    var body: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: GroupDetailLayout.editBadgeIconSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(width: GroupDetailLayout.editBadgeSize, height: GroupDetailLayout.editBadgeSize)
            .background(Circle().fill(.white.opacity(GroupDetailColor.editBadgeFillOpacity)))
            .overlay {
                Circle()
                    .stroke(PushControlColors.activeFill, lineWidth: GroupDetailLayout.editBadgeStrokeWidth)
            }
    }
}

private struct GroupDetailFallbackTile: View {
    let group: PushGroupData

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PushControlColors.activeFill.opacity(GroupDetailColor.fallbackTopOpacity),
                    .white.opacity(GroupDetailColor.fallbackBottomOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(group.fallbackInitials)
                .font(.system(size: GroupDetailLayout.fallbackTextSize, weight: .bold, design: .rounded))
                .foregroundStyle(PushControlColors.activeForeground)
        }
    }
}

private struct GroupDetailActions: View {
    var body: some View {
        HStack(spacing: GroupDetailLayout.actionSpacing) {
            GroupDetailActionButton(title: "Start push", symbolName: "calendar.badge.plus", isPrimary: true)
            GroupDetailActionButton(title: "Ping group", symbolName: "paperplane.fill", isPrimary: false)
        }
    }
}

private struct GroupDetailActionButton: View {
    let title: String
    let symbolName: String
    let isPrimary: Bool

    var body: some View {
        Button {
        } label: {
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

private struct GroupMembersCard: View {
    let members: [PushGroupMemberData]

    var body: some View {
        VStack(alignment: .leading, spacing: GroupDetailLayout.memberSpacing) {
            Text("Members")
                .font(.headline.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)

            ForEach(members) { member in
                GroupMemberRow(member: member)
            }
        }
        .padding(GroupDetailLayout.cardPadding)
        .pushGlassBackground(cornerRadius: GroupDetailLayout.cardCornerRadius)
    }
}

private struct GroupMemberRow: View {
    let member: PushGroupMemberData

    var body: some View {
        HStack(spacing: GroupDetailLayout.memberRowSpacing) {
            GroupMemberAvatar(member: member)

            Text(member.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)

            Spacer(minLength: 0)

            if let availability = member.availability {
                GroupMemberStatusPill(availability: availability)
            }
        }
        .padding(GroupDetailLayout.memberRowPadding)
        .background {
            RoundedRectangle(cornerRadius: GroupDetailLayout.memberRowCornerRadius, style: .continuous)
                .fill(.white.opacity(GroupDetailColor.memberRowFillOpacity))
        }
    }
}

private struct GroupMemberAvatar: View {
    let member: PushGroupMemberData

    var body: some View {
        ZStack {
            if let image = PushImageAssets.image(named: member.profileImageAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(member.avatarPlaceholder)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PushControlColors.activeFill.opacity(GroupDetailColor.avatarFallbackFillOpacity))
            }
        }
        .frame(width: GroupDetailLayout.memberAvatarSize, height: GroupDetailLayout.memberAvatarSize)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(GroupDetailColor.imageStrokeOpacity), lineWidth: GroupDetailLayout.avatarStrokeWidth)
        }
    }
}

private struct GroupMemberStatusPill: View {
    let availability: FriendAvailabilityState

    var body: some View {
        Text(availability.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .lineLimit(1)
            .minimumScaleFactor(GroupDetailLayout.minimumTextScale)
            .padding(.horizontal, GroupDetailLayout.statusHorizontalPadding)
            .padding(.vertical, GroupDetailLayout.statusVerticalPadding)
            .background(Capsule().fill(PushControlColors.activeFill.opacity(GroupDetailColor.statusFillOpacity)))
    }
}

private enum GroupDetailLayout {
    static let horizontalPadding: CGFloat = 18
    static let topPadding: CGFloat = 18
    static let bottomPadding: CGFloat = 88
    static let sectionSpacing: CGFloat = 18
    static let headerSpacing: CGFloat = 14
    static let titleSpacing: CGFloat = 3
    static let heroImageSize: CGFloat = 112
    static let heroImageCornerRadius: CGFloat = 34
    static let imageStrokeWidth: CGFloat = 1.2
    static let imageShadowRadius: CGFloat = 18
    static let imageShadowYOffset: CGFloat = 8
    static let fallbackTextSize: CGFloat = 34
    static let editBadgeSize: CGFloat = 34
    static let editBadgeIconSize: CGFloat = 14
    static let editBadgeStrokeWidth: CGFloat = 2
    static let editBadgeOffset: CGFloat = 4
    static let actionSpacing: CGFloat = 10
    static let actionLabelSpacing: CGFloat = 7
    static let actionIconSize: CGFloat = 14
    static let actionVerticalPadding: CGFloat = 14
    static let actionCornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 26
    static let memberSpacing: CGFloat = 8
    static let memberRowSpacing: CGFloat = 12
    static let memberRowPadding: CGFloat = 10
    static let memberRowCornerRadius: CGFloat = 18
    static let memberAvatarSize: CGFloat = 40
    static let avatarStrokeWidth: CGFloat = 1
    static let statusHorizontalPadding: CGFloat = 9
    static let statusVerticalPadding: CGFloat = 6
    static let minimumTextScale = 0.82
}

private enum GroupDetailColor {
    static let imageStrokeOpacity = 0.82
    static let imageShadowOpacity = 0.18
    static let fallbackTopOpacity = 0.92
    static let fallbackBottomOpacity = 0.86
    static let editBadgeFillOpacity = 0.9
    static let secondaryActionFillOpacity = 0.38
    static let memberRowFillOpacity = 0.28
    static let avatarFallbackFillOpacity = 0.92
    static let statusFillOpacity = 0.72
}

struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GroupDetailView(
            group: GroupsMockData.groups[0],
            members: SeededGroupFriends.members(for: GroupsMockData.groups[0].memberIDs)
        ) {
        }
    }
}
