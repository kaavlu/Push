//
//  FriendDetailGroupContent.swift
//  Push
//
//  Issue #139 — compact map puck detail sheet.
//  Multi-person: group summary + Who’s here grid + actions.
//  Individual: summary + actions (no member grid).
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
            MultiPersonAvatarStack(people: members)

            VStack(alignment: .leading, spacing: FriendDetailSheetLayout.multiPersonTextSpacing) {
                Text(FriendDetailSheetContent.summaryTitle(for: puck))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(1)
                    .truncationMode(.tail)

                activitySubtitle

                if let location = FriendDetailSheetContent.multiPersonLocationDetail(for: puck) {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(PushControlColors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            trailingStatus
        }
    }

    private var activitySubtitle: some View {
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
            Text(FriendDetailSheetLayout.whosHereTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)

            WhosHereMemberGrid(
                members: members,
                isExpanded: isMembersExpanded,
                onSelectMember: onSelectMember,
                onExpand: { isMembersExpanded = true }
            )
            .frame(height: FriendDetailSheetLayout.whosHereGridViewportHeight)
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

// MARK: - Who’s here grid

private struct WhosHereMemberGrid: View {
    let members: [FriendPuckData]
    let isExpanded: Bool
    let onSelectMember: (String) -> Void
    let onExpand: () -> Void

    private var needsOverflow: Bool {
        FriendDetailSheetContent.needsWhosHereOverflow(memberCount: members.count)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(),
                spacing: FriendDetailSheetLayout.whosHereGridSpacing
            ),
            count: FriendDetailSheetLayout.whosHereColumnCount
        )
    }

    var body: some View {
        if isExpanded || !needsOverflow {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: FriendDetailSheetLayout.whosHereGridSpacing) {
                    ForEach(members) { person in
                        WhosHerePersonPuck(person: person) {
                            onSelectMember(person.id)
                        }
                    }
                }
            }
        } else {
            LazyVGrid(columns: columns, spacing: FriendDetailSheetLayout.whosHereGridSpacing) {
                ForEach(collapsedMembers) { person in
                    WhosHerePersonPuck(person: person) {
                        onSelectMember(person.id)
                    }
                }
                WhosHereOverflowPuck(
                    overflowCount: FriendDetailSheetContent.whosHereOverflowCount(
                        memberCount: members.count
                    ),
                    action: onExpand
                )
            }
        }
    }

    private var collapsedMembers: [FriendPuckData] {
        Array(members.prefix(FriendDetailSheetLayout.whosHereCollapsedMemberSlots))
    }
}

private struct WhosHerePersonPuck: View {
    let person: FriendPuckData
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FriendDetailSheetLayout.whosHereLabelSpacing) {
                PushPersonAvatar(
                    imageAssetName: person.profileImageAssetName,
                    fallbackInitials: person.avatarPlaceholder,
                    fallbackStyle: .dark,
                    size: FriendDetailSheetLayout.whosHereAvatarSize
                )
                .overlay {
                    Circle()
                        .stroke(
                            person.availability.accentColor.opacity(PushCreamTokens.ringOpacity),
                            lineWidth: FriendDetailSheetLayout.whosHereAvatarRingWidth
                        )
                }

                Text(FriendDetailSheetContent.firstName(person))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
            }
            .padding(.horizontal, FriendDetailSheetLayout.whosHerePuckHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FriendDetailSheetLayout.whosHerePuckHeight)
            .background(Capsule().fill(secondaryFill))
            .overlay {
                Capsule()
                    .stroke(
                        PushColorPalette.Accent.walnut.opacity(
                            FriendDetailSheetLayout.multiPersonSecondaryBorderOpacity
                        ),
                        lineWidth: FriendDetailSheetLayout.multiPersonSecondaryBorderWidth
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(person.name)
    }

    private var secondaryFill: Color {
        Color.white.opacity(FriendDetailSheetLayout.multiPersonSecondaryFillOpacity)
    }
}

private struct WhosHereOverflowPuck: View {
    let overflowCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("+ \(overflowCount) more")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
                .padding(.horizontal, FriendDetailSheetLayout.whosHerePuckHorizontalPadding)
                .frame(maxWidth: .infinity)
                .frame(height: FriendDetailSheetLayout.whosHerePuckHeight)
                .background(
                    Capsule().fill(
                        Color.white.opacity(
                            FriendDetailSheetLayout.multiPersonSecondaryFillOpacity
                        )
                    )
                )
                .overlay {
                    Capsule()
                        .stroke(
                            PushColorPalette.Accent.walnut.opacity(
                                FriendDetailSheetLayout.multiPersonSecondaryBorderOpacity
                            ),
                            lineWidth: FriendDetailSheetLayout.multiPersonSecondaryBorderWidth
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(overflowCount) more people")
    }
}

// MARK: - Avatar stack

private struct MultiPersonAvatarStack: View {
    let people: [FriendPuckData]

