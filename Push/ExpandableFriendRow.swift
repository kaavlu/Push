//
//  ExpandableFriendRow.swift
//  Push
//
//  Friends-list row that expands in place to a compact action rail:
//  primary Start push, optional Directions (only with a usable location),
//  and an overflow menu for Remove friend / Block. Friend identity and
//  status stay on FriendRowCard unchanged.
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

    /// Directions only when the friend has a shared place name (usable location).
    private var showsDirections: Bool {
        guard let placeName = row.friend.placeName else { return false }
        return !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            FriendRowCard(row: row, showsCardBackground: false, action: onToggle)

            if isExpanded {
                ExpandableFriendRowActionRail(
                    showsDirections: showsDirections,
                    isBusy: isRemoving || isBlocking,
                    onDirections: onDirections,
                    onStartPush: onStartPush,
                    onRemove: { isConfirmingRemove = true },
                    onBlock: { isConfirmingBlock = true }
                )
                .padding(.horizontal, FriendsLayout.cardPadding(layout))
                .padding(.bottom, ExpandableFriendRowLayout.railBottomPadding)
                .padding(.top, ExpandableFriendRowLayout.actionsTopSpacing)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
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

// MARK: - Compact action rail

/// Single horizontal rail: optional Directions · primary Start push · overflow.
private struct ExpandableFriendRowActionRail: View {
    let showsDirections: Bool
    let isBusy: Bool
    let onDirections: () -> Void
    let onStartPush: () -> Void
    let onRemove: () -> Void
    let onBlock: () -> Void

    var body: some View {
        HStack(spacing: ExpandableFriendRowLayout.railSpacing) {
            if showsDirections {
                ExpandableFriendRowSecondaryButton(
                    label: "Directions",
                    symbolName: "arrow.triangle.turn.up.right.circle.fill",
                    action: onDirections
                )
            }

            ExpandableFriendRowPrimaryButton(
                label: "Start push",
                symbolName: "calendar.badge.plus",
                action: onStartPush
            )

            ExpandableFriendRowOverflowMenu(
                isBusy: isBusy,
                onRemove: onRemove,
                onBlock: onBlock
            )
        }
        .frame(height: ExpandableFriendRowLayout.railHeight)
    }
}

private struct ExpandableFriendRowPrimaryButton: View {
    let label: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ExpandableFriendRowLayout.primaryLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: ExpandableFriendRowLayout.primaryIconSize, weight: .semibold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(FriendsLayout.minimumTextScale)
            }
            .foregroundStyle(ExpandableFriendRowColor.startPushText)
            .frame(maxWidth: .infinity)
            .frame(height: ExpandableFriendRowLayout.railHeight)
            .expandableFriendRailSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

private struct ExpandableFriendRowSecondaryButton: View {
    let label: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ExpandableFriendRowLayout.secondaryLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: ExpandableFriendRowLayout.secondaryIconSize, weight: .semibold))
                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(FriendsLayout.minimumTextScale)
            }
            .foregroundStyle(PushControlColors.textSecondary)
            .padding(.horizontal, ExpandableFriendRowLayout.secondaryHorizontalPadding)
            .frame(height: ExpandableFriendRowLayout.railHeight)
            .expandableFriendRailSurface()
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(label)
    }
}

private struct ExpandableFriendRowOverflowMenu: View {
    let isBusy: Bool
    let onRemove: () -> Void
    let onBlock: () -> Void

    var body: some View {
        Menu {
            Button("Remove friend", role: .destructive, action: onRemove)
            Button("Block", role: .destructive, action: onBlock)
        } label: {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: ExpandableFriendRowLayout.overflowIconSize, weight: .semibold))
                        .foregroundStyle(PushControlColors.textSecondary)
                }
            }
            .frame(width: ExpandableFriendRowLayout.overflowWidth, height: ExpandableFriendRowLayout.railHeight)
            .expandableFriendRailSurface()
        }
        .disabled(isBusy)
        .accessibilityLabel("More actions")
        .accessibilityHint("Remove friend or block")
    }
}

/// Flat cream fill + thin walnut rim — no glass shadow so the rail sits flush on the card.
private extension View {
    func expandableFriendRailSurface() -> some View {
        let shape = RoundedRectangle(
            cornerRadius: ExpandableFriendRowLayout.railCornerRadius,
            style: .continuous
        )
        return background(shape.fill(FriendsColor.pageIvory))
            .overlay {
                shape.stroke(
                    ExpandableFriendRowColor.railBorder,
                    lineWidth: ExpandableFriendRowLayout.railBorderWidth
                )
            }
    }
}

// MARK: - Style Tokens

enum ExpandableFriendRowLayout {
    /// Tight gap under the friend identity so the rail reads as one card.
    static let actionsTopSpacing: CGFloat = 6
    static let railBottomPadding: CGFloat = 10
    static let railSpacing: CGFloat = 8
    static let railHeight: CGFloat = 40
    static let railCornerRadius: CGFloat = 12

    static let primaryIconSize: CGFloat = 15
    static let primaryLabelSpacing: CGFloat = 6

    static let secondaryIconSize: CGFloat = 13
    static let secondaryLabelSpacing: CGFloat = 4
    static let secondaryHorizontalPadding: CGFloat = 10

    static let overflowWidth: CGFloat = 40
    static let overflowIconSize: CGFloat = 15

    /// Thin walnut rim (1–2pt) — no glass shadow.
    static let railBorderWidth: CGFloat = 1.5

    static let animationResponse = 0.40
    static let animationDamping = 0.86
}

enum ExpandableFriendRowColor {
    /// Darker brown than default walnut so Start push reads as primary.
    static let startPushText = Color(red: 0.32, green: 0.18, blue: 0.06)
    /// Soft brand brown rim on rail controls.
    static let railBorder = PushColorPalette.Accent.walnut.opacity(0.40)
}
