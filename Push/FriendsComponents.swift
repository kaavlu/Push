//
//  FriendsComponents.swift
//  Push
//
//  Shared, screen-local building blocks for the Friends screen: the glass
//  circle button, the availability chip, the compact group card, and the empty
//  state.
//

import SwiftUI

// Ivory page + solid cream card live in DesignSystem (PushCreamSurfaces).
// FriendsBackground / friendsCard remain as migration shims.

struct FriendsAvailabilityChip: View {
    let availability: FriendAvailabilityState

    var body: some View {
        Text(availability.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(availability.chipTextColor)
            .lineLimit(1)
            .minimumScaleFactor(FriendsLayout.minimumTextScale)
            .padding(.horizontal, FriendsLayout.chipHorizontalPadding)
            .padding(.vertical, FriendsLayout.chipVerticalPadding)
            .background(availability.chipFillColor, in: Capsule())
            .overlay(
                Capsule().stroke(.white.opacity(FriendsColor.chipStrokeOpacity), lineWidth: 0.5)
            )
    }
}

// MARK: - Filter Chips

struct FriendsFilterChipRow: View {
    @Binding var selected: FriendsFilter
    let counts: [FriendsFilter: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FriendsLayout.chipRowSpacing) {
                ForEach(FriendsFilter.allCases) { filter in
                    chip(filter)
                }
            }
        }
    }

    private func chip(_ filter: FriendsFilter) -> some View {
        let isSelected = selected == filter
        return Button {
            withAnimation(
                .spring(
                    response: FriendsLayout.switchAnimationResponse,
                    dampingFraction: FriendsLayout.switchAnimationDamping
                )
            ) {
                selected = filter
            }
        } label: {
            HStack(spacing: FriendsLayout.chipCountSpacing) {
                Text(filter.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(counts[filter] ?? 0)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, FriendsLayout.chipCountHorizontalPadding)
                    .padding(.vertical, FriendsLayout.chipCountVerticalPadding)
                    .background(
                        Capsule().fill(
                            .white.opacity(
                                isSelected ? FriendsColor.chipCountSelectedOpacity : 0
                            )
                        )
                    )
                    .background(
                        Capsule().fill(
                            PushColorPalette.Accent.walnut.opacity(
                                isSelected ? 0 : FriendsColor.chipCountInactiveOpacity
                            )
                        )
                    )
            }
            .foregroundStyle(isSelected ? FriendsColor.chipSelectedText : PushControlColors.textPrimary)
            .padding(.horizontal, FriendsLayout.filterChipHorizontalPadding)
            .padding(.vertical, FriendsLayout.filterChipVerticalPadding)
            .background(chipBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.title)
        .accessibilityValue("\(counts[filter] ?? 0)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func chipBackground(isSelected: Bool) -> some View {
        if isSelected {
            Capsule().fill(FriendsColor.chipSelectedFill)
        } else {
            Capsule()
                .fill(FriendsColor.cardCream.opacity(FriendsColor.cardCreamOpacity))
                .overlay {
                    Capsule().stroke(
                        PushColorPalette.Accent.walnut.opacity(FriendsColor.chipStrokeWalnutOpacity),
                        lineWidth: FriendsLayout.chipStrokeWidth
                    )
                }
        }
    }
}

// Section header → PushListSectionHeader (FriendsSectionHeader typealias).
// Group card → PushGroupRow (FriendGroupCard typealias).

// Empty state → FriendsEmptyState in DesignSystem EmptyStates (DS-071).
