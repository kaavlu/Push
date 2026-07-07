//
//  PushGlassStyle.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

enum PushGlassStyle {
    static let materialPresenceOpacity = 0.68
    // Warm cream tint instead of neutral white
    static let warmTint = Color(red: 1.0, green: 0.95, blue: 0.84)
    static let tintOpacity = 0.22
    // Stroke: keep white but slightly softer
    static let strokeOpacity = 0.52
    static let strokeWidth: CGFloat = 0.8
    // Walnut-amber shadow instead of black
    static let shadowColor = Color(red: 0.55, green: 0.36, blue: 0.16)
    static let shadowOpacity = 0.18
    static let shadowRadius: CGFloat = 24
    static let shadowYOffset: CGFloat = 10
}

enum PushControlStyle {
    static let activeFillOpacity = 1.0
    static let inactiveForegroundOpacity = 0.7
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
    static let pressScale = 0.97
    static let pressAnimation = Animation.easeInOut(duration: 0.18)
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

    // Text hierarchy — walnut-based, no black
    static let textEspresso = Color(red: 0.22, green: 0.12, blue: 0.05) // deep warm dark for names/titles
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
    @ViewBuilder
    func pushGlassBackground(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            pushMaterialBackground(cornerRadius: cornerRadius)
        }
        #else
        pushMaterialBackground(cornerRadius: cornerRadius)
        #endif
    }

    func pushMaterialBackground(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial.opacity(PushGlassStyle.materialPresenceOpacity))
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PushGlassStyle.warmTint.opacity(PushGlassStyle.tintOpacity))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    .white.opacity(PushGlassStyle.strokeOpacity),
                    lineWidth: PushGlassStyle.strokeWidth
                )
        }
        .shadow(
            color: PushGlassStyle.shadowColor.opacity(PushGlassStyle.shadowOpacity),
            radius: PushGlassStyle.shadowRadius,
            y: PushGlassStyle.shadowYOffset
        )
    }

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
