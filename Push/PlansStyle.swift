// Push/PlansStyle.swift
import SwiftUI

enum PlansLayout {
    static let horizontalPadding: CGFloat = 18
    static let headerToCalendarSpacing: CGFloat = 14
    static let headerSubtitleSpacing: CGFloat = 3
    static let bottomPadding: CGFloat = 110
    static let sectionSpacing: CGFloat = 10
    static let calendarToYourPushesSpacing: CGFloat = 18
    static let pushesModuleSpacing: CGFloat = 20
    static let startButtonTopSpacing: CGFloat = 18
    static let moduleTitleCardSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 26
    static let cardPadding: CGFloat = 15
    static let cardRowSpacing: CGFloat = 6
    static let pushCardHeight: CGFloat = 188
    static let cardDividerOpacity: Double = 0.28
    static let calendarCornerRadius: CGFloat = 26
    static let calendarPadding: CGFloat = 14
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
    static let reviewAllButtonTopPadding: CGFloat = 4
    static let startPlanButtonHeight: CGFloat = 50
    static let startPlanButtonCornerRadius: CGFloat = 25
    static let startPlanButtonBottomPadding: CGFloat = 28
    static let startPlanButtonHorizontalPadding: CGFloat = 46
    static let headerTopPadding: CGFloat = 12
    static let deckCardPadding: CGFloat = 12
    static let swipeThreshold: CGFloat = 100
    static let swipeUpThreshold: CGFloat = -80
    static let swipeRotationDivisor: Double = 20.0
    static let deckHintsBottomPadding: CGFloat = 12
    static let deckRemainingLabelBottomPadding: CGFloat = 24
}

enum PlansColor {
    static let metadata = Color(red: 0.43, green: 0.29, blue: 0.17)
    static let metadataSecondary = Color(red: 0.55, green: 0.43, blue: 0.31)
    static let metadataTertiary = Color(red: 0.68, green: 0.58, blue: 0.47)
    static let creamBase = Color(red: 1.00, green: 0.96, blue: 0.87)
    static let creamSoft = Color(red: 0.98, green: 0.91, blue: 0.78)
    static let cleanCardFill = creamBase.opacity(0.42)
    static let warmCardTint = PushColorPalette.Accent.sunbeam.opacity(0.10)
    static let glassStroke = creamBase.opacity(0.74)
    static let innerGlassStroke = Color.white.opacity(0.46)
    static let cardShadow = PushColorPalette.Accent.walnut.opacity(0.14)
    static let primaryGlow = PushColorPalette.Accent.sunbeam.opacity(0.32)
    static let pageTop = creamSoft.opacity(0.54)
    static let pageMiddle = creamBase.opacity(0.68)
    static let pageBottom = PushColorPalette.Accent.walnut.opacity(0.11)

    // Subtle light-brown card border — mirrors the Friends screen cards so the
    // calendar and push cards read consistently against the ivory page.
    static let walnutBorder = PushColorPalette.Accent.walnut.opacity(0.18)
    static let walnutBorderWidth: CGFloat = 0.8

    // Start Push CTA: a more pronounced walnut rim so the primary button reads
    // as intentionally brown-accented against the liquid-glass fill.
    static let startButtonBorder = PushColorPalette.Accent.walnut.opacity(0.32)
    static let startButtonBorderWidth: CGFloat = 1.0
}

/// Tokens for the premium liquid-glass treatment on the Review deck card.
/// Kept translucent so the warm modal gradient blurs through, rather than
/// reading as a flat beige panel.
enum ReviewGlassStyle {
    static let warmFill = PlansColor.creamBase.opacity(0.20)
    static let sunbeamTint = PushColorPalette.Accent.sunbeam.opacity(0.08)
    static let highlight = Color.white.opacity(0.34)
    static let walnutStroke = PushColorPalette.Accent.walnut.opacity(0.10)
    static let shadow = PushColorPalette.Accent.walnut.opacity(0.12)
    static let shadowRadius: CGFloat = 28
    static let shadowYOffset: CGFloat = 14
    static let whiteStrokeWidth: CGFloat = 1
    static let walnutStrokeWidth: CGFloat = 0.5

    /// Specular edge: bright at the top-left, fading toward the bottom so the
    /// rim catches light like real glass.
    static let edgeSheen = LinearGradient(
        colors: [Color.white.opacity(0.62), Color.white.opacity(0.18), Color.white.opacity(0.30)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    /// Reusable liquid-glass card: blurred material + translucent warm fill,
    /// a top-left sheen, layered white/walnut strokes, and a soft warm shadow.
    func reviewGlassCard(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(.ultraThinMaterial, in: shape)
            .background(shape.fill(ReviewGlassStyle.warmFill))
            .background(shape.fill(ReviewGlassStyle.sunbeamTint))
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [ReviewGlassStyle.highlight, .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
            }
            .overlay {
                shape.stroke(ReviewGlassStyle.walnutStroke, lineWidth: ReviewGlassStyle.walnutStrokeWidth)
            }
            .overlay {
                shape.inset(by: 1)
                    .stroke(ReviewGlassStyle.edgeSheen, lineWidth: ReviewGlassStyle.whiteStrokeWidth)
            }
            .overlay {
                shape.stroke(PlansColor.walnutBorder, lineWidth: PlansColor.walnutBorderWidth)
            }
            .shadow(
                color: ReviewGlassStyle.shadow,
                radius: ReviewGlassStyle.shadowRadius,
                y: ReviewGlassStyle.shadowYOffset
            )
    }

    func plansGlassCard(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PlansColor.cleanCardFill)
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PlansColor.warmCardTint)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(PlansColor.glassStroke, lineWidth: PushGlassStyle.strokeWidth)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(PlansColor.innerGlassStroke, lineWidth: PushGlassStyle.strokeWidth)
                .padding(1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(PlansColor.walnutBorder, lineWidth: PlansColor.walnutBorderWidth)
        }
        .shadow(color: PlansColor.cardShadow, radius: 20, y: 10)
    }
}

struct PlanStatusPill: View {
    let status: PlanStatus

    var body: some View {
        Text(status.pill)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, PlansLayout.statusPillHorizontalPadding)
            .padding(.vertical, PlansLayout.statusPillVerticalPadding)
            .background(Capsule().fill(backgroundColor))
    }

    private var foregroundColor: Color {
        switch status {
        case .pending:   return PushColorPalette.Accent.walnut
        case .joined:    return PushColorPalette.Accent.sageGreen
        case .open:      return PushControlColors.textSecondary
        case .waiting:   return PushControlColors.textTertiary
        case .locked:    return PushColorPalette.Accent.walnut
        case .happening: return PushColorPalette.Accent.walnut
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:   return PushColorPalette.Accent.sunbeam.opacity(0.7)
        case .joined:    return PushColorPalette.Accent.mintFoam
        case .open:      return PushColorPalette.Accent.walnut.opacity(0.10)
        case .waiting:   return PushColorPalette.Accent.walnut.opacity(0.06)
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
    static let joinedLabelSpacing: CGFloat = 6
    static let footerTopPadding: CGFloat = 4
    static let overflowFontSize: CGFloat = 11
    static let headerSpacerMinLength: CGFloat = 8
    static let timeChipStrokeWidth: CGFloat = 1.0
    static let avatarRingOpacity: Double = 0.86
}
