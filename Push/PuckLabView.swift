//
//  PuckLabView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

#if DEBUG
import SwiftUI

struct PuckLabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PuckLabLayout.sectionSpacing) {
                header
                scenarioGrid
            }
            .padding(.horizontal, PuckLabLayout.horizontalPadding)
            .padding(.vertical, PuckLabLayout.verticalPadding)
        }
        .background(PuckLabMapBackdrop())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PuckLabLayout.headerSpacing) {
            Text("Puck Lab")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(PuckLabColors.primaryText)

            Text("Single-friend puck states first, with clusters still available for comparison.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PuckLabColors.secondaryText)
        }
        .padding(.top, PuckLabLayout.headerTopPadding)
    }

    private var scenarioGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: PuckLabLayout.cardMinimumWidth), spacing: PuckLabLayout.cardSpacing)],
            spacing: PuckLabLayout.cardSpacing
        ) {
            ForEach(PuckLabFixtures.scenarios) { scenario in
                PuckLabScenarioCard(scenario: scenario)
            }
        }
    }
}

private struct PuckLabScenarioCard: View {
    let scenario: PuckLabScenario

    var body: some View {
        VStack(spacing: PuckLabLayout.cardContentSpacing) {
            puck
                .frame(height: PuckLabLayout.puckStageHeight)

            VStack(spacing: PuckLabLayout.labelSpacing) {
                Text(scenario.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PuckLabColors.primaryText)

                Text(scenario.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PuckLabColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(PuckLabLayout.subtitleLineLimit)

                availabilityLine
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PuckLabLayout.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: PuckLabLayout.cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    RoundedRectangle(cornerRadius: PuckLabLayout.cardCornerRadius, style: .continuous)
                        .fill(PuckLabColors.cardTint)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: PuckLabLayout.cardCornerRadius, style: .continuous)
                .stroke(PuckLabColors.cardStroke, lineWidth: PuckLabLayout.cardStrokeWidth)
        }
    }

    @ViewBuilder
    private var puck: some View {
        if scenario.puckStyle == .friendGroup {
            FriendGroupPuck(friends: scenario.friends, size: PuckLabLayout.labSinglePuckSize)
        } else if let friend = scenario.friends.first, scenario.friends.count == PuckLabLayout.singleFriendCount {
            FriendPuck(friend: friend, size: PuckLabLayout.labSinglePuckSize)
        } else {
            FriendClusterPuck(friends: scenario.friends, size: PuckLabLayout.labClusterPuckSize)
        }
    }

    private var availabilityLine: some View {
        Text(scenario.friends.map(\.availability.title).joined(separator: " · "))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(PuckLabColors.tertiaryText)
            .lineLimit(PuckLabLayout.availabilityLineLimit)
            .minimumScaleFactor(PuckLabLayout.minimumTextScale)
    }
}

private struct PuckLabMapBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: PuckLabColors.backdropGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(PuckLabColors.warmGlow)
                .frame(width: PuckLabLayout.largeGlowSize, height: PuckLabLayout.largeGlowSize)
                .blur(radius: PuckLabLayout.glowBlurRadius)
                .offset(x: PuckLabLayout.largeGlowXOffset, y: PuckLabLayout.largeGlowYOffset)

            Circle()
                .fill(PuckLabColors.coolGlow)
                .frame(width: PuckLabLayout.smallGlowSize, height: PuckLabLayout.smallGlowSize)
                .blur(radius: PuckLabLayout.glowBlurRadius)
                .offset(x: PuckLabLayout.smallGlowXOffset, y: PuckLabLayout.smallGlowYOffset)
        }
    }
}

private enum PuckLabColors {
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let tertiaryText = Color.white.opacity(0.58)
    static let cardTint = Color.white.opacity(0.12)
    static let cardStroke = Color.white.opacity(0.36)
    static let warmGlow = PushColorPalette.Accent.sunbeam.opacity(0.32)
    static let coolGlow = Color(red: 0.24, green: 0.64, blue: 1.0).opacity(0.26)
    static let backdropGradient = [
        Color(red: 0.10, green: 0.14, blue: 0.18),
        Color(red: 0.14, green: 0.20, blue: 0.17),
        Color(red: 0.08, green: 0.10, blue: 0.15)
    ]
}

private enum PuckLabLayout {
    static let sectionSpacing: CGFloat = 24
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 24
    static let headerSpacing: CGFloat = 6
    static let headerTopPadding: CGFloat = 16
    static let cardMinimumWidth: CGFloat = 160
    static let cardSpacing: CGFloat = 16
    static let cardContentSpacing: CGFloat = 14
    static let cardPadding: CGFloat = 18
    static let cardCornerRadius: CGFloat = 28
    static let cardStrokeWidth: CGFloat = 0.8
    static let puckStageHeight: CGFloat = 138
    static let labSinglePuckSize: CGFloat = 96
    static let labClusterPuckSize: CGFloat = 122
    static let labelSpacing: CGFloat = 5
    static let subtitleLineLimit = 2
    static let availabilityLineLimit = 1
    static let minimumTextScale = 0.72
    static let singleFriendCount = 1
    static let largeGlowSize: CGFloat = 320
    static let smallGlowSize: CGFloat = 260
    static let glowBlurRadius: CGFloat = 52
    static let largeGlowXOffset: CGFloat = -120
    static let largeGlowYOffset: CGFloat = -220
    static let smallGlowXOffset: CGFloat = 130
    static let smallGlowYOffset: CGFloat = 240
}

struct PuckLabView_Previews: PreviewProvider {
    static var previews: some View {
        PuckLabView()
    }
}
#endif
