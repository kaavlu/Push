//
//  AddYoursStyle.swift
//  Push
//
//  Layout tokens for the Add Yours contribution page.
//  Aligns with Start Push card chrome + modal spacing.
//

import SwiftUI

enum AddYoursLayout {
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        StartPushLayout.horizontalPadding(layout)
    }

    static func bottomPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        StartPushLayout.bottomPadding(layout)
    }

    static func sectionSpacing(_ layout: PushAdaptiveLayout) -> CGFloat {
        StartPushLayout.sectionSpacing(layout)
    }

    static func cardCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat {
        StartPushLayout.cardCornerRadius(layout)
    }

    static func cardPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        StartPushLayout.cardPadding(layout)
    }

    static let maxSelectionCount = 8

    static let navTopPadding = StartPushLayout.navTopPadding
    static let navBottomPadding = StartPushLayout.navBottomPadding
    static let contentTopSpacing = StartPushLayout.contentTopSpacing
    static let headerToStageSpacing: CGFloat = 14
    static let stageToStripSpacing: CGFloat = 14
    static let stripToButtonSpacing: CGFloat = 16

    /// Portrait-ish preview ratio (width ÷ height), fitted into available space.
    static let heroAspectRatio: CGFloat = 0.86
    static let heroStrokeWidth: CGFloat = 1
    static let heroStrokeOpacity = StartPushColor.textEditorStrokeOpacity
    static let heroFillOpacity = StartPushColor.textEditorFill

    /// Empty pick surface is a compact card, not a full-bleed media frame.
    static let emptyMinHeight: CGFloat = 196
    static let emptyMaxHeight: CGFloat = 240
    static let emptyIconCircle: CGFloat = 56
    static let emptyIconSize: CGFloat = 22
    static let emptyStackSpacing: CGFloat = 12
    static let emptyTextSpacing: CGFloat = 4

    static let thumbSize: CGFloat = 60
    static let thumbSpacing: CGFloat = 10
    static let thumbCornerRadius: CGFloat = 14
    static let thumbSelectedStrokeWidth: CGFloat = 2.5
    static let thumbIdleStrokeWidth: CGFloat = 1
    static let thumbStripVerticalPadding: CGFloat = 2
    static let addThumbIconSize: CGFloat = 16

    static let videoBadgeSize: CGFloat = 32
    static let videoBadgeIconSize: CGFloat = 13
    static let videoBadgeInset: CGFloat = 12
    static let videoBadgeFillOpacity = 0.42

    static let removeControlSize: CGFloat = 32
    static let removeIconSize: CGFloat = 11
    static let removeInset: CGFloat = 10

    static let thumbPlayIconSize: CGFloat = 11
    static let thumbPlayShadowOpacity = 0.35
    static let thumbPlayShadowRadius: CGFloat = 2
    static let thumbPlayShadowY: CGFloat = 1

    static let videoPlaceholderIconSize: CGFloat = 26
    static let videoPlaceholderIconOpacity = 0.88

    static let successIconFrame = StartPushLayout.confirmIconFrame
    static let successIconSize = StartPushLayout.confirmIconSize
    static let successStackSpacing: CGFloat = 12
    static let successShadowOpacity = 0.22
    static let successShadowRadius: CGFloat = 20
    static let successShadowY: CGFloat = 8

    static func fittedHeroSize(in bounds: CGSize) -> CGSize {
        guard bounds.width > 0, bounds.height > 0 else {
            return .zero
        }
        var width = bounds.width
        var height = width / heroAspectRatio
        if height > bounds.height {
            height = bounds.height
            width = height * heroAspectRatio
        }
        return CGSize(width: width, height: height)
    }
}

enum AddYoursColor {
    static let cardFill = Color.white.opacity(AddYoursLayout.heroFillOpacity)
    static let cardStrokeOpacity = AddYoursLayout.heroStrokeOpacity
    static let thumbIdleStrokeOpacity = 0.18
    static let videoPlaceholderTop = PushColorPalette.Accent.walnut.opacity(0.55)
    static let videoPlaceholderBottom = PushColorPalette.Accent.walnut.opacity(0.28)
}
