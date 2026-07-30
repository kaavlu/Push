//
//  FriendDetailGroupContent.swift
//  Push
//
//  Issue #139 — compact multi-person map sheet (hangout / cluster / friendGroup).
//  Reads as an expanded Friends row: avatar stack, title, activity, status, actions.
//

import SwiftUI

// MARK: - Multi-person sheet content

struct FriendDetailGroupContent: View {
    let puck: MapPuckData
    let onDirections: () -> Void
    let onAskToJoin: () -> Void
    let onStartPush: () -> Void

    private var members: [FriendPuckData] {
        FriendDetailSheetContent.displayMembers(for: puck)
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
            divider
            actions
        }
        .padding(.horizontal, FriendDetailSheetLayout.contentHorizontalPadding)
        .padding(.top, FriendDetailSheetLayout.multiPersonTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.multiPersonActionBottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: Info row

    private var infoRow: some View {
        HStack(alignment: .center, spacing: FriendDetailSheetLayout.multiPersonInfoSpacing) {
            MultiPersonAvatarStack(people: members)

            VStack(alignment: .leading, spacing: FriendDetailSheetLayout.multiPersonTextSpacing) {
                Text(FriendDetailSheetContent.multiPersonTitle(for: members))
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
                PushSolidSunbeamButton(
                    title: "Ask to join",
                    systemImageName: "figure.wave",
                    action: onAskToJoin
                )
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
            } else {
                PushSolidSunbeamButton(
                    title: "Start push",
                    systemImageName: "calendar.badge.plus",
                    action: onStartPush
                )
                multiPersonSecondaryButton(
                    label: "Directions",
                    symbolName: "arrow.triangle.turn.up.right.circle.fill",
                    action: onDirections
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
                        previewPerson(name: "Viplove", initials: "VI")
                    ]),
                    onDirections: {},
                    onAskToJoin: {},
                    onStartPush: {}
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
