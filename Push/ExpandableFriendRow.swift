//
//  ExpandableFriendRow.swift
//  Push
//
//  Friends-list row that expands in place to reveal Directions/Start push/
//  Remove/Block actions, replacing the old map-style bottom sheet for this
//  screen only. The row's own content (FriendRowCard) is drawn unchanged;
//  this view owns the shared card surface the row and its actions grow inside.
//

import SwiftUI

struct ExpandableFriendRow: View {
    @Environment(\.pushLayout) private var layout
    let row: FriendRowModel
    let isExpanded: Bool
    let isRemoving: Bool
    let isBlocking: Bool
    let onToggle: () -> Void
    let onDirections: () -> Void
    let onStartPush: () -> Void
    let onRemove: () -> Void
    let onBlock: () -> Void

    @State private var isConfirmingRemove = false
    @State private var isConfirmingBlock = false

    var body: some View {
        VStack(spacing: 0) {
            FriendRowCard(row: row, showsCardBackground: false, action: onToggle)

            if isExpanded {
                ExpandableFriendRowActionRow(
                    isRemoving: isRemoving,
                    isBlocking: isBlocking,
                    onDirections: onDirections,
                    onStartPush: onStartPush,
                    onRemove: { isConfirmingRemove = true },
                    onBlock: { isConfirmingBlock = true }
                )
                .padding(.horizontal, FriendsLayout.cardPadding(layout))
                .padding(.bottom, FriendsLayout.cardPadding(layout))
                .padding(.top, ExpandableFriendRowLayout.actionsTopSpacing)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .friendsCard(cornerRadius: FriendsLayout.cardCornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: FriendsLayout.cardCornerRadius, style: .continuous))
        .animation(
            .spring(
                response: ExpandableFriendRowLayout.animationResponse,
                dampingFraction: ExpandableFriendRowLayout.animationDamping
            ),
            value: isExpanded
        )
        .confirmationDialog(
            "Remove \(row.friend.name)?",
            isPresented: $isConfirmingRemove,
            titleVisibility: .visible
        ) {
            Button("Remove Friend", role: .destructive, action: onRemove)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't see your status anymore, and you won't see theirs.")
        }
        .confirmationDialog(
            "Block \(row.friend.name)?",
            isPresented: $isConfirmingBlock,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive, action: onBlock)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be notified. You won't appear as friends.")
        }
    }
}

// MARK: - Action Row

/// Four actions in a 2×2 grid so compact widths don't overflow.
private struct ExpandableFriendRowActionRow: View {
    let isRemoving: Bool
    let isBlocking: Bool
    let onDirections: () -> Void
    let onStartPush: () -> Void
    let onRemove: () -> Void
    let onBlock: () -> Void

    var body: some View {
        VStack(spacing: FriendDetailSheetLayout.actionSpacing) {
            HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
                ExpandableFriendRowActionButton(
                    label: "Directions",
                    symbolName: "arrow.triangle.turn.up.right.circle.fill",
                    emphasis: .plain,
                    action: onDirections
                )
                ExpandableFriendRowActionButton(
                    label: "Start push",
                    symbolName: "calendar.badge.plus",
                    emphasis: .sunbeam,
                    action: onStartPush
                )
            }
            HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
                ExpandableFriendRowActionButton(
                    label: "Remove",
                    symbolName: "person.badge.minus",
                    emphasis: .destructive,
                    isLoading: isRemoving,
                    action: onRemove
                )
                ExpandableFriendRowActionButton(
                    label: "Block",
                    symbolName: "hand.raised.fill",
                    emphasis: .destructive,
                    isLoading: isBlocking,
                    action: onBlock
                )
            }
        }
    }
}

private enum ExpandableFriendRowEmphasis {
    case plain
    case sunbeam
    case destructive
}

private struct ExpandableFriendRowActionButton: View {
    let label: String
    let symbolName: String
    let emphasis: ExpandableFriendRowEmphasis
    var isLoading: Bool = false
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FriendDetailSheetLayout.actionCardCornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: FriendDetailSheetLayout.actionCardLabelSpacing) {
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: symbolName)
                        .font(.system(size: FriendDetailSheetLayout.actionCardIconSize, weight: .semibold))
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(FriendsLayout.minimumTextScale)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: FriendDetailSheetLayout.actionCardHeight)
            .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.actionCardCornerRadius)
            .overlay {
                shape.stroke(Color.white.opacity(PushGlassStyle.strokeOpacity), lineWidth: ExpandableFriendRowLayout.emphasisStrokeWidth)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(label)
    }

    /// Only the icon/label tint distinguishes emphasis now; the glass
    /// background and stroke stay identical across all three buttons.
    private var foregroundColor: Color {
        switch emphasis {
        case .plain:       return PushControlColors.textPrimary
        case .sunbeam:      return ExpandableFriendRowColor.startPushText
        case .destructive: return PushControlColors.destructive
        }
    }
}

// MARK: - Style Tokens

enum ExpandableFriendRowLayout {
    static let actionsTopSpacing: CGFloat = 12
    static let animationResponse = 0.40
    static let animationDamping = 0.86
    static let emphasisStrokeWidth: CGFloat = 0.8
}

enum ExpandableFriendRowColor {
    /// Darker brown than the default walnut text, so Start push still reads
    /// as the emphasized action without a tinted background.
    static let startPushText = Color(red: 0.32, green: 0.18, blue: 0.06)
}
