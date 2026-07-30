//
//  PushMediaCarouselBottom.swift
//  Push
//
//  Bottom interaction chrome for Feed media: participant stack + names.
//  Playback toggles by tapping the media (see PushMediaCarousel). Add yours
//  lives in the cream content band under the media.
//

import SwiftUI

// MARK: - Bottom section

struct FeedMediaBottomInteraction: View {
    let participants: [FeedMediaParticipant]

    var body: some View {
        ZStack(alignment: .bottom) {
            FeedMediaBottomScrim()
                .allowsHitTesting(false)

            participantRow
                .padding(.horizontal, FeedMediaLayout.bottomHorizontalInset)
                .padding(.bottom, FeedMediaLayout.bottomEdgeInset)
        }
    }

    private var participantRow: some View {
        HStack(alignment: .center, spacing: FeedMediaBottomStyle.avatarToTextSpacing) {
            FeedMediaParticipantAvatarStack(participants: participants)

            // Names only: per-item uploader attribution would be wrong here —
            // the line sits on the first slide but the album mixes contributors.
            Text(FeedMediaParticipantCopy.namesLine(from: participants))
                .font(FeedMediaBottomStyle.namesFont)
                .foregroundStyle(FeedMediaBottomStyle.textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
                .shadow(
                    color: Color.black.opacity(0.35),
                    radius: FeedMediaBottomStyle.textShadowRadius,
                    y: FeedMediaBottomStyle.textShadowY
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Scrim

private struct FeedMediaBottomScrim: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0),
                    .init(
                        color: Color.black.opacity(FeedMediaBottomStyle.scrimMidOpacity),
                        location: FeedMediaBottomStyle.scrimMidStop
                    ),
                    .init(
                        color: Color.black.opacity(FeedMediaBottomStyle.scrimBottomOpacity),
                        location: 1
                    ),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: FeedMediaLayout.bottomScrimHeight)
        }
    }
}

// MARK: - Avatar stack

private struct FeedMediaParticipantAvatarStack: View {
    let participants: [FeedMediaParticipant]

    private var visible: [FeedMediaParticipant] {
        Array(participants.prefix(FeedMediaParticipantCopy.maxVisibleAvatars))
    }

    private var overflowCount: Int {
        FeedMediaParticipantCopy.avatarOverflowCount(participantCount: participants.count)
    }

    var body: some View {
        HStack(spacing: FeedMediaBottomStyle.avatarOverlap) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, person in
                PushPersonAvatar(
                    imageAssetName: person.imageAssetPath,
                    fallbackInitials: person.initials,
                    fallbackStyle: .dark,
                    size: FeedMediaBottomStyle.avatarSize
                )
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(FeedMediaBottomStyle.avatarStrokeOpacity),
                            lineWidth: FeedMediaBottomStyle.avatarStrokeWidth
                        )
                }
                .zIndex(Double(visible.count - index))
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(
                        size: FeedMediaBottomStyle.overflowFontSize,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .frame(
                        width: FeedMediaBottomStyle.avatarSize,
                        height: FeedMediaBottomStyle.avatarSize
                    )
                    .background(Circle().fill(PushColorPalette.Accent.sunbeam))
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(FeedMediaBottomStyle.avatarStrokeOpacity),
                                lineWidth: FeedMediaBottomStyle.avatarStrokeWidth
                            )
                    }
                    .zIndex(0)
            }
        }
        .padding(.trailing, overflowCount > 0 || visible.count > 1 ? 2 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let names = participants.map(\.displayName).joined(separator: ", ")
        return names.isEmpty ? "Participants" : "Participants: \(names)"
    }
}
