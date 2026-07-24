//
//  PushExpandablePersonRow.swift
//  Push
//
//  DS-028 — optional expandable wrapper around flat person row + action rail.
//

import SwiftUI

/// Expandable shell around `PushPersonRow` with a configurable action rail.
/// Owns expand animation and confirmation dialogs for overflow actions.
struct PushExpandablePersonRow: View {
    @Environment(\.pushLayout) private var layout
    let row: FriendRowModel
    let isExpanded: Bool
    let isBusy: Bool
    let onToggle: () -> Void
    let railActions: [PushExpandableRailAction]
    var removeTitle: String = "Remove Friend"
    var removeMessage: String = "They won't see your status anymore, and you won't see theirs."
    var blockMessage: String = "They won't be notified. You won't appear as friends."
    let onRemove: () -> Void
    let onBlock: () -> Void

    @State private var isConfirmingRemove = false
    @State private var isConfirmingBlock = false

    var body: some View {
        VStack(spacing: 0) {
            PushPersonRow(row: row, showsCardBackground: false, action: onToggle)

            if isExpanded {
                PushExpandableActionRail(actions: railActions, isBusy: isBusy) {
                    Menu {
                        Button("Remove friend", role: .destructive) {
                            isConfirmingRemove = true
                        }
                        Button("Block", role: .destructive) {
                            isConfirmingBlock = true
                        }
                    } label: {
                        PushExpandableRailOverflowChrome(isBusy: isBusy) {
                            Image(systemName: "ellipsis")
                                .font(.system(
                                    size: PushExpandableActionRailMetrics.overflowIconSize,
                                    weight: .semibold
                                ))
                                .foregroundStyle(PushControlColors.textSecondary)
                        }
                    }
                    .disabled(isBusy)
                    .accessibilityLabel("More actions")
                    .accessibilityHint("Remove friend or block")
                }
                .padding(.horizontal, FriendsLayout.cardPadding(layout))
                .padding(.bottom, PushExpandableActionRailMetrics.railBottomPadding)
                .padding(.top, PushExpandableActionRailMetrics.actionsTopSpacing)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .pushSolidCreamCard(cornerRadius: FriendsLayout.cardCornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: FriendsLayout.cardCornerRadius, style: .continuous))
        .animation(PushMotion.expand, value: isExpanded)
        .pushConfirmation(
            isPresented: $isConfirmingRemove,
            title: "Remove \(row.friend.name)?",
            message: removeMessage,
            confirmTitle: removeTitle,
            onConfirm: onRemove
        )
        .pushConfirmation(
            isPresented: $isConfirmingBlock,
            title: "Block \(row.friend.name)?",
            message: blockMessage,
            confirmTitle: "Block",
            onConfirm: onBlock
        )
    }
}

/// Friends-list convenience wrapping directions + start-push rail actions.
struct ExpandableFriendRow: View {
    let row: FriendRowModel
    let isExpanded: Bool
    let isRemoving: Bool
    let isBlocking: Bool
    let onToggle: () -> Void
    let onDirections: () -> Void
    let onStartPush: () -> Void
    let onRemove: () -> Void
    let onBlock: () -> Void

    private var showsDirections: Bool {
        guard let placeName = row.friend.placeName else { return false }
        return !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var railActions: [PushExpandableRailAction] {
        var actions: [PushExpandableRailAction] = []
        if showsDirections {
            actions.append(
                PushExpandableRailAction(
                    label: "Directions",
                    systemImageName: "arrow.triangle.turn.up.right.circle.fill",
                    action: onDirections
                )
            )
        }
        actions.append(
            PushExpandableRailAction(
                label: "Start push",
                systemImageName: "calendar.badge.plus",
                action: onStartPush
            )
        )
        return actions
    }

    var body: some View {
        PushExpandablePersonRow(
            row: row,
            isExpanded: isExpanded,
            isBusy: isRemoving || isBlocking,
            onToggle: onToggle,
            railActions: railActions,
            onRemove: onRemove,
            onBlock: onBlock
        )
    }
}

#if DEBUG
struct PushExpandablePersonRow_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ExpandableFriendRow(
                row: FriendRowModel(
                    id: "preview",
                    friend: FriendPuckData(
                        name: "Jordan",
                        avatarPlaceholder: "J",
                        activity: "Walk",
                        activitySymbolName: "figure.walk",
                        activityDisplayText: "Walk",
                        availability: .freeNow,
                        venueStatusText: "Near campus",
                        placeName: "Campus"
                    ),
                    groupLabel: nil
                ),
                isExpanded: true,
                isRemoving: false,
                isBlocking: false,
                onToggle: {},
                onDirections: {},
                onStartPush: {},
                onRemove: {},
                onBlock: {}
            )
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
