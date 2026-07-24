// Push/PlansStyle.swift
import SwiftUI

enum PlansLayout {
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.pageHorizontalPadding }
    static func headerToCalendarSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 10, standard: 12, large: 14) }
    static let headerSubtitleSpacing: CGFloat = 3
    static let bottomPadding: CGFloat = 110
    static func sectionSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 8, standard: 9, large: 10) }
    static func calendarToYourPushesSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 12, standard: 15, large: 18) }
    static func pushesModuleSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 14, standard: 17, large: 20) }
    static let startButtonTopSpacing: CGFloat = 18
    static let moduleTitleCardSpacing: CGFloat = 12
    static func cardCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat { layout.cardCornerRadius }
    static func cardPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.denseCardPadding }
    static func cardRowSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 5, standard: 6, large: 6) }
    static func pushCardMinHeight(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 138, standard: 145, large: 152) }
    static let cardDividerOpacity: Double = 0.28
    static func calendarCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat { layout.cardCornerRadius }
    static func calendarPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 11, standard: 12, large: 14) }
    static let calendarCellSize: CGFloat = 28
    static let calendarCellSpacing: CGFloat = 4
    static let calendarHeaderSpacing: CGFloat = 8
    static let calendarFooterSpacing: CGFloat = 12
    static let dotEmptySize: CGFloat = 4
    static let dotSmallSize: CGFloat = 6
    static let dotMediumSize: CGFloat = 9
    static let dotLargeSize: CGFloat = 12
    static let dotRingStrokeWidth: CGFloat = 1.5
    static let dotRingPadding: CGFloat = 6
    static let statusPillHorizontalPadding: CGFloat = 10
    static let statusPillVerticalPadding: CGFloat = 5
    static let currentPushesSpacing: CGFloat = 8
    static let listHeaderToCardsSpacing: CGFloat = 22
    static let reviewAllButtonTopPadding: CGFloat = 4
    static let startPlanButtonHeight: CGFloat = 50
    static let startPlanButtonCornerRadius: CGFloat = 25
    static func startPlanButtonBottomPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 18, standard: 23, large: 28) }
    static func startPlanButtonHorizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 34, standard: 40, large: 46) }
    static let headerTopPadding: CGFloat = 12
    static let deckCardPadding: CGFloat = 12
    static let swipeThreshold: CGFloat = 100
    static let swipeUpThreshold: CGFloat = -80
    static let swipeRotationDivisor: Double = 20.0
    static let deckHintsBottomPadding: CGFloat = 12
    static let deckRemainingLabelBottomPadding: CGFloat = 24
}

enum PlansColor {
    /// Prefer `PushCreamTokens` / `PushGlassCreamTokens` for new code.
    static let metadata = PushCreamTokens.metadata
    static let metadataSecondary = PushCreamTokens.metadataSecondary
    static let metadataTertiary = PushCreamTokens.metadataTertiary
    static let creamBase = PushGlassCreamTokens.creamBase
    static let creamSoft = PushGlassCreamTokens.creamSoft
    static let cleanCardFill = PushGlassCreamTokens.cleanCardFill
    static let warmCardTint = PushGlassCreamTokens.warmCardTint
    static let glassStroke = PushGlassCreamTokens.glassStroke
    static let innerGlassStroke = PushGlassCreamTokens.innerGlassStroke
    static let cardShadow = PushGlassCreamTokens.cardShadow
    static let primaryGlow = PushColorPalette.Accent.sunbeam.opacity(0.32)
    static let pageTop = creamSoft.opacity(0.54)
    static let pageMiddle = creamBase.opacity(0.68)
    static let pageBottom = PushColorPalette.Accent.walnut.opacity(0.11)

    // Subtle light-brown card border — mirrors the Friends screen cards so the
    // calendar and push cards read consistently against the ivory page.
    static let walnutBorder = PushGlassCreamTokens.walnutBorder
    static let walnutBorderWidth = PushGlassCreamTokens.walnutBorderWidth

