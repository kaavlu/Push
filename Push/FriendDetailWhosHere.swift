//
//  FriendDetailWhosHere.swift
//  Push
//
//  Who’s here member grid + summary avatar stack for multi-person map sheets.
//

import SwiftUI

// MARK: - Who’s here grid

struct WhosHereMemberGrid: View {
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

struct WhosHerePersonPuck: View {
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
                            person.availability.accentColor.opacity(
                                FriendDetailSheetLayout.whosHereAvatarRingOpacity
                            ),
                            lineWidth: FriendDetailSheetLayout.whosHereAvatarRingWidth
                        )
                }

                Text(FriendDetailSheetContent.firstName(person))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(1)
                    .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
            }
            .padding(.horizontal, FriendDetailSheetLayout.whosHerePuckHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FriendDetailSheetLayout.whosHerePuckHeight)
            .background(Capsule().fill(chipFill))
            .overlay {
                Capsule()
                    .stroke(
                        PushColorPalette.Accent.walnut.opacity(
                            FriendDetailSheetLayout.whosHereChipBorderOpacity
                        ),
                        lineWidth: FriendDetailSheetLayout.whosHereChipBorderWidth
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(person.name)
    }

    private var chipFill: Color {
        Color.white.opacity(FriendDetailSheetLayout.whosHereChipFillOpacity)
    }
}

struct WhosHereOverflowPuck: View {
    let overflowCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("+ \(overflowCount) more")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)
                .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
                .padding(.horizontal, FriendDetailSheetLayout.whosHerePuckHorizontalPadding)
                .frame(maxWidth: .infinity)
                .frame(height: FriendDetailSheetLayout.whosHerePuckHeight)
                .background(
                    Capsule().fill(
                        Color.white.opacity(FriendDetailSheetLayout.whosHereChipFillOpacity)
                    )
                )
                .overlay {
                    Capsule()
                        .stroke(
                            PushColorPalette.Accent.walnut.opacity(
                                FriendDetailSheetLayout.whosHereChipBorderOpacity
                            ),
                            lineWidth: FriendDetailSheetLayout.whosHereChipBorderWidth
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(overflowCount) more people")
    }
}

// MARK: - Avatar stack

struct MultiPersonAvatarStack: View {
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
