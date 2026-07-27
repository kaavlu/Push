//
//  RegionalActivityPuck.swift
//  Push
//

import SwiftUI

struct RegionalActivityPuck: View {
    let model: RegionalPuckModel
    var isSelected = false

    @Environment(\.pushLayout) private var layout
    @State private var isHaloExpanded = false

    private var metrics: RegionalActivityPuckMetrics {
        RegionalActivityPuckMetrics(memberCount: model.memberCount, scale: layout.puckScale)
    }

    private var stateColor: Color {
        if model.containsCurrentUser {
            return PushAvailabilityTokens.freeNow
        }
        return PushGlassCreamTokens.creamBase
    }

    var body: some View {
        ZStack {
            currentUserHalo
            core
            clusterChip(model.regionAbbreviation)
                .offset(y: PushRegionalPuckTokens.chipVerticalOffset)
        }
        .scaleEffect(metrics.uniformScale)
        .frame(width: metrics.frameWidth, height: metrics.frameHeight)
        .scaleEffect(isSelected ? PushRegionalPuckTokens.selectedScale : 1)
        .animation(PushMotion.selection, value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected" : "")
        .onAppear {
            guard model.containsCurrentUser else { return }
            withAnimation(PushMotion.mapPulse) {
                isHaloExpanded = true
            }
        }
    }

    @ViewBuilder
    private var currentUserHalo: some View {
        if model.containsCurrentUser {
            Capsule()
                .stroke(
                    PushAvailabilityTokens.freeNow.opacity(PushRegionalPuckTokens.haloOpacity),
                    lineWidth: PushRegionalPuckTokens.haloLineWidth
                )
                .frame(
                    width: PushRegionalPuckTokens.baseWidth,
                    height: PushRegionalPuckTokens.coreHeight
                )
                .scaleEffect(
                    isHaloExpanded
                        ? PushRegionalPuckTokens.haloMaxScale
                        : PushRegionalPuckTokens.haloMinScale
                )
                .opacity(isHaloExpanded ? PushRegionalPuckTokens.haloLowOpacity : 1)
        }
    }

    private var core: some View {
        RegionalPuckAvatarStack(
            friends: model.representativeAvatars,
            avatarSize: PushRegionalPuckTokens.avatarSize
        )
        .frame(
            width: PushRegionalPuckTokens.baseWidth,
            height: PushRegionalPuckTokens.coreHeight
        )
        .pushPuckGlass(cornerRadius: PushRegionalPuckTokens.coreHeight / 2)
        .overlay {
            Capsule()
                .stroke(
                    Color.white.opacity(PushRegionalPuckTokens.avatarStrokeOpacity),
                    lineWidth: PushRegionalPuckTokens.contrastRingWidth
                )
        }
        .overlay {
            Capsule()
                .stroke(
                    stateColor.opacity(stateRingOpacity),
                    lineWidth: isSelected
                        ? PushRegionalPuckTokens.selectedRingWidth
                        : PushRegionalPuckTokens.stateRingWidth
                )
        }
    }

    private func clusterChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .kerning(PushRegionalPuckTokens.chipKerning)
            .foregroundStyle(PushControlColors.textEspresso)
            .lineLimit(1)
            .minimumScaleFactor(PushRegionalPuckTokens.minimumTextScale)
            .frame(
                width: PushRegionalPuckTokens.chipWidth,
                height: PushRegionalPuckTokens.chipHeight
            )
            .background {
                Capsule()
                    .fill(
                        PushGlassCreamTokens.creamBase.opacity(
                            PushRegionalPuckTokens.chipFillOpacity
                        )
                    )
            }
            .overlay {
                Capsule()
                    .stroke(
                        Color.white.opacity(PushRegionalPuckTokens.chipStrokeOpacity),
                        lineWidth: PushRegionalPuckTokens.chipStrokeWidth
                    )
            }
            .shadow(
                color: PushColorPalette.Accent.walnut.opacity(
                    PushRegionalPuckTokens.badgeShadowOpacity
                ),
                radius: PushRegionalPuckTokens.badgeShadowRadius,
                y: PushRegionalPuckTokens.badgeShadowYOffset
            )
    }

    private var stateRingOpacity: Double {
        if model.containsCurrentUser { return PushRegionalPuckTokens.currentUserRingOpacity }
        return PushRegionalPuckTokens.creamRingOpacity
    }

    private var accessibilityLabel: String {
        let inclusion = model.containsCurrentUser ? ", including you" : ""
        return "\(model.regionName), \(model.memberCount) people\(inclusion), \(model.availabilitySummary)"
    }
}

private struct RegionalPuckAvatarStack: View {
    let friends: [FriendPuckData]
    let avatarSize: CGFloat

    private var displayedFriends: [FriendPuckData] {
        Array(friends.prefix(3))
    }

