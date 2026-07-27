//
//  PushPuckGlass.swift
//  Push
//
//  DS-012 — puck glass for map annotations only (cooler white tint).
//

import SwiftUI

enum PushPuckGlassTokens {
    static let tintOpacity = 0.16
    static let strokeOpacity = 0.64
    static let strokeWidth: CGFloat = 0.9
}

/// DS-052 regional-cluster variant. Values stay restrained so population
/// changes remain scannable without competing with close-range friend pucks.
enum PushRegionalPuckTokens {
    static let baseWidth: CGFloat = 76
    static let coreHeight: CGFloat = 46
    static let overallScale: CGFloat = 1.14
    static let populationScaleSmall: CGFloat = 0.94
    static let populationScaleMedium: CGFloat = 1
    static let populationScaleLarge: CGFloat = 1.06

    static let avatarSize: CGFloat = 30
    static let avatarOverlap: CGFloat = 11
    static let avatarStrokeWidth: CGFloat = 1.5
    static let avatarStrokeOpacity = 0.92

    static let chipWidth: CGFloat = 42
    static let chipHeight: CGFloat = 21
    static let chipStrokeWidth: CGFloat = 0.8
    static let chipStrokeOpacity = 0.76
    static let chipFillOpacity = 0.94
    static let chipKerning: CGFloat = 0.4
    static let chipVerticalOffset: CGFloat = 23
    static let badgeShadowOpacity = 0.18
    static let badgeShadowRadius: CGFloat = 5
    static let badgeShadowYOffset: CGFloat = 2

    static let neutralRingOpacity = 0.74
    static let activeRingOpacity = 0.92
    static let currentUserRingOpacity = 0.92
    static let creamRingOpacity = 0.96
    static let selectedRingOpacity = 0.96
    static let contrastRingWidth: CGFloat = 3.8
    static let stateRingWidth: CGFloat = 2
    static let selectedRingWidth: CGFloat = 2.8
    static let selectedScale: CGFloat = 1.04

    static let haloLineWidth: CGFloat = 2
    static let haloOpacity = 0.48
    static let haloMinScale: CGFloat = 1.01
    static let haloMaxScale: CGFloat = 1.10
    static let haloLowOpacity = 0.12

    static let frameWidthPadding: CGFloat = 20
    static let frameHeight: CGFloat = 94
    static let minimumTextScale = PushOpacityTokens.minimumTextScale

    static let detailCornerRadius: CGFloat = 24
    static let detailAvatarStackSize: CGFloat = 54
    static let detailAvatarSize: CGFloat = 31
    static let detailHorizontalPadding: CGFloat = 16
    static let detailVerticalPadding: CGFloat = 14
    static let detailContentSpacing: CGFloat = 12
    static let detailTextSpacing: CGFloat = 3
}

extension View {
    /// Annotation-scoped glass. Do not use for buttons, cards, or general chrome.
    func pushPuckGlass(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(PushPuckGlassTokens.tintOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    .white.opacity(PushPuckGlassTokens.strokeOpacity),
                    lineWidth: PushPuckGlassTokens.strokeWidth
                )
        }
    }
}
