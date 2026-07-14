//
//  OnboardingLabTheme.swift
//  Push
//
//  Design tokens for the Onboarding Lab, mapped verbatim from the
//  Push Design System (tokens/colors.css, tokens/effects.css). Kept
//  local to the lab so iterating on the flow never touches shipping
//  Push styling. See docs issue #22.
//

import SwiftUI

/// Semantic aliases for onboarding. Values come from the shared Push
/// design system so the lab does not own an independent palette.
enum OnboardingLabColor {
    static let sunbeam = PushColorPalette.Accent.sunbeam
    static let walnut = PushColorPalette.Accent.walnut
    static let sage = PushColorPalette.Accent.sageGreen
    static let mint = PushColorPalette.Accent.mintFoam

    static let espresso = PushControlColors.textEspresso
    static let textSecondary = PushControlColors.textSecondary
    static let textTertiary = PushControlColors.textTertiary

    static let stateFree = PuckColorTokens.freeNow
    static let stateMaybe = PuckColorTokens.maybeDown
    static let stateJoinable = PuckColorTokens.joinable
    static let stateDriving = PuckColorTokens.driving
    static let stateFreeText = PushColorPalette.Onboarding.freeNowText
    static let stateDrivingText = PushColorPalette.Onboarding.drivingText
    static let stateVague = PushColorPalette.Onboarding.purpleAccent

    static let ctaTop = PushColorPalette.Onboarding.ctaTop
    static let ctaBottom = PushColorPalette.Onboarding.ctaBottom
    static let ctaLabel = PushColorPalette.Onboarding.ctaLabel
    static let appleButtonFill = PushColorPalette.Onboarding.appleButtonFill
    static let googleButtonText = PushColorPalette.Onboarding.googleButtonText

    static let screenTop = PushColorPalette.Onboarding.screenTop
    static let screenMid = PushColorPalette.Onboarding.screenMiddle
    static let screenBottom = PushColorPalette.Onboarding.screenBottom

    static let fieldFill = PushColorPalette.Onboarding.fieldFill
    static let keyFill = PushColorPalette.Onboarding.keyFill
    static let keyFillActive = PushColorPalette.Onboarding.keyFillActive
    static let miniMapTop = PushColorPalette.Onboarding.miniMapTop
    static let miniMapBottom = PushColorPalette.Onboarding.miniMapBottom
    static let notificationBadge = PushColorPalette.Onboarding.notificationBadge

    static let warmShadow = PushGlassStyle.shadowColor
}

/// Thin aliases over the shared Push typography helpers.
enum OnboardingLabFont {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        PushTypography.rounded(size: size, weight: weight)
    }

    static func text(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        PushTypography.text(size: size, weight: weight)
    }
}

/// Motion tokens (tokens/effects.css).
enum OnboardingLabMotion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.68)
    static let standard = Animation.easeInOut(duration: 0.24)
    static let fast = Animation.easeInOut(duration: 0.18)
    static let screenIn = Animation.easeOut(duration: 0.42)
}

/// Shared metrics used across every screen.
enum OnboardingLabMetric {
    static func screenHorizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 18, standard: 21, large: 24) }
    static let ctaHeight: CGFloat = 54
    static let ctaCornerRadius: CGFloat = 27
    static let cardCornerRadius: CGFloat = 24
    static let fieldHeight: CGFloat = 56
    static let fieldCornerRadius: CGFloat = 16
    static func contentTopInset(_ layout: PushAdaptiveLayout) -> CGFloat { layout.onboardingTopInset }
    static let avatarRingWidth: CGFloat = 3
}
