// Push/Auth/PostAuthOnboardingScreens.swift
import SwiftUI

// Teach screens for post-auth onboarding.
// Ghost → PostAuthGhostScreen.swift · location → PostAuthLocationScreens.swift

// MARK: - Coordinate (Pushes + Moments)

struct PostAuthCoordinateScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel
    @State private var revealStep = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Make plans. Keep moments.",
                subtitle: "Coordinate without the group chat thrash; save the hang after."
            )
            .onboardingCascadeVisible(revealStep >= 1)
            VStack(spacing: CoordinateTeachLayout.cardSpacing) {
                teachCard(
                    symbol: "paperplane.fill",
                    title: "Push",
                    body: "Start a Push when something's forming"
                )
                .onboardingCascadeVisible(revealStep >= 2)
                teachCard(
                    symbol: "photo.on.rectangle.angled",
                    title: "Moment",
                    body: "Share photos from the hang on Feed"
                )
                .onboardingCascadeVisible(revealStep >= 3)
            }
            .padding(.top, CoordinateTeachLayout.cardsTop)
            Spacer(minLength: CoordinateTeachLayout.ctaSpacerMin)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromCoordinate()
            }
            .disabled(model.isBusy || revealStep < 4)
            .onboardingCascadeVisible(revealStep >= 4)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, CoordinateTeachLayout.bottomPadding)
        .animation(PushMotion.contentCrossfade, value: revealStep)
        .task { await runCascade() }
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

    private func runCascade() async {
        for step in 1...4 {
            OnboardingCascadeRunner.step(&revealStep, to: step)
            await OnboardingCascadeRunner.sleepStagger()
        }
    }
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
