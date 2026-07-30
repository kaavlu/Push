// Push/Auth/PostAuthOnboardingScreens.swift
import SwiftUI

// Teach + optional graph screens for post-auth onboarding.
// Combined location/value primer + blocked live in PostAuthLocationScreens.swift

// MARK: - Ghost

struct PostAuthGhostScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ghostHero
                .frame(maxWidth: .infinity)
                .padding(.top, GhostTeachLayout.heroTop)
            OnboardingHeader(
                title: "You're visible to friends.",
                subtitle: "Go invisible anytime with Ghost in Profile. You're on by default so friends can find you.",
                alignment: .center
            )
            .padding(.top, GhostTeachLayout.headerTop)
            Spacer(minLength: GhostTeachLayout.ctaSpacerMin)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromGhost()
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, GhostTeachLayout.bottomPadding)
    }

    private var ghostHero: some View {
        Image(systemName: "eye.slash.fill")
            .font(.system(size: GhostTeachLayout.iconSize, weight: .semibold))
            .foregroundStyle(OnboardingLabColor.espresso)
            .frame(width: GhostTeachLayout.heroSize, height: GhostTeachLayout.heroSize)
            .background(
                Circle()
                    .fill(OnboardingLabColor.walnut.opacity(GhostTeachLayout.heroFillOpacity))
            )
            .overlay(
                Circle()
                    .stroke(OnboardingLabColor.walnut.opacity(GhostTeachLayout.heroStrokeOpacity), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Coordinate (Pushes + Moments)

struct PostAuthCoordinateScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Make plans. Keep moments.",
                subtitle: "Coordinate without the group chat thrash; save the hang after."
            )
            VStack(spacing: CoordinateTeachLayout.cardSpacing) {
                teachCard(
                    symbol: "paperplane.fill",
                    title: "Push",
                    body: "Start a Push when something's forming"
                )
                teachCard(
                    symbol: "photo.on.rectangle.angled",
                    title: "Moment",
                    body: "Share photos from the hang on Feed"
                )
            }
            .padding(.top, CoordinateTeachLayout.cardsTop)
            Spacer(minLength: CoordinateTeachLayout.ctaSpacerMin)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromCoordinate()
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, CoordinateTeachLayout.bottomPadding)
    }

    private func teachCard(symbol: String, title: String, body: String) -> some View {
        HStack(spacing: CoordinateTeachLayout.cardInnerSpacing) {
            Image(systemName: symbol)
                .font(.system(size: CoordinateTeachLayout.symbolSize, weight: .semibold))
                .foregroundStyle(OnboardingLabColor.espresso)
                .frame(width: CoordinateTeachLayout.symbolWell, height: CoordinateTeachLayout.symbolWell)
                .background(
                    Circle()
                        .fill(OnboardingLabColor.sunbeam.opacity(CoordinateTeachLayout.symbolFillOpacity))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OnboardingLabFont.rounded(16, .bold))
                    .foregroundStyle(OnboardingLabColor.espresso)
                Text(body)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(OnboardingLabColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CoordinateTeachLayout.cardPaddingH)
        .padding(.vertical, CoordinateTeachLayout.cardPaddingV)
        .background(
            Color.white.opacity(CoordinateTeachLayout.cardFillOpacity),
            in: RoundedRectangle(cornerRadius: CoordinateTeachLayout.cardCornerRadius, style: .continuous)
        )
        .shadow(
            color: OnboardingLabColor.warmShadow.opacity(CoordinateTeachLayout.cardShadowOpacity),
            radius: CoordinateTeachLayout.cardShadowRadius,
            y: CoordinateTeachLayout.cardShadowY
        )
    }
}

private enum GhostTeachLayout {
    static let heroTop: CGFloat = 12
    static let heroSize: CGFloat = 96
    static let iconSize: CGFloat = 36
    static let heroFillOpacity = 0.08
    static let heroStrokeOpacity = 0.12
    static let headerTop: CGFloat = 20
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
}

private enum CoordinateTeachLayout {
    static let cardsTop: CGFloat = 24
    static let cardSpacing: CGFloat = 12
    static let cardInnerSpacing: CGFloat = 14
    static let cardPaddingH: CGFloat = 16
    static let cardPaddingV: CGFloat = 14
    static let cardCornerRadius: CGFloat = 18
    static let cardFillOpacity = 0.6
    static let cardShadowOpacity = 0.1
    static let cardShadowRadius: CGFloat = 7
    static let cardShadowY: CGFloat = 6
    static let symbolSize: CGFloat = 18
    static let symbolWell: CGFloat = 44
    static let symbolFillOpacity = 0.55
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
}

// Contacts / find people / done live in PostAuthConnectScreens.swift.
