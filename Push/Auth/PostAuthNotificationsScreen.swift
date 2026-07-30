// Push/Auth/PostAuthNotificationsScreen.swift
import SwiftUI

/// Optional notifications primer — never hard-gates completion.
struct PostAuthNotificationsScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel
    @State private var revealStep = 0

    var body: some View {
        VStack(spacing: 0) {
            bell
                .padding(.top, NotificationsLayout.heroTop)
                .onboardingCascadeVisible(revealStep >= 1)
            OnboardingHeader(
                title: NotificationsCopy.title,
                subtitle: NotificationsCopy.subtitle,
                alignment: .center
            )
            .padding(.top, NotificationsLayout.headerTop)
            .onboardingCascadeVisible(revealStep >= 2)
            samples
                .padding(.top, NotificationsLayout.samplesTop)
                .onboardingCascadeVisible(revealStep >= 3)
            Spacer(minLength: NotificationsLayout.ctaSpacerMin)
            OnboardingCTAButton(title: model.isBusy ? "Working…" : "Turn on notifications") {
                Task { await model.enableNotifications() }
            }
            .disabled(model.isBusy || revealStep < 4)
            .onboardingCascadeVisible(revealStep >= 4)
            OnboardingTextButton(title: "Maybe later") {
                Task { await model.skipNotifications() }
            }
            .disabled(model.isBusy || revealStep < 5)
            .onboardingCascadeVisible(revealStep >= 5)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(
            .top,
            OnboardingLabMetric.contentTopInset(layout)
                + layout.value(compact: 2, standard: 3, large: 4)
        )
        .padding(.bottom, NotificationsLayout.bottomPadding)
        .animation(OnboardingCascadeTiming.cascade, value: revealStep)
        .task { await runCascade() }
    }

    private var bell: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: NotificationsLayout.iconSize, weight: .semibold))
            .foregroundStyle(OnboardingLabColor.espresso)
            .frame(width: NotificationsLayout.heroSize, height: NotificationsLayout.heroSize)
            .background(
                RadialGradient(
                    colors: [
                        OnboardingLabColor.sunbeam,
                        OnboardingLabColor.sunbeam.opacity(NotificationsLayout.heroGradientEndOpacity)
                    ],
                    center: .init(x: 0.5, y: 0.4),
                    startRadius: NotificationsLayout.heroGradientStartRadius,
                    endRadius: NotificationsLayout.heroGradientEndRadius
                ),
                in: Circle()
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(OnboardingLabColor.notificationBadge)
                    .frame(
                        width: NotificationsLayout.badgeSize,
                        height: NotificationsLayout.badgeSize
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                OnboardingLabColor.sunbeam.opacity(NotificationsLayout.badgeStrokeOpacity),
                                lineWidth: NotificationsLayout.badgeStrokeWidth
                            )
                    )
                    .offset(
                        x: NotificationsLayout.badgeOffsetX,
                        y: NotificationsLayout.badgeOffsetY
                    )
            }
            .shadow(
                color: OnboardingLabColor.sunbeam.opacity(NotificationsLayout.heroShadowOpacity),
                radius: NotificationsLayout.heroShadowRadius,
                y: NotificationsLayout.heroShadowY
            )
            .accessibilityHidden(true)
    }

    private var samples: some View {
        VStack(spacing: NotificationsLayout.sampleSpacing) {
            sampleRow(title: "sid is 2 min away 🚗", subtitle: "heading toward the mission")
            sampleRow(title: "maya started a Push ☕", subtitle: "coffee at blue bottle · join?")
            sampleRow(title: "3 friends are free now", subtitle: "nobody's texting the group chat")
        }
    }

    private func sampleRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: NotificationsLayout.sampleTextSpacing) {
            Text(title)
                .font(OnboardingLabFont.text(14, .bold))
                .foregroundStyle(OnboardingLabColor.espresso)
            Text(subtitle)
                .font(OnboardingLabFont.text(12, .regular))
                .foregroundStyle(OnboardingLabColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, NotificationsLayout.samplePaddingH)
        .padding(.vertical, NotificationsLayout.samplePaddingV)
        .background(
            Color.white.opacity(NotificationsLayout.sampleFillOpacity),
            in: RoundedRectangle(
                cornerRadius: NotificationsLayout.sampleCornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: OnboardingLabColor.warmShadow.opacity(NotificationsLayout.sampleShadowOpacity),
            radius: NotificationsLayout.sampleShadowRadius,
            y: NotificationsLayout.sampleShadowY
        )
    }

    private func runCascade() async {
        for step in 1...5 {
            OnboardingCascadeRunner.step(&revealStep, to: step)
            await OnboardingCascadeRunner.sleepStagger()
        }
    }
}

private enum NotificationsCopy {
    static let title = "Never miss the moment."
    static let subtitle =
        "Optional — a gentle nudge when something's happening. You can change this anytime in Settings."
}

private enum NotificationsLayout {
    static let heroTop: CGFloat = 6
    static let heroSize: CGFloat = 96
    static let iconSize: CGFloat = 40
    static let heroGradientStartRadius: CGFloat = 4
    static let heroGradientEndRadius: CGFloat = 60
    static let heroGradientEndOpacity = 0.5
    static let heroShadowOpacity = 0.35
    static let heroShadowRadius: CGFloat = 13
    static let heroShadowY: CGFloat = 12
    static let badgeSize: CGFloat = 16
    static let badgeStrokeWidth: CGFloat = 3
    static let badgeStrokeOpacity = 0.9
    static let badgeOffsetX: CGFloat = -14
    static let badgeOffsetY: CGFloat = 14
    static let headerTop: CGFloat = 20
    static let samplesTop: CGFloat = 24
    static let sampleSpacing: CGFloat = 10
    static let sampleTextSpacing: CGFloat = 1
    static let samplePaddingH: CGFloat = 15
    static let samplePaddingV: CGFloat = 13
    static let sampleCornerRadius: CGFloat = 18
    static let sampleFillOpacity = 0.6
    static let sampleShadowOpacity = 0.1
    static let sampleShadowRadius: CGFloat = 7
    static let sampleShadowY: CGFloat = 6
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
}
