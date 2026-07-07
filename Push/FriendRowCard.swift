//
//  FriendRowCard.swift
//  Push
//
//  Shared Friends-style person row used anywhere the app shows a list of
//  people on the warm cream surface.
//

import SwiftUI

struct FriendRowCard: View {
    let row: FriendRowModel
    let showsGroupLabel: Bool
    let action: (() -> Void)?

    init(
        row: FriendRowModel,
        showsGroupLabel: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.row = row
        self.showsGroupLabel = showsGroupLabel
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
        HStack(spacing: FriendsLayout.rowSpacing) {
            avatar
            identity
            Spacer(minLength: 0)
            trailing
        }
        .padding(FriendsLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .friendsCard(cornerRadius: FriendsLayout.cardCornerRadius)
    }

    private var avatar: some View {
        ProfilePhotoAvatar(
            imageAssetName: friend.profileImageAssetName,
            fallbackInitials: friend.avatarPlaceholder
        )
        .frame(width: FriendsLayout.rowAvatarSize, height: FriendsLayout.rowAvatarSize)
        .overlay {
            Circle()
                .stroke(
                    friend.availability.accentColor.opacity(FriendsColor.ringOpacity),
                    lineWidth: FriendsLayout.rowRingWidth
                )
        }
        .opacity(isHidden ? 0.72 : 1)
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
