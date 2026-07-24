//
//  PushGlassStyle.swift
//  Push
//
//  Control colors/typography plus migration shims for named surfaces (Wave 4).
//  Prefer pushControlGlass / PushControlGlassTokens for new glass chrome.
//

import SwiftUI

/// Bridge tokens used by legacy call sites and map/puck glass that still
/// reference `PushGlassStyle`. Values match `PushControlGlassTokens`.
enum PushGlassStyle {
    static let materialPresenceOpacity = PushControlGlassTokens.materialPresenceOpacity
    static let warmTint = PushControlGlassTokens.warmTint
    static let tintOpacity = PushControlGlassTokens.tintOpacity
    static let strokeOpacity = PushControlGlassTokens.strokeOpacity
    static let strokeWidth = PushControlGlassTokens.strokeWidth
    static let shadowColor = PushControlGlassTokens.shadowColor
    static let shadowOpacity = PushControlGlassTokens.shadowOpacity
    static let shadowRadius = PushControlGlassTokens.shadowRadius
    static let shadowYOffset = PushControlGlassTokens.shadowYOffset
}

enum PushControlStyle {
    static let activeFillOpacity = 1.0
    static let inactiveForegroundOpacity = PushOpacityTokens.inactiveLabel
    static let primaryStrokeOpacity = 0.72
    static let primaryGlowOpacity = 0.34
}

enum PushOnboardingGlassStyle {
    static let warmTint = PushColorPalette.Onboarding.glassTint
    static let stroke = Color.white.opacity(0.66)
    static let shadow = PushGlassStyle.shadowColor.opacity(PushGlassStyle.shadowOpacity)
    static let shadowRadius: CGFloat = 15
    static let shadowYOffset: CGFloat = 14
}

enum PushOnboardingControlStyle {
    static let primaryGradient = LinearGradient(
        colors: [PushColorPalette.Onboarding.ctaTop, PushColorPalette.Onboarding.ctaBottom],
        startPoint: .top,
        endPoint: .bottom
    )
    static let pressScale = PushMotion.pressScale
    static let pressAnimation = PushMotion.press
    static let primaryShadowOpacity = 0.32
    static let primaryShadowRadius: CGFloat = 12
    static let primaryShadowYOffset: CGFloat = 12
    static let secondaryShadowOpacity = 0.14
    static let secondaryShadowRadius: CGFloat = 10
    static let secondaryShadowYOffset: CGFloat = 8
}

enum PushControlColors {
    static let activeForeground = PushColorPalette.Accent.walnut
    static let inactiveForeground = PushColorPalette.Accent.walnut.opacity(PushControlStyle.inactiveForegroundOpacity)
    static let activeFill = PushColorPalette.Accent.sunbeam.opacity(PushControlStyle.activeFillOpacity)
    // Warm red for destructive actions (delete/cancel), kept out of the
    // walnut/sunbeam palette on purpose so it reads unambiguously as danger.
    static let destructive = Color(red: 0.76, green: 0.24, blue: 0.19)

    // Text hierarchy — walnut-based, no black
    static let textEspresso = Color(red: 0.22, green: 0.12, blue: 0.05)
    static let textPrimary = PushColorPalette.Accent.walnut
    static let textSecondary = PushColorPalette.Accent.walnut.opacity(0.70)
    static let textTertiary = PushColorPalette.Accent.walnut.opacity(0.52)
}

enum PushTypography {
    static func rounded(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func text(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    /// Prefer `pushControlGlass` (DS-010).
    @ViewBuilder
    func pushGlassBackground(cornerRadius: CGFloat, showsShadow: Bool = true) -> some View {
        pushControlGlass(cornerRadius: cornerRadius, showsShadow: showsShadow)
    }

    /// Prefer `pushControlGlassMaterial` (material fallback path).
    @ViewBuilder
    func pushMaterialBackground(cornerRadius: CGFloat, showsShadow: Bool = true) -> some View {
        pushControlGlassMaterial(cornerRadius: cornerRadius, showsShadow: showsShadow)
    }

    /// Onboarding/auth domain glass — keep domain-local (DS-016).
    func pushOnboardingGlassBackground(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(.ultraThinMaterial, in: shape)
            .background(shape.fill(PushOnboardingGlassStyle.warmTint))
            .overlay {
                shape.stroke(
                    PushOnboardingGlassStyle.stroke,
                    lineWidth: PushGlassStyle.strokeWidth
                )
            }
            .shadow(
                color: PushOnboardingGlassStyle.shadow,
                radius: PushOnboardingGlassStyle.shadowRadius,
                y: PushOnboardingGlassStyle.shadowYOffset
            )
    }
}

struct PushPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? PushOnboardingControlStyle.pressScale : 1)
            .animation(PushOnboardingControlStyle.pressAnimation, value: configuration.isPressed)
    }
}
