//
//  PushPersonRow.swift
//  Push
//
//  DS-018 / DS-027 — flat person list row on solid cream foundation.
//

import SwiftUI

/// Shared person list row for ivory destinations. Default is flat; expansion is
/// an optional wrapper (`PushExpandablePersonRow`).
struct PushPersonRow: View {
    @Environment(\.pushLayout) private var layout
    let row: FriendRowModel
    let showsGroupLabel: Bool
    /// When false, only the person's name is shown (no activity, venue, or group).
    let showsStatusDetail: Bool
    let fixedHeight: CGFloat?
    let usesAvailabilityAppearance: Bool
    let customTrailing: AnyView?
    /// Off when an outer container (e.g. expandable row) draws its own card surface.
    let showsCardBackground: Bool
    let action: (() -> Void)?
    let avatarAction: (() -> Void)?
    let onLongPress: (() -> Void)?

    init(
        row: FriendRowModel,
        showsGroupLabel: Bool = true,
        showsStatusDetail: Bool = true,
        fixedHeight: CGFloat? = nil,
        usesAvailabilityAppearance: Bool = true,
        customTrailing: AnyView? = nil,
        showsCardBackground: Bool = true,
        action: (() -> Void)? = nil,
        avatarAction: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil
    ) {
        self.row = row
        self.showsGroupLabel = showsGroupLabel
        self.showsStatusDetail = showsStatusDetail
        self.fixedHeight = fixedHeight
        self.usesAvailabilityAppearance = usesAvailabilityAppearance
        self.customTrailing = customTrailing
        self.showsCardBackground = showsCardBackground
        self.action = action
        self.avatarAction = avatarAction
        self.onLongPress = onLongPress
    }

    private var friend: FriendPuckData { row.friend }
    private var isHidden: Bool { friend.availability == .unavailable }

    var body: some View {
        if let action {
            rowContent
            .onTapGesture(perform: action)
            .simultaneousGesture(
                LongPressGesture().onEnded { _ in onLongPress?() }
            )
            .accessibilityElement(children: avatarAction == nil ? .combine : .contain)
            .accessibilityLabel(friend.name)
            .accessibilityValue(showsStatusDetail ? friend.venueStatusText : "")
            .accessibilityAddTraits(.isButton)
        } else if customTrailing != nil {
            // Keep interactive trailing controls (e.g. Accept/Deny) as separate elements.
            rowContent
                .accessibilityElement(children: .contain)
        } else {
            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(friend.name)
                .accessibilityValue(showsStatusDetail ? friend.venueStatusText : "")
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
                    Spacer(minLength: 0)
                }
                trailing
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: fixedHeight)
        .contentShape(Rectangle())
        .modifier(OptionalSolidCreamCardBackground(isEnabled: showsCardBackground))
    }

    private var avatar: some View {
        Group {
            if let avatarAction {
                Button(action: avatarAction) {
                    avatarContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Locate \(friend.name) on map")
            } else {
                avatarContent
            }
        }
    }

    private var avatarContent: some View {
        ProfilePhotoAvatar(
            imageAssetName: friend.profileImageAssetName,
            fallbackInitials: friend.avatarPlaceholder
        )
        .frame(width: FriendsLayout.rowAvatarSize(layout), height: FriendsLayout.rowAvatarSize(layout))
        .overlay {
            Circle()
                .stroke(avatarRingColor, lineWidth: FriendsLayout.rowRingWidth)
        }
        .opacity(usesAvailabilityAppearance && isHidden ? 0.72 : 1)
    }

    private var avatarRingColor: Color {
        if usesAvailabilityAppearance {
            return friend.availability.accentColor.opacity(PushCreamTokens.ringOpacity)
        }
        return PushColorPalette.Accent.walnut.opacity(PushCreamTokens.neutralRingOpacity)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.rowTextSpacing) {
            Text(friend.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)

            if showsStatusDetail, !friend.venueStatusText.isEmpty {
                HStack(spacing: FriendsLayout.rowSubtitleSpacing) {
                    if !friend.activitySymbolName.isEmpty {
                        Image(systemName: friend.activitySymbolName)
                            .font(.system(size: FriendsLayout.rowSubtitleIconSize, weight: .semibold))
                            .foregroundStyle(friend.availability.accentColor)
                    }
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
                    PushAvailabilityChip(availability: friend.availability)

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

/// Applies solid cream only when `isEnabled`, so expandable wrappers can own the shell.
private struct OptionalSolidCreamCardBackground: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.pushSolidCreamCard(cornerRadius: FriendsLayout.cardCornerRadius)
        } else {
            content
        }
    }
}

/// Migration shim — prefer `PushPersonRow`.
typealias FriendRowCard = PushPersonRow

#if DEBUG
struct PushPersonRow_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            VStack(spacing: 12) {
                PushPersonRow(
                    row: FriendRowModel(
                        id: "preview",
                        friend: FriendPuckData(
                            name: "Alex",
                            avatarPlaceholder: "A",
                            activity: "Coffee",
                            activitySymbolName: "cup.and.saucer.fill",
                            activityDisplayText: "Coffee",
                            availability: .freeNow,
                            venueStatusText: "At Blue Bottle"
                        ),
                        groupLabel: "Exec"
                    )
                )
                PushPersonRow(
                    row: FriendRowModel(
                        id: "blocked",
                        friend: FriendPuckData(
                            name: "Sam",
                            avatarPlaceholder: "S",
                            activity: "",
                            activitySymbolName: "",
                            activityDisplayText: "",
                            availability: .unavailable,
                            venueStatusText: "@sam",
                            lastUpdated: ""
                        ),
                        groupLabel: nil
                    ),
                    usesAvailabilityAppearance: false,
                    customTrailing: AnyView(
                        Text("Unblock")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PushControlColors.activeForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(PushControlColors.activeFill, in: Capsule())
                    )
                )
            }
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
