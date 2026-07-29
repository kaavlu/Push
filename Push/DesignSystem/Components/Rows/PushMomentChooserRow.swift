//
//  PushMomentChooserRow.swift
//  Push
//
//  DS-091 — solid-cream chooser rows for Share a moment hub:
//  existing moments (media thumb), past Pushes (avatar stack), create action.
//

import SwiftUI

// MARK: - Metrics

enum PushMomentChooserMetrics {
    static func rowThumbSize(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.value(compact: 52, standard: 54, large: 56)
    }

    static let rowThumbCornerRadius: CGFloat = 14
    static let rowThumbRingWidth: CGFloat = 1
    static let rowThumbPlaceholderIconSize: CGFloat = 16
    static let createPlusIconSize: CGFloat = 16

    static let rowPeopleAvatarSize: CGFloat = 22

    /// Past Push leading stack — person-row face size for list density.
    static func pastPushAvatarSize(_ layout: PushAdaptiveLayout) -> CGFloat {
        FriendsLayout.rowAvatarSize(layout)
    }

    static func rowContentSpacing(_ layout: PushAdaptiveLayout) -> CGFloat {
        FriendsLayout.rowSpacing(layout)
    }

    static let rowSecondarySpacing: CGFloat = 10
    static let rowMediaBadgeSpacing: CGFloat = 4
    static let rowMediaIconSize: CGFloat = 11
    static let rowChevronSize: CGFloat = 12
    static let rowChevronLeadingSpacing: CGFloat = 8

    static let avatarOverlapScale: CGFloat = 0.38
    static let maxFaces = 3
    static let avatarOverflowSpacing: CGFloat = 6
    static let avatarRingWidth: CGFloat = 1.5

    static let mediaSymbolName = "photo.on.rectangle"
}

// MARK: - Person model

/// Lightweight face identity for chooser stacks (no availability chrome).
struct PushChooserPerson: Identifiable, Equatable {
    let id: String
    let displayName: String
    let initials: String
    let imageAssetPath: String?
}

// MARK: - Shared chrome

/// Square media / action leading mark with solid cream-adjacent fill + walnut ring.
struct PushChooserThumbFrame<Content: View>: View {
    let size: CGFloat
    var fill: Color = PushColorPalette.Accent.walnut.opacity(0.08)
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PushMomentChooserMetrics.rowThumbCornerRadius,
                style: .continuous
            )
            .fill(fill)

            content()
                .frame(width: size, height: size)
                .clipped()
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PushMomentChooserMetrics.rowThumbCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PushMomentChooserMetrics.rowThumbCornerRadius,
                style: .continuous
            )
            .stroke(
                PushColorPalette.Accent.walnut.opacity(PushCreamTokens.neutralRingOpacity),
                lineWidth: PushMomentChooserMetrics.rowThumbRingWidth
            )
        }
    }
}

/// Overlapping avatar stack for chooser rows (optional +N overflow).
struct PushChooserAvatarStack: View {
    let people: [PushChooserPerson]
    let avatarSize: CGFloat
    var showsOverflowCount: Bool = true
    /// When true, width is always sized for `maxFaces` so columns align.
    var usesFixedMaxWidth: Bool = false

    private var overlap: CGFloat {
        avatarSize * PushMomentChooserMetrics.avatarOverlapScale
    }

    private var maxFaces: Int { PushMomentChooserMetrics.maxFaces }

    var body: some View {
        let shown = Array(people.prefix(maxFaces))
        let overflow = max(0, people.count - shown.count)
        let faceCountForWidth = usesFixedMaxWidth ? maxFaces : max(shown.count, 1)
        let stackWidth = avatarSize + CGFloat(max(faceCountForWidth - 1, 0)) * overlap

        HStack(spacing: PushMomentChooserMetrics.avatarOverflowSpacing) {
            ZStack(alignment: .leading) {
                if shown.isEmpty {
                    Circle()
                        .fill(PushCreamTokens.solidCard)
                        .frame(width: avatarSize, height: avatarSize)
                } else {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, person in
                        PushPersonAvatar(
                            imageAssetName: person.imageAssetPath,
                            fallbackInitials: person.initials,
                            fallbackStyle: .dark
                        )
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(
                                    Color.white.opacity(PushCreamTokens.ringOpacity),
                                    lineWidth: PushMomentChooserMetrics.avatarRingWidth
                                )
                        }
                        .offset(x: CGFloat(index) * overlap)
                    }
                }
            }
            .frame(width: stackWidth, height: avatarSize, alignment: .leading)

            if showsOverflowCount, overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PushControlColors.textTertiary)
            }
        }
        .frame(height: avatarSize, alignment: .center)
    }
}

// MARK: - Existing moment row

/// Existing moment chooser: media thumb, title, date · location, people + media + chip, chevron.
struct PushMomentChooserRow<Leading: View>: View {
    @Environment(\.pushLayout) private var layout
    let title: String
    let metaLine: String
    let contributors: [PushChooserPerson]
    let mediaCountLabel: String?
    let mediaAccessibilityLabel: String
    let contributionTitle: String
    let contributionKind: PushContributionChipKind
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        HStack(alignment: .center, spacing: PushMomentChooserMetrics.rowContentSpacing(layout)) {
            leading()

            VStack(alignment: .leading, spacing: FriendsLayout.rowTextSpacing) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(2)

                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)