    var body: some View {
        HStack(spacing: -PushRegionalPuckTokens.avatarOverlap) {
            ForEach(Array(displayedFriends.enumerated()), id: \.element.id) { index, friend in
                PushPersonAvatar(
                    imageAssetName: friend.profileImageAssetName,
                    fallbackInitials: friend.avatarPlaceholder,
                    fallbackStyle: .dark,
                    size: avatarSize
                )
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(PushRegionalPuckTokens.avatarStrokeOpacity),
                            lineWidth: PushRegionalPuckTokens.avatarStrokeWidth
                        )
                }
                .zIndex(Double(displayedFriends.count - index))
            }

            if displayedFriends.isEmpty {
                PushPersonAvatar(
                    imageAssetName: nil,
                    fallbackInitials: "P",
                    fallbackStyle: .dark,
                    size: avatarSize
                )
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(PushRegionalPuckTokens.avatarStrokeOpacity),
                            lineWidth: PushRegionalPuckTokens.avatarStrokeWidth
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RegionalActivityPuckMetrics: Equatable {
    let uniformScale: CGFloat
    let width: CGFloat
    let height: CGFloat
    let avatarSize: CGFloat
    let frameWidth: CGFloat
    let frameHeight: CGFloat
    let regionVerticalOffset: CGFloat
    let countFontSize: CGFloat

    init(memberCount: Int, scale: CGFloat = 1) {
        let populationScale: CGFloat
        switch memberCount {
        case ...5:
            populationScale = PushRegionalPuckTokens.populationScaleSmall
        case 6...15:
            populationScale = PushRegionalPuckTokens.populationScaleMedium
        default:
            populationScale = PushRegionalPuckTokens.populationScaleLarge
        }

        uniformScale = PushRegionalPuckTokens.overallScale * populationScale * scale
        width = PushRegionalPuckTokens.baseWidth * uniformScale
        height = PushRegionalPuckTokens.coreHeight * uniformScale
        avatarSize = PushRegionalPuckTokens.avatarSize * uniformScale
        frameWidth = (
            PushRegionalPuckTokens.baseWidth + PushRegionalPuckTokens.frameWidthPadding
        ) * uniformScale
        frameHeight = PushRegionalPuckTokens.frameHeight * uniformScale
        regionVerticalOffset = PushRegionalPuckTokens.chipVerticalOffset * uniformScale
        countFontSize = UIFont.preferredFont(forTextStyle: .caption2).pointSize * uniformScale
    }
}

/// Compatibility shim for existing hit-testing/tests while the regional
/// metrics now live on the DS variant above.
enum RegionalActivityPuckLayout {
    static let sizeSmall = PushRegionalPuckTokens.baseWidth
        * PushRegionalPuckTokens.overallScale
        * PushRegionalPuckTokens.populationScaleSmall
    static let sizeMedium = PushRegionalPuckTokens.baseWidth
        * PushRegionalPuckTokens.overallScale
        * PushRegionalPuckTokens.populationScaleMedium
    static let sizeLarge = PushRegionalPuckTokens.baseWidth
        * PushRegionalPuckTokens.overallScale
        * PushRegionalPuckTokens.populationScaleLarge

    static func coreSize(memberCount: Int, scale: CGFloat = 1) -> CGFloat {
        RegionalActivityPuckMetrics(memberCount: memberCount, scale: scale).width
    }
}

struct RegionalPuckDetailCard: View {
    let model: RegionalPuckModel
    let onZoomIn: () -> Void

    var body: some View {
        HStack(spacing: PushRegionalPuckTokens.detailContentSpacing) {
            RegionalPuckAvatarStack(
                friends: model.representativeAvatars,
                avatarSize: PushRegionalPuckTokens.detailAvatarSize
            )
            .frame(
                width: PushRegionalPuckTokens.detailAvatarStackSize,
                height: PushRegionalPuckTokens.detailAvatarStackSize
            )

            VStack(alignment: .leading, spacing: PushRegionalPuckTokens.detailTextSpacing) {
                Text(model.regionName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(1)

                Text(peopleSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textPrimary)
                    .lineLimit(1)

                Text(model.availabilitySummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(PushRegionalPuckTokens.minimumTextScale)
            }

            Spacer(minLength: 0)

            PushCircleIconButton(
                systemImageName: "plus.magnifyingglass",
                accessibilityLabel: "Zoom into \(model.regionName)",
                action: onZoomIn
            )
        }
        .padding(.horizontal, PushRegionalPuckTokens.detailHorizontalPadding)
        .padding(.vertical, PushRegionalPuckTokens.detailVerticalPadding)
        .pushMapControlGlass(cornerRadius: PushRegionalPuckTokens.detailCornerRadius)
        .accessibilityElement(children: .contain)
    }

    private var peopleSummary: String {
        let count = "\(model.memberCount) \(model.memberCount == 1 ? "person" : "people")"
        let inclusion = model.containsCurrentUser ? "You’re here" : "You’re not here"
        return "\(count) · \(inclusion)"
    }
}

#if DEBUG
struct RegionalActivityPuck_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            HStack(spacing: 20) {
                ForEach(PuckLabFixtures.regionalScenarios) { scenario in
                    RegionalActivityPuck(
                        model: scenario.model,
                        isSelected: scenario.model.regionName == "Chicago"
                    )
                }
            }
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
