//
//  PushExpandablePersonRow.swift
//  Push
//
//  DS-028 — optional expandable wrapper around flat person row + action rail.
//

import SwiftUI

/// Expandable shell around `PushPersonRow` with a configurable action rail.
/// Owns expand animation, Push action menu, and confirmation dialogs for overflow.
struct PushExpandablePersonRow: View {
    @Environment(\.pushLayout) private var layout
    let row: FriendRowModel
    let isExpanded: Bool
    let isBusy: Bool
    let onToggle: () -> Void
    let onAvatarTap: () -> Void
    let railActions: [PushExpandableRailAction]
    var removeTitle: String = "Remove Friend"
    var removeMessage: String = "They won't see your status anymore, and you won't see theirs."
    var blockMessage: String = "They won't be notified. You won't appear as friends."
    let onRemove: () -> Void
    let onBlock: () -> Void

    @State private var isOverflowMenuPresented = false
    @State private var isConfirmingRemove = false
    @State private var isConfirmingBlock = false
    /// Queued after the action menu dismisses so two window overlays don't race.
    @State private var pendingConfirmation: OverflowConfirmation?

    private enum OverflowConfirmation {
        case remove
        case block
    }

    private enum OverflowActionID {
        static let remove = "remove"
        static let block = "block"
    }

    private var overflowMenuItems: [PushActionMenuItem] {
        [
            PushActionMenuItem(
                id: OverflowActionID.remove,
                title: "Remove friend",
                role: .destructive
            ),
            PushActionMenuItem(
                id: OverflowActionID.block,
                title: "Block",
                role: .destructive
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            PushPersonRow(
                row: row,
                showsCardBackground: false,
                action: onToggle,
                avatarAction: onAvatarTap,
                onLongPress: presentOverflowMenu
            )

            if isExpanded {
                PushExpandableActionRail(actions: railActions, isBusy: isBusy) {
                    PushExpandableRailOverflowButton(
                        isBusy: isBusy,
                        accessibilityLabel: "More actions",
                        accessibilityHint: "Remove friend or block"
                    ) {
                        isOverflowMenuPresented = true
                    }
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
        .pushActionMenu(
            isPresented: $isOverflowMenuPresented,
            title: "More actions",
            items: overflowMenuItems,
            onSelect: handleOverflowSelection
        )
        .onChange(of: isOverflowMenuPresented) { presented in
            guard !presented, let pending = pendingConfirmation else { return }
            pendingConfirmation = nil
            // Present confirm after the menu host has dismissed.
            DispatchQueue.main.async {
                switch pending {
                case .remove: isConfirmingRemove = true
                case .block: isConfirmingBlock = true
                }
            }
        }
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

    private func handleOverflowSelection(_ item: PushActionMenuItem) {
        switch item.id {
        case OverflowActionID.remove:
            pendingConfirmation = .remove
        case OverflowActionID.block:
            pendingConfirmation = .block
        default:
            break
        }
    }

    private func presentOverflowMenu() {
        guard !isBusy else { return }
        isOverflowMenuPresented = true
    }
}

/// Friends-list convenience wrapping directions + start-push rail actions.
struct ExpandableFriendRow: View {
    let row: FriendRowModel
    let isExpanded: Bool
    let isRemoving: Bool
    let isBlocking: Bool
    let onToggle: () -> Void
    let onAvatarTap: () -> Void
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
            onAvatarTap: onAvatarTap,
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
                onAvatarTap: {},
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
