//
//  FriendRowCard.swift
//  Push
//
//  Shared Friends-style person row used anywhere the app shows a list of
//  people on the warm cream surface.
//

import SwiftUI

struct FriendRowCard: View {
    @Environment(\.pushLayout) private var layout
    let row: FriendRowModel
    let showsGroupLabel: Bool
    let fixedHeight: CGFloat?
    let usesAvailabilityAppearance: Bool
    let customTrailing: AnyView?
    let action: (() -> Void)?

    init(
        row: FriendRowModel,
        showsGroupLabel: Bool = true,
        fixedHeight: CGFloat? = nil,
        usesAvailabilityAppearance: Bool = true,
        customTrailing: AnyView? = nil,
        action: (() -> Void)? = nil
    ) {
        self.row = row
        self.showsGroupLabel = showsGroupLabel
        self.fixedHeight = fixedHeight
        self.usesAvailabilityAppearance = usesAvailabilityAppearance
        self.customTrailing = customTrailing
        self.action = action
    }

    private var friend: FriendPuckData { row.friend }
    private var isHidden: Bool { friend.availability == .unavailable }

    var body: some View {
        if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(friend.name)
            .accessibilityValue(friend.venueStatusText)
        } else {
            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(friend.name)
                .accessibilityValue(friend.venueStatusText)
        }
    }

    private var rowContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: FriendsLayout.rowSpacing(layout)) {
                avatar
                identity
                    .layoutPriority(1)
                Spacer(minLength: 0)
                trailing
            }

            VStack(alignment: .leading, spacing: FriendsLayout.rowSpacing(layout)) {
                HStack(spacing: FriendsLayout.rowSpacing(layout)) {
                    avatar
                    identity
                        .layoutPriority(1)
                }
                trailing
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: fixedHeight)
        .friendsCard(cornerRadius: FriendsLayout.cardCornerRadius)
    }

    private var avatar: some View {
        ProfilePhotoAvatar(
            imageAssetName: friend.profileImageAssetName,
            fallbackInitials: friend.avatarPlaceholder
        )
        .frame(width: FriendsLayout.rowAvatarSize(layout), height: FriendsLayout.rowAvatarSize(layout))
        .overlay {
            Circle()
                .stroke(
                    friend.availability.accentColor.opacity(FriendsColor.ringOpacity),
                    lineWidth: FriendsLayout.rowRingWidth
                )
        }
        .opacity(usesAvailabilityAppearance && isHidden ? 0.72 : 1)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.rowTextSpacing) {
            Text(friend.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)

            HStack(spacing: FriendsLayout.rowSubtitleSpacing) {
                Image(systemName: friend.activitySymbolName)
                    .font(.system(size: FriendsLayout.rowSubtitleIconSize, weight: .semibold))
                    .foregroundStyle(friend.availability.accentColor)
                Text(friend.venueStatusText)
                    .font(.subheadline)
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)
            }

            if showsGroupLabel, let groupLabel = row.groupLabel {
                groupTag(groupLabel)
            }
        }
    }

    private func groupTag(_ label: String) -> some View {
        HStack(spacing: FriendsLayout.rowGroupTagSpacing) {
            Image(systemName: "person.2.fill")
                .font(.system(size: FriendsLayout.rowGroupTagIconSize, weight: .semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(PushControlColors.textTertiary)
    }

    private var trailing: some View {
        Group {
            if let customTrailing {
                customTrailing
            } else {
                VStack(alignment: .trailing, spacing: FriendsLayout.rowTrailingSpacing) {
                    FriendsAvailabilityChip(availability: friend.availability)

                    if !friend.lastUpdated.isEmpty {
                        HStack(spacing: FriendsLayout.liveTimestampSpacing) {
                            Circle()
                                .fill(friend.availability.accentColor)
                                .frame(width: FriendsLayout.liveDotSize, height: FriendsLayout.liveDotSize)
                            Text(friend.lastUpdated)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(PushControlColors.textTertiary)
                        }
                    }
                }
            }
        }
    }
}