    private var visiblePeople: [FriendPuckData] {
        Array(people.prefix(FriendDetailSheetLayout.multiPersonVisibleAvatarLimit))
    }

    private var overflowCount: Int {
        max(0, people.count - FriendDetailSheetLayout.multiPersonVisibleAvatarLimit)
    }

    private var stackWidth: CGFloat {
        FriendDetailSheetLayout.multiPersonAvatarStackWidth(visibleCount: visiblePeople.count)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(visiblePeople.enumerated()), id: \.element.id) { index, person in
                avatar(for: person)
                    .offset(x: CGFloat(index) * step)
                    .zIndex(Double(index))
            }

            if overflowCount > 0 {
                overflowBadge
                    .offset(x: CGFloat(visiblePeople.count) * step * 0.72)
                    .zIndex(Double(visiblePeople.count + 1))
            }
        }
        .frame(
            width: stackWidth,
            height: FriendDetailSheetLayout.multiPersonAvatarSize,
            alignment: .leading
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var step: CGFloat {
        FriendDetailSheetLayout.multiPersonAvatarSize
            - FriendDetailSheetLayout.multiPersonAvatarOverlap
    }

    private func avatar(for person: FriendPuckData) -> some View {
        PushPersonAvatar(
            imageAssetName: person.profileImageAssetName,
            fallbackInitials: person.avatarPlaceholder,
            fallbackStyle: .dark,
            size: FriendDetailSheetLayout.multiPersonAvatarSize
        )
        .overlay {
            Circle()
                .stroke(
                    person.availability.accentColor.opacity(PushCreamTokens.ringOpacity),
                    lineWidth: FriendDetailSheetLayout.multiPersonAvatarRingWidth
                )
        }
    }

    private var overflowBadge: some View {
        Text("+\(overflowCount)")
            .font(.system(
                size: FriendDetailSheetLayout.multiPersonOverflowFontSize,
                weight: .bold,
                design: .rounded
            ))
            .foregroundStyle(PushControlColors.textEspresso)
            .frame(
                width: FriendDetailSheetLayout.multiPersonOverflowBadgeSize,
                height: FriendDetailSheetLayout.multiPersonOverflowBadgeSize
            )
            .background(
                Circle().fill(
                    Color.white.opacity(
                        FriendDetailSheetLayout.multiPersonOverflowBadgeFillOpacity
                    )
                )
            )
            .overlay {
                Circle()
                    .stroke(
                        Color.white.opacity(PushControlGlassTokens.strokeOpacity),
                        lineWidth: PushControlGlassTokens.strokeWidth
                    )
            }
    }

    private var accessibilityLabel: String {
        let names = people.map(\.name).joined(separator: ", ")
        return names.isEmpty ? "Group" : names
    }
}

#if DEBUG
struct FriendDetailGroupContent_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            VStack {
                FriendDetailGroupContent(
                    puck: previewPuck(people: [
                        previewPerson(name: "Ishan", initials: "IS"),
                        previewPerson(name: "Viplove", initials: "VI"),
                        previewPerson(name: "Rohan", initials: "RO")
                    ]),
                    isMembersExpanded: .constant(false),
                    onDirections: {},
                    onAskToJoin: {},
                    onStartPush: {},
                    onSelectMember: { _ in }
                )
                .padding(.bottom, 20)
                .background(PushCreamTokens.solidCard)
            }
        }
    }

    private static func previewPuck(people: [FriendPuckData]) -> MapPuckData {
        MapPuckData(
            id: "preview-hangout",
            kind: people.count == 2 ? .hangout : .cluster,
            people: people,
            activity: "Lunch",
            availability: .joinable,
            venueStatusText: "At Souvla",
            coordinate: .init(latitude: 37.776, longitude: -122.424)
        )
    }

    private static func previewPerson(name: String, initials: String) -> FriendPuckData {
        FriendPuckData(
            name: name,
            avatarPlaceholder: initials,
            activity: "Lunch",
            activitySymbolName: "fork.knife",
            activityDisplayText: "Souvla",
            availability: .joinable,
            venueStatusText: "At Souvla",
            locationLabel: "517 Hayes St",
            placeName: "Souvla"
        )
    }
}
#endif
