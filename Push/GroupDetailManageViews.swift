//
//  GroupDetailManageViews.swift
//  Push
//
//  Shared group chrome: member trailings, rename field, manage action list
//  (used on GroupManageView), Start push / Manage action row, and copy.
//

import SwiftUI

// MARK: - Member trailing controls

struct GroupMemberTrailingControl: View {
    enum Kind {
        case remove
        case cancelInvite
    }

    let kind: Kind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: kind == .remove ? "person.badge.minus" : "xmark.circle")
                .font(.system(size: GroupDetailManageLayout.trailingIconSize, weight: .semibold))
                .foregroundStyle(
                    kind == .remove
                        ? PushControlColors.destructive
                        : PushControlColors.textSecondary
                )
                .frame(
                    width: GroupDetailManageLayout.trailingHitSize,
                    height: GroupDetailManageLayout.trailingHitSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .remove ? "Remove member" : "Cancel invite")
    }
}

// MARK: - Manage footer

struct GroupDetailManageSection: View {
    let isOwner: Bool
    let canTransfer: Bool
    let onInvite: () -> Void
    let onTransfer: () -> Void
    let onLeave: () -> Void
    let onDelete: () -> Void

    private var actionCount: Int {
        if isOwner { return canTransfer ? 3 : 2 }
        return 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.listSpacing) {
            FriendsSectionHeader(title: "Manage", count: actionCount)
            if isOwner {
                GroupDetailManageButton(
                    title: "Invite friends",
                    symbolName: "person.badge.plus",
                    isDestructive: false,
                    action: onInvite
                )
                if canTransfer {
                    GroupDetailManageButton(
                        title: "Transfer ownership",
                        symbolName: "arrow.left.arrow.right",
                        isDestructive: false,
                        action: onTransfer
                    )
                }
                GroupDetailManageButton(
                    title: "Delete group",
                    symbolName: "trash",
                    isDestructive: true,
                    action: onDelete
                )
            } else {
                GroupDetailManageButton(
                    title: "Leave group",
                    symbolName: "rectangle.portrait.and.arrow.right",
                    isDestructive: true,
                    action: onLeave
                )
            }
        }
    }
}

struct GroupDetailManageButton: View {
    @Environment(\.pushLayout) private var layout
    let title: String
    let symbolName: String
    let isDestructive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: GroupDetailManageLayout.manageLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: GroupDetailManageLayout.manageIconSize, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PushControlColors.textTertiary)
            }
            .foregroundStyle(
                isDestructive ? PushControlColors.destructive : PushControlColors.textEspresso
            )
            .padding(.horizontal, FriendsLayout.cardPadding(layout))
            .padding(.vertical, GroupDetailManageLayout.manageVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .friendsCard(cornerRadius: FriendsLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Rename field

struct GroupDetailRenameField: View {
    @Binding var draftName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: GroupDetailManageLayout.renameSpacing) {
            TextField("Group name", text: $draftName)
                .font(.title3.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
                .tint(PushControlColors.activeForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FriendsLayout.searchHorizontalPadding)
                .padding(.vertical, GroupDetailManageLayout.renameFieldPadding)
                .background(
                    RoundedRectangle(cornerRadius: FriendsLayout.searchCornerRadius, style: .continuous)
                        .fill(FriendsColor.cardCream.opacity(FriendsColor.cardCreamOpacity))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: FriendsLayout.searchCornerRadius, style: .continuous)
                        .stroke(
                            PushColorPalette.Accent.walnut.opacity(FriendsColor.chipStrokeWalnutOpacity),
                            lineWidth: FriendsColor.cardStrokeWidth
                        )
                }

            HStack(spacing: GroupDetailManageLayout.renameActionSpacing) {
                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
                Button("Save", action: onSave)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Detail action row

struct GroupDetailActions: View {
    let onStartPush: () -> Void
    let onManage: () -> Void

    var body: some View {
        HStack(spacing: GroupDetailLayout.actionSpacing) {
            GroupDetailActionButton(
                title: "Start push",
                symbolName: "calendar.badge.plus",
                isPrimary: true,
                action: onStartPush
            )
            GroupDetailActionButton(
                title: "Manage",
                symbolName: "gearshape.fill",
                isPrimary: false,
                action: onManage
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
            .background(
                RoundedRectangle(cornerRadius: GroupDetailLayout.actionCornerRadius, style: .continuous)
                    .fill(
                        isPrimary
                            ? PushControlColors.activeFill
                            : .white.opacity(GroupDetailColor.secondaryActionFillOpacity)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Confirmations copy

enum GroupDetailCopy {
    static let leaveTitle = "Leave this group?"
    static let leaveMessage = "You can only rejoin if someone invites you again."
    static let deleteTitle = "Delete this group?"
    static let deleteMessage =
        "Delete this group for everyone? Members lose access. Past pushes stay, but won’t link to this group."
    static let removeMemberMessage = "They’ll lose access right away. You can invite them again later."
    static let cancelInviteMessage = "They won’t see this invite in Alerts anymore."

    static func transferMessage(name: String) -> String {
        "Make \(name) the owner? You’ll become a regular member."
    }
}

// MARK: - Layout

enum GroupDetailManageLayout {
    static let sheetHeaderTop: CGFloat = 12
    static let sheetSearchBottom: CGFloat = 10
    static let sheetListBottom: CGFloat = 24
    static let selectedStrokeWidth: CGFloat = 1.5
    static let trailingIconSize: CGFloat = 18
    static let trailingHitSize: CGFloat = 36
    static let manageLabelSpacing: CGFloat = 10
    static let manageIconSize: CGFloat = 15
    static let manageVerticalPadding: CGFloat = 14
    static let renameSpacing: CGFloat = 10
    static let renameFieldPadding: CGFloat = 12
    static let renameActionSpacing: CGFloat = 20
    static let pencilSize: CGFloat = 14
}

enum GroupDetailManageColor {
    static let selectedTintOpacity = 0.14
    static let selectedStrokeOpacity = 0.5
}
