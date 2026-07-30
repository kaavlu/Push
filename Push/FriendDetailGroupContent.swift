//
//  FriendDetailGroupContent.swift
//  Push
//
//  Issue #139 — compact map puck detail sheet.
//  Multi-person: group context + Who’s here chips + actions.
//  Individual: avatar summary + actions (no member grid).
//

import SwiftUI

// MARK: - Sheet content

struct FriendDetailGroupContent: View {
    let puck: MapPuckData
    @Binding var isMembersExpanded: Bool
    let onDirections: () -> Void
    let onAskToJoin: () -> Void
    let onStartPush: () -> Void
    let onSelectMember: (String) -> Void

    private var members: [FriendPuckData] {
        FriendDetailSheetContent.displayMembers(for: puck)
    }

    private var isMultiPerson: Bool {
        FriendDetailSheetContent.isMultiPerson(puck)
    }

    private var showsAskToJoin: Bool {
        FriendDetailSheetContent.showsAskToJoin(for: puck)
    }

    private var accentColor: Color {
        puck.availability.accentColor
    }

    var body: some View {
        VStack(spacing: FriendDetailSheetLayout.multiPersonSectionSpacing) {
            infoRow
            if isMultiPerson {
                whosHereSection
            }
            divider
            actions
        }
        .padding(.horizontal, FriendDetailSheetLayout.contentHorizontalPadding)
        .padding(.top, FriendDetailSheetLayout.multiPersonTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.multiPersonActionBottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: Summary

    private var infoRow: some View {
        HStack(alignment: .center, spacing: FriendDetailSheetLayout.multiPersonInfoSpacing) {
            // Overlapping stack only for individual — multi-person identity is Who’s here.
            if !isMultiPerson {
                MultiPersonAvatarStack(people: members)
            }

            VStack(alignment: .leading, spacing: FriendDetailSheetLayout.multiPersonTextSpacing) {
                Text(FriendDetailSheetContent.summaryTitle(for: puck))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isMultiPerson {
                    multiPersonSubtitle
                } else {
                    individualActivitySubtitle
                    if let location = FriendDetailSheetContent.multiPersonLocationDetail(for: puck) {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(PushControlColors.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            trailingStatus
        }
    }

    /// Venue / activity under group context title (e.g. `At Dolores`).
    private var multiPersonSubtitle: some View {
        let line = FriendDetailSheetContent.groupContextSubtitle(for: puck)
        let symbol = members.first?.activitySymbolName
            ?? PresenceActivityPresentation.defaultSymbolName

        return HStack(spacing: FriendDetailSheetLayout.multiPersonActivityIconSpacing) {
            if !symbol.isEmpty {
                Image(systemName: symbol)
                    .font(.system(
                        size: FriendDetailSheetLayout.multiPersonActivityIconSize,
                        weight: .semibold
                    ))
                    .foregroundStyle(accentColor)
            }
            Text(line)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(FriendDetailSheetLayout.multiPersonSubtitleMinimumScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var individualActivitySubtitle: some View {
        let line = FriendDetailSheetContent.multiPersonActivityLine(for: puck)
        let symbol = members.first?.activitySymbolName
            ?? PresenceActivityPresentation.defaultSymbolName

        return HStack(spacing: FriendDetailSheetLayout.multiPersonActivityIconSpacing) {
            if !symbol.isEmpty {
                Image(systemName: symbol)
                    .font(.system(
                        size: FriendDetailSheetLayout.multiPersonActivityIconSize,
                        weight: .semibold
                    ))
                    .foregroundStyle(accentColor)
            }
            Text(line)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(FriendDetailSheetLayout.multiPersonSubtitleMinimumScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var trailingStatus: some View {
        VStack(alignment: .trailing, spacing: FriendDetailSheetLayout.multiPersonTrailingSpacing) {
            PushAvailabilityChip(availability: puck.availability, density: .sheet)

            HStack(spacing: FriendsLayout.liveTimestampSpacing) {
                Circle()
                    .fill(accentColor)
                    .frame(
                        width: FriendsLayout.liveDotSize,
                        height: FriendsLayout.liveDotSize
                    )
                Text(FriendDetailSheetContent.multiPersonFreshness(for: puck))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PushControlColors.textTertiary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: Who’s here

    private var whosHereSection: some View {
        VStack(alignment: .leading, spacing: FriendDetailSheetLayout.whosHereSectionLabelSpacing) {
            Text(FriendDetailSheetContent.whosHereSectionLabel(memberCount: members.count))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PushControlColors.textTertiary)
                .tracking(FriendDetailSheetLayout.whosHereLabelTracking)

            WhosHereMemberGrid(
                members: members,
                isExpanded: isMembersExpanded,
                onSelectMember: onSelectMember,
                onExpand: { isMembersExpanded = true }
            )
            .frame(
                height: FriendDetailSheetLayout.whosHereGridViewportHeight(
                    memberCount: members.count
                )
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(
                PushColorPalette.Accent.walnut.opacity(
                    FriendDetailSheetLayout.multiPersonDividerOpacity
                )
            )
            .frame(height: FriendDetailSheetLayout.multiPersonDividerHeight)
            .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: FriendDetailSheetLayout.multiPersonActionsSpacing) {
            if showsAskToJoin {
                // Glass + walnut rim — approved primary (not solid sunbeam).
                PushGlassRimButton(
                    title: "Ask to join",
                    systemImageName: "figure.wave",
                    action: onAskToJoin
                )
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
                multiPersonSecondaryButton(
                    label: "Directions",
                    symbolName: "arrow.triangle.turn.up.right.circle.fill",
                    action: onDirections
                )
                multiPersonSecondaryButton(
                    label: "Start push",
                    symbolName: "calendar.badge.plus",
                    action: onStartPush
                )
            }
        }
    }

    private func multiPersonSecondaryButton(
        label: String,
        symbolName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: FriendDetailSheetLayout.multiPersonSecondaryLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(
                        size: FriendDetailSheetLayout.multiPersonSecondaryIconSize,
                        weight: .semibold
                    ))
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
            }
            .foregroundStyle(PushControlColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: FriendDetailSheetLayout.multiPersonSecondaryHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: FriendDetailSheetLayout.multiPersonSecondaryCornerRadius,
                    style: .continuous
                )
                .fill(
                    Color.white.opacity(
                        FriendDetailSheetLayout.multiPersonSecondaryFillOpacity
                    )
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: FriendDetailSheetLayout.multiPersonSecondaryCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(
                        FriendDetailSheetLayout.multiPersonSecondaryBorderOpacity
                    ),
                    lineWidth: FriendDetailSheetLayout.multiPersonSecondaryBorderWidth
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
