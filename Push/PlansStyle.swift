// Push/PlansStyle.swift
import SwiftUI

enum PlansLayout {
    static let horizontalPadding: CGFloat = 18
    static let topPadding: CGFloat = 18
    static let bottomPadding: CGFloat = 110
    static let sectionSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 26
    static let cardPadding: CGFloat = 18
    static let cardRowSpacing: CGFloat = 8
    static let calendarCornerRadius: CGFloat = 26
    static let calendarPadding: CGFloat = 18
    static let calendarCellSize: CGFloat = 30
    static let calendarCellSpacing: CGFloat = 4
    static let calendarHeaderSpacing: CGFloat = 12
    static let calendarFooterSpacing: CGFloat = 12
    static let dotEmptySize: CGFloat = 4
    static let dotSmallSize: CGFloat = 6
    static let dotMediumSize: CGFloat = 9
    static let dotLargeSize: CGFloat = 12
    static let dotRingStrokeWidth: CGFloat = 1.5
    static let dotRingPadding: CGFloat = 6
    static let statusPillHorizontalPadding: CGFloat = 10
    static let statusPillVerticalPadding: CGFloat = 5
    static let currentPushesSpacing: CGFloat = 12
    static let reviewAllButtonTopPadding: CGFloat = 4
    static let startPlanButtonHeight: CGFloat = 46
    static let startPlanButtonCornerRadius: CGFloat = 23
    static let startPlanButtonBottomPadding: CGFloat = 32
    static let startPlanButtonHorizontalPadding: CGFloat = 48
    static let headerTopPadding: CGFloat = 18
    static let deckCardPadding: CGFloat = 24
    static let swipeThreshold: CGFloat = 100
    static let swipeUpThreshold: CGFloat = -80
    static let swipeRotationDivisor: Double = 20.0
    static let deckHintsBottomPadding: CGFloat = 24
    static let deckRemainingLabelBottomPadding: CGFloat = 48
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
}