                secondaryLine
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
            trailingChevron
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .pushSolidCreamCard(cornerRadius: FriendsLayout.cardCornerRadius)
    }

    private var secondaryLine: some View {
        HStack(spacing: PushMomentChooserMetrics.rowSecondarySpacing) {
            if !contributors.isEmpty {
                PushChooserAvatarStack(
                    people: contributors,
                    avatarSize: PushMomentChooserMetrics.rowPeopleAvatarSize,
                    showsOverflowCount: true,
                    usesFixedMaxWidth: false
                )
            }
            if let mediaCountLabel {
                HStack(spacing: PushMomentChooserMetrics.rowMediaBadgeSpacing) {
                    Image(systemName: PushMomentChooserMetrics.mediaSymbolName)
                        .font(.system(size: PushMomentChooserMetrics.rowMediaIconSize, weight: .semibold))
                    Text(mediaCountLabel)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(PushControlColors.textTertiary)
                .accessibilityLabel(mediaAccessibilityLabel)
            }
            PushContributionChip(title: contributionTitle, kind: contributionKind)
        }
    }

    private var trailingChevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: PushMomentChooserMetrics.rowChevronSize, weight: .bold))
            .foregroundStyle(PushControlColors.textTertiary)
            .frame(width: PushMomentChooserMetrics.rowChevronSize)
            .accessibilityHidden(true)
    }
}

// MARK: - Past Push row

/// Past Push chooser: fixed-width attendee stack, title, date · location, chevron (no media).
struct PushPastPushChooserRow: View {
    @Environment(\.pushLayout) private var layout
    let title: String
    let metaLine: String
    let participants: [PushChooserPerson]

    var body: some View {
        HStack(alignment: .center, spacing: PushMomentChooserMetrics.rowContentSpacing(layout)) {
            PushChooserAvatarStack(
                people: participants,
                avatarSize: PushMomentChooserMetrics.pastPushAvatarSize(layout),
                showsOverflowCount: false,
                usesFixedMaxWidth: true
            )

            VStack(alignment: .leading, spacing: FriendsLayout.rowTextSpacing) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(2)

                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: PushMomentChooserMetrics.rowChevronLeadingSpacing)

            Image(systemName: "chevron.right")
                .font(.system(size: PushMomentChooserMetrics.rowChevronSize, weight: .bold))
                .foregroundStyle(PushControlColors.textTertiary)
                .frame(width: PushMomentChooserMetrics.rowChevronSize)
                .accessibilityHidden(true)
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .pushSolidCreamCard(cornerRadius: FriendsLayout.cardCornerRadius)
    }
}

// MARK: - Create-from-scratch action row

/// Pinned hub action: square sunbeam + mark matching moment thumb size.
struct PushCreateActionChooserRow: View {
    @Environment(\.pushLayout) private var layout
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: FriendsLayout.rowSpacing(layout)) {
            createLeadingThumb

            VStack(alignment: .leading, spacing: FriendsLayout.rowTextSpacing) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: PushMomentChooserMetrics.rowChevronSize, weight: .bold))
                .foregroundStyle(PushControlColors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .pushSolidCreamCard(cornerRadius: FriendsLayout.cardCornerRadius)
    }

    private var createLeadingThumb: some View {
        let size = PushMomentChooserMetrics.rowThumbSize(layout)
        return PushChooserThumbFrame(
            size: size,
            fill: PushColorPalette.Accent.sunbeam
        ) {
            Image(systemName: "plus")
                .font(.system(size: PushMomentChooserMetrics.createPlusIconSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
        }
    }
}

#if DEBUG
struct PushMomentChooserRow_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            VStack(spacing: 8) {
                PushCreateActionChooserRow(
                    title: "Create from scratch",
                    subtitle: "Add photos and write your own."
                )
                PushMomentChooserRow(
                    title: "Friday night out",
                    metaLine: "Fri · 9:30 PM · Mission",
                    contributors: samplePeople,
                    mediaCountLabel: "3",
                    mediaAccessibilityLabel: "3 media items",
                    contributionTitle: "Open for adds",
                    contributionKind: .openForAdds
                ) {
                    PushChooserThumbFrame(size: 54) {
                        Image(systemName: "photo")
                            .foregroundStyle(PushControlColors.textTertiary)
                    }
                }
                PushPastPushChooserRow(
                    title: "Park hang",
                    metaLine: "Sat · 4:30 PM · Dolores Park",
                    participants: samplePeople
                )
            }
            .padding()
            .background(PushModalBackground())
        }
    }

    private static let samplePeople: [PushChooserPerson] = [
        PushChooserPerson(id: "1", displayName: "A", initials: "A", imageAssetPath: nil),
        PushChooserPerson(id: "2", displayName: "B", initials: "B", imageAssetPath: nil),
        PushChooserPerson(id: "3", displayName: "C", initials: "C", imageAssetPath: nil),
        PushChooserPerson(id: "4", displayName: "D", initials: "D", imageAssetPath: nil),
    ]
}
#endif