    // Start Push CTA: a more pronounced walnut rim so the primary button reads
    // as intentionally brown-accented against the liquid-glass fill.
    static let startButtonBorder = PushColorPalette.Accent.walnut.opacity(0.32)
    static let startButtonBorderWidth: CGFloat = 1.0

    // "Maybe" status pill (responded maybe) — matches the Your Push card's time chip.
    static let maybeBackground = PushColorPalette.Accent.sunbeam
    static let maybeForeground = PushControlColors.textEspresso

    // "Pass" status pill (responded no) — light red.
    static let passBackground = Color(red: 0.96, green: 0.80, blue: 0.78)
    static let passForeground = Color(red: 0.65, green: 0.20, blue: 0.16)
}

/// Prefer `PushGlassCreamTokens` for new code; kept for Review card call sites.
enum ReviewGlassStyle {
    static let warmFill = PushGlassCreamTokens.reviewWarmFill
    static let sunbeamTint = PushGlassCreamTokens.reviewSunbeamTint
    static let highlight = PushGlassCreamTokens.reviewHighlight
    static let walnutStroke = PushGlassCreamTokens.reviewWalnutStroke
    static let shadow = PushGlassCreamTokens.reviewShadow
    static let shadowRadius = PushGlassCreamTokens.reviewShadowRadius
    static let shadowYOffset = PushGlassCreamTokens.reviewShadowY
    static let whiteStrokeWidth = PushGlassCreamTokens.reviewWhiteStrokeWidth
    static let walnutStrokeWidth = PushGlassCreamTokens.reviewWalnutStrokeWidth
    static let edgeSheen = PushGlassCreamTokens.reviewEdgeSheen
}

extension View {
    /// Prefer `pushReviewDeckGlass` (DS-013).
    func reviewGlassCard(cornerRadius: CGFloat) -> some View {
        pushReviewDeckGlass(cornerRadius: cornerRadius)
    }

    /// Prefer `pushPlansCardGlass` (DS-013).
    func plansGlassCard(cornerRadius: CGFloat) -> some View {
        pushPlansCardGlass(cornerRadius: cornerRadius)
    }
}

struct PlanStatusPill: View {
    let status: PlanStatus

    var body: some View {
        Text(status.pill)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, PlansLayout.statusPillHorizontalPadding)
            .padding(.vertical, PlansLayout.statusPillVerticalPadding)
            .background(Capsule().fill(backgroundColor))
    }

    private var foregroundColor: Color {
        switch status {
        case .pending:   return PushColorPalette.Accent.walnut
        case .joined:    return PushColorPalette.Accent.sageGreen
        case .open:      return PlansColor.maybeForeground
        case .waiting:   return PlansColor.passForeground
        case .locked:    return PushColorPalette.Accent.walnut
        case .happening: return PushColorPalette.Accent.walnut
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:   return PushColorPalette.Accent.sunbeam.opacity(0.7)
        case .joined:    return PushColorPalette.Accent.mintFoam
        case .open:      return PlansColor.maybeBackground
        case .waiting:   return PlansColor.passBackground
        case .locked:    return PushColorPalette.Accent.sunbeam
        case .happening: return PushColorPalette.Accent.sunbeam
        }
    }
}

enum YourPushCardLayout {
    static let avatarSize: CGFloat = 28
    static let avatarSpacing: CGFloat = 6
    static let avatarStrokeWidth: CGFloat = 0.8
    static let overflowAvatarSize: CGFloat = 28
    static let maxVisibleAvatars: Int = 4
    static let timeChipHorizontalPadding: CGFloat = 8
    static let timeChipVerticalPadding: CGFloat = 4
    static let timeChipStrokeOpacity: Double = 0.40
    static let footerTopPadding: CGFloat = 4
    static let overflowFontSize: CGFloat = 11
    static let headerSpacerMinLength: CGFloat = 8
    static let timeChipStrokeWidth: CGFloat = 1.0
    static let avatarRingOpacity: Double = 0.86
}
