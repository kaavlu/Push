//
//  PushCardGlass.swift
//  Push
//
//  DS-013 — Plans card glass (cream pages) + Review deck glass (gradient decks).
//

import SwiftUI

/// Semantic cream roles used by Plans/Review glass without flattening appearance.
enum PushGlassCreamTokens {
    static let creamBase = Color(red: 1.00, green: 0.96, blue: 0.87)
    static let creamSoft = Color(red: 0.98, green: 0.91, blue: 0.78)
    static let cleanCardFillOpacity = 0.42
    static let warmCardTintOpacity = 0.10
    static let glassStrokeOpacity = 0.74
    static let innerGlassStrokeOpacity = 0.46
    static let cardShadowOpacity = 0.14
    static let walnutBorderOpacity = 0.18
    static let walnutBorderWidth: CGFloat = 0.8
    static let plansCardShadowRadius: CGFloat = 20
    static let plansCardShadowY: CGFloat = 10

    static let cleanCardFill = creamBase.opacity(cleanCardFillOpacity)
    static let warmCardTint = PushColorPalette.Accent.sunbeam.opacity(warmCardTintOpacity)
    static let glassStroke = creamBase.opacity(glassStrokeOpacity)
    static let innerGlassStroke = Color.white.opacity(innerGlassStrokeOpacity)
    static let cardShadow = PushColorPalette.Accent.walnut.opacity(cardShadowOpacity)
    static let walnutBorder = PushColorPalette.Accent.walnut.opacity(walnutBorderOpacity)

    // Review deck (more translucent over modal gradient)
    static let reviewWarmFillOpacity = 0.20
    static let reviewSunbeamTintOpacity = 0.08
    static let reviewHighlightOpacity = 0.34
    static let reviewWalnutStrokeOpacity = 0.10
    static let reviewShadowOpacity = 0.12
    static let reviewShadowRadius: CGFloat = 28
    static let reviewShadowY: CGFloat = 14
    static let reviewWhiteStrokeWidth: CGFloat = 1
    static let reviewWalnutStrokeWidth: CGFloat = 0.5

    static let reviewWarmFill = creamBase.opacity(reviewWarmFillOpacity)
    static let reviewSunbeamTint = PushColorPalette.Accent.sunbeam.opacity(reviewSunbeamTintOpacity)
    static let reviewHighlight = Color.white.opacity(reviewHighlightOpacity)
    static let reviewWalnutStroke = PushColorPalette.Accent.walnut.opacity(reviewWalnutStrokeOpacity)
    static let reviewShadow = PushColorPalette.Accent.walnut.opacity(reviewShadowOpacity)

    static let reviewEdgeSheen = LinearGradient(
        colors: [Color.white.opacity(0.62), Color.white.opacity(0.18), Color.white.opacity(0.30)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    /// Plans card glass — push cards & calendar shell on cream pages.
    func pushPlansCardGlass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(.ultraThinMaterial, in: shape)
            .background(shape.fill(PushGlassCreamTokens.cleanCardFill))
            .background(shape.fill(PushGlassCreamTokens.warmCardTint))
            .overlay {
                shape.stroke(
                    PushGlassCreamTokens.glassStroke,
                    lineWidth: PushControlGlassTokens.strokeWidth
                )
            }
            .overlay {
                shape.stroke(
                    PushGlassCreamTokens.innerGlassStroke,
                    lineWidth: PushControlGlassTokens.strokeWidth
                )
                .padding(1)
            }
            .overlay {
                shape.stroke(
                    PushGlassCreamTokens.walnutBorder,
                    lineWidth: PushGlassCreamTokens.walnutBorderWidth
                )
            }
            .shadow(
                color: PushGlassCreamTokens.cardShadow,
                radius: PushGlassCreamTokens.plansCardShadowRadius,
                y: PushGlassCreamTokens.plansCardShadowY
            )
    }

    /// Review deck glass — premium swipe cards over modal gradient only.
    func pushReviewDeckGlass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(.ultraThinMaterial, in: shape)
            .background(shape.fill(PushGlassCreamTokens.reviewWarmFill))
            .background(shape.fill(PushGlassCreamTokens.reviewSunbeamTint))
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [PushGlassCreamTokens.reviewHighlight, .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
            }
            .overlay {
                shape.stroke(
                    PushGlassCreamTokens.reviewWalnutStroke,
                    lineWidth: PushGlassCreamTokens.reviewWalnutStrokeWidth
                )
            }
            .overlay {
                shape.inset(by: 1)
                    .stroke(
                        PushGlassCreamTokens.reviewEdgeSheen,
                        lineWidth: PushGlassCreamTokens.reviewWhiteStrokeWidth
                    )
            }
            .overlay {
                shape.stroke(
                    PushGlassCreamTokens.walnutBorder,
                    lineWidth: PushGlassCreamTokens.walnutBorderWidth
                )
            }
            .shadow(
                color: PushGlassCreamTokens.reviewShadow,
                radius: PushGlassCreamTokens.reviewShadowRadius,
                y: PushGlassCreamTokens.reviewShadowY
            )
    }
}
