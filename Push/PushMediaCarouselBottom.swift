//
//  PushMediaCarouselBottom.swift
//  Push
//
//  Bottom interaction chrome for Feed media cards: participant stack, names,
//  play/pause, and Add yours. Anchored inside the media frame.
//

import SwiftUI

// MARK: - Bottom section

struct FeedMediaBottomInteraction: View {
    let participants: [FeedMediaParticipant]
    let contributorName: String
    let canAddYours: Bool
    let isPlaying: Bool
    let onTogglePlayback: () -> Void
    var onAddYours: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            FeedMediaBottomScrim()
                .allowsHitTesting(false)

            VStack(spacing: FeedMediaLayout.bottomRowToCTASpacing) {
                participantRow
                if canAddYours {
                    FeedMediaAddYoursButton(action: onAddYours)
                }
            }
            .padding(.horizontal, FeedMediaLayout.bottomHorizontalInset)
            .padding(.bottom, FeedMediaLayout.bottomEdgeInset)
        }
    }

    private var participantRow: some View {
        HStack(alignment: .center, spacing: FeedMediaBottomStyle.rowToPlaySpacing) {
            HStack(alignment: .center, spacing: FeedMediaBottomStyle.avatarToTextSpacing) {
                FeedMediaParticipantAvatarStack(participants: participants)

                VStack(alignment: .leading, spacing: FeedMediaBottomStyle.textStackSpacing) {
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
                    Text(contributorName)
                        .font(FeedMediaBottomStyle.contributorFont)
                        .foregroundStyle(
                            FeedMediaBottomStyle.textColor.opacity(FeedMediaBottomStyle.contributorOpacity)
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .shadow(
                            color: Color.black.opacity(0.30),
                            radius: FeedMediaBottomStyle.textShadowRadius,
                            y: FeedMediaBottomStyle.textShadowY
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .layoutPriority(0)

            FeedMediaPlaybackButton(isPlaying: isPlaying, action: onTogglePlayback)
                .layoutPriority(1)
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

// MARK: - Playback

private struct FeedMediaPlaybackButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(
                    size: FeedMediaBottomStyle.playIconSize,
                    weight: .semibold
                ))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(
                    width: FeedMediaBottomStyle.playButtonSize,
                    height: FeedMediaBottomStyle.playButtonSize
                )
                .pushMapControlGlass(
                    cornerRadius: FeedMediaBottomStyle.playCornerRadius,
                    treatment: .profileButton
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

// MARK: - Add yours

/// Sunbeam pill CTA matching DS-002 solid primary treatment, with leading plus.
private struct FeedMediaAddYoursButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FeedMediaBottomStyle.addYoursLabelSpacing) {
                Image(systemName: "plus")
                    .font(.system(
                        size: FeedMediaBottomStyle.addYoursIconSize,
                        weight: .bold
                    ))
                Text("Add yours")
                    .font(FeedMediaBottomStyle.addYoursFont)
            }
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(maxWidth: .infinity)
            .frame(height: FeedMediaBottomStyle.addYoursHeight)
            .background(Capsule().fill(PushControlColors.activeFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add yours")
    }
}
