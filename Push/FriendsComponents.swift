//
//  FriendsComponents.swift
//  Push
//
//  Shared, screen-local building blocks for the Friends screen: the glass
//  circle button, the availability chip, the compact group card, and the empty
//  state.
//

import SwiftUI

/// Warm cream/ivory page background — a single flat fill so the header, the
/// scrollable list, and the safe-area edges are all the same color.
struct FriendsBackground: View {
    var body: some View {
        FriendsColor.pageIvory
            .ignoresSafeArea()
    }
}

extension View {
    /// A subtle premium card that sits directly on the cream page background.
    func friendsCard(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(FriendsColor.cardCream)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(FriendsColor.cardStrokeOpacity),
                    lineWidth: FriendsColor.cardStrokeWidth
                )
        }
    }
}

struct FriendsCircleButton: View {
    let systemImageName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.system(size: FriendsLayout.headerButtonIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: FriendsLayout.headerButtonSize, height: FriendsLayout.headerButtonSize)
                .pushGlassBackground(cornerRadius: FriendsLayout.headerButtonSize / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

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

// MARK: - Section Header

struct FriendsSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: FriendsLayout.sectionHeaderSpacing) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .kerning(FriendsLayout.sectionHeaderKerning)
                .foregroundStyle(PushControlColors.textTertiary)

            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PushControlColors.textSecondary)
                .padding(.horizontal, FriendsLayout.sectionCountHorizontalPadding)
                .padding(.vertical, FriendsLayout.sectionCountVerticalPadding)
                .background(
                    Capsule().fill(PushColorPalette.Accent.walnut.opacity(FriendsColor.sectionBadgeFillOpacity))
                )

            Spacer(minLength: 0)
        }
        .padding(.bottom, FriendsLayout.sectionHeaderBottomPadding)
    }
}

// MARK: - Group Card

struct FriendGroupCard: View {
    @Environment(\.pushLayout) private var layout
    let group: PushGroupData
    let members: [PushGroupMemberData]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FriendsLayout.groupIdentitySpacing(layout)) {
                avatar
                identity
                    .layoutPriority(1)
                Spacer(minLength: 0)
            }
            .padding(FriendsLayout.cardPadding(layout))
            .frame(maxWidth: .infinity, alignment: .leading)
            .friendsCard(cornerRadius: FriendsLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.name)
        .accessibilityValue(summaryText)
    }

    private var avatar: some View {
        ZStack {
            if let image = PushImageAssets.image(named: group.imageAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        PushControlColors.activeFill.opacity(0.9),
                        .white.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(group.fallbackInitials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
        }
        .frame(width: FriendsLayout.groupAvatarSize(layout), height: FriendsLayout.groupAvatarSize(layout))
        .clipShape(RoundedRectangle(cornerRadius: FriendsLayout.groupAvatarCornerRadius(layout), style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendsLayout.groupAvatarCornerRadius(layout), style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 1)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.groupTextSpacing) {
            Text(group.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)
                .minimumScaleFactor(FriendsLayout.minimumTextScale)

            Text(memberCountText)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)

            Text(summaryText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(group.status == .quiet ? PushControlColors.textTertiary : PushControlColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(FriendsLayout.minimumTextScale)
        }
    }

    private var memberCountText: String {
        "\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")"
    }

    /// Prefers concrete live counts ("2 active now · 1 nearby") and falls back
    /// to the derived status badge when the circle is quiet.
    private var summaryText: String {
        var parts: [String] = []
        if group.activeNowCount > 0 { parts.append("\(group.activeNowCount) active now") }
        if group.nearbyCount > 0 { parts.append("\(group.nearbyCount) nearby") }
        if group.planCount > 0 {
            parts.append("\(group.planCount) push\(group.planCount == 1 ? "" : "es")")
        }
        return parts.isEmpty ? group.status.title : parts.joined(separator: " · ")
    }
}

// MARK: - Empty State

struct FriendsEmptyState: View {
    let mode: FriendsMode
    let isSearching: Bool

    var body: some View {
        VStack(spacing: FriendsLayout.emptyStateSpacing) {
            Image(systemName: icon)
                .font(.system(size: FriendsLayout.emptyStateIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textTertiary)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FriendsLayout.emptyStateTopPadding)
    }

    private var icon: String {
        if isSearching { return "magnifyingglass" }
        return mode == .friends ? "person.2" : "person.3"
    }

    private var title: String {
        if isSearching { return "No matches" }
        return mode == .friends ? "No friends yet" : "No groups yet"
    }

    private var message: String {
        if isSearching { return "Try a different name or place." }
        return mode == .friends
            ? "Add friends to see who's around."
            : "Create a circle to coordinate faster."
    }
}
