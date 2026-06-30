//
//  FriendDetailSheet.swift
//  Push
//

import SwiftUI

struct FriendDetailSheet: View {
    let puck: MapPuckData

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if puck.kind == .individual, let friend = puck.people.first {
                    individualContent(friend: friend)
                } else {
                    groupContent
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Individual

    private func individualContent(friend: FriendPuckData) -> some View {
        VStack(spacing: 0) {
            individualHero(friend: friend)
            individualInfo(friend: friend)
            Divider()
                .padding(.vertical, FriendDetailSheetLayout.dividerVerticalPadding)
            actionsRow(availability: friend.availability, isGroup: false)
        }
    }

    private func individualHero(friend: FriendPuckData) -> some View {
        VStack(spacing: FriendDetailSheetLayout.heroNameSpacing) {
            ProfilePhotoAvatar(
                imageAssetName: friend.profileImageAssetName,
                fallbackInitials: friend.avatarPlaceholder
            )
            .frame(
                width: FriendDetailSheetLayout.heroAvatarSize,
                height: FriendDetailSheetLayout.heroAvatarSize
            )

            VStack(spacing: FriendDetailSheetLayout.heroInnerSpacing) {
                Text(friend.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                ActivityBadge(
                    text: friend.activityDisplayText,
                    symbolName: friend.activitySymbolName,
                    availability: friend.availability
                )
            }
        }
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.heroBottomPadding)
    }

    private func individualInfo(friend: FriendPuckData) -> some View {
        VStack(spacing: 0) {
            DetailInfoRow(symbolName: friend.activitySymbolName, text: friend.venueStatusText)

            if let withWhom = friend.withWhom, !withWhom.isEmpty {
                DetailInfoRow(
                    symbolName: "person.2.fill",
                    text: withWhom.joined(separator: ", ")
                )
            }

            DetailInfoRow(symbolName: "clock", text: friend.lastUpdated, isSecondary: true)
        }
        .padding(.horizontal, FriendDetailSheetLayout.infoHorizontalPadding)
    }

    // MARK: - Group

    private var groupContent: some View {
        VStack(spacing: 0) {
            groupHero
            groupInfo
            Divider()
                .padding(.vertical, FriendDetailSheetLayout.dividerVerticalPadding)
            actionsRow(availability: puck.availability, isGroup: true)
        }
    }

    private var groupHero: some View {
        VStack(spacing: FriendDetailSheetLayout.heroNameSpacing) {
            AvatarStack(friends: puck.people, size: FriendDetailSheetLayout.heroGroupSize)
                .frame(
                    width: FriendDetailSheetLayout.heroGroupSize,
                    height: FriendDetailSheetLayout.heroGroupSize
                )

            VStack(spacing: FriendDetailSheetLayout.heroInnerSpacing) {
                Text(FriendDetailSheetContent.groupHeadline(for: puck.people))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                ActivityBadge(
                    text: puck.activity,
                    symbolName: puck.people.first?.activitySymbolName ?? "person.3.fill",
                    availability: puck.availability
                )
            }
        }
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.heroBottomPadding)
    }

    private var groupInfo: some View {
        VStack(spacing: 0) {
            DetailInfoRow(
                symbolName: puck.people.first?.activitySymbolName ?? "mappin",
                text: puck.venueStatusText
            )
            DetailInfoRow(
                symbolName: "clock",
                text: puck.people.first?.lastUpdated ?? "Recently",
                isSecondary: true
            )
        }
        .padding(.horizontal, FriendDetailSheetLayout.infoHorizontalPadding)
    }

    // MARK: - Actions

    private func actionsRow(availability: FriendAvailabilityState, isGroup: Bool) -> some View {
        HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
            DetailActionButton(label: isGroup ? "Ping all" : "Ping", symbolName: "bolt.fill")
            DetailActionButton(label: "Start plan", symbolName: "calendar.badge.plus")
            if availability == .joinable {
                DetailActionButton(label: "Pull Up?", symbolName: "figure.wave", isPrimary: true)
            }
            DetailActionButton(label: "Hide", symbolName: "eye.slash.fill")
        }
        .padding(.horizontal, FriendDetailSheetLayout.actionHorizontalPadding)
        .padding(.bottom, FriendDetailSheetLayout.actionBottomPadding)
    }
}

// MARK: - Sub-components

private struct DetailInfoRow: View {
    let symbolName: String
    let text: String
    var isSecondary: Bool = false

    var body: some View {
        HStack(spacing: FriendDetailSheetLayout.infoIconSpacing) {
            Image(systemName: symbolName)
                .font(.system(size: FriendDetailSheetLayout.infoIconSize, weight: .semibold))
                .foregroundStyle(isSecondary ? Color.secondary : PushControlColors.activeForeground)
                .frame(width: FriendDetailSheetLayout.infoIconFrameWidth)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(isSecondary ? Color.secondary : PushControlColors.activeForeground)

            Spacer()
        }
        .padding(.vertical, FriendDetailSheetLayout.infoRowVerticalPadding)
    }
}

private struct DetailActionButton: View {
    let label: String
    let symbolName: String
    var isPrimary: Bool = false

    var body: some View {
        Button(action: {}) {
            VStack(spacing: FriendDetailSheetLayout.actionLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: FriendDetailSheetLayout.actionIconSize, weight: .semibold))

                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(FriendDetailSheetLayout.actionMinimumScaleFactor)
            }
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(maxWidth: .infinity)
            .frame(height: FriendDetailSheetLayout.actionHeight)
            .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.actionCornerRadius)
            .overlay {
                if isPrimary {
                    RoundedRectangle(
                        cornerRadius: FriendDetailSheetLayout.actionCornerRadius,
                        style: .continuous
                    )
                    .fill(PushColorPalette.Accent.sunbeam.opacity(FriendDetailSheetLayout.primaryTintOpacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
