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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    // MARK: Member grid

    private var whosHereSection: some View {
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
            // Yellow primary is always "Ask to join" — never promote Start push.
            if showsAskToJoin {
                multiPersonActionButton(
                    label: "Ask to join",
                    symbolName: "figure.wave",
                    style: .primary,
                    action: onAskToJoin
                )
            }
            HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
                multiPersonActionButton(
                    label: "Directions",
                    symbolName: "arrow.triangle.turn.up.right.circle.fill",
                    style: .secondary,
                    action: onDirections
                )
                multiPersonActionButton(
                    label: "Start push",
                    symbolName: "calendar.badge.plus",
                    style: .secondary,
                    action: onStartPush
                )
            }
        }
    }

    private enum ActionStyle {
        case primary
        case secondary
    }

    private func multiPersonActionButton(
        label: String,
        symbolName: String,
        style: ActionStyle,
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
            .foregroundStyle(
                style == .primary
                    ? PushControlColors.activeForeground
                    : PushControlColors.textSecondary
            )
            .frame(maxWidth: .infinity)
            .frame(height: FriendDetailSheetLayout.multiPersonSecondaryHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: FriendDetailSheetLayout.multiPersonSecondaryCornerRadius,
                    style: .continuous
                )
                .fill(actionFill(for: style))
            )
            .overlay {
                if style == .secondary {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func actionFill(for style: ActionStyle) -> Color {
        switch style {
        case .primary:
            return PushControlColors.activeFill
        case .secondary:
            return Color.white.opacity(
                FriendDetailSheetLayout.multiPersonSecondaryFillOpacity
            )
        }
    }
}
