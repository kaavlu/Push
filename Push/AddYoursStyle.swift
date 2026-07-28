//
//  AddYoursStyle.swift
//  Push
//
//  Layout tokens for the Add Yours contribution page.
//

import SwiftUI

enum AddYoursLayout {
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.modalHorizontalPadding
    }

    static func bottomPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.value(compact: 20, standard: 26, large: 32)
    }

    static func sectionSpacing(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.value(compact: 16, standard: 18, large: 20)
    }

    static let maxSelectionCount = 8

    static let navTopPadding: CGFloat = 16
    static let navBottomPadding: CGFloat = 10
    static let headerSpacing: CGFloat = 6
    static let contentTopSpacing: CGFloat = 8

    /// Match Feed media frame so contribution preview feels on-brand.
    static let heroAspectRatio = FeedMediaLayout.aspectRatio
    static let heroCornerRadius = FeedMediaLayout.cornerRadius
    static let heroStrokeOpacity = FeedMediaLayout.mediaStrokeOpacity
    static let heroStrokeWidth = FeedMediaLayout.mediaStrokeWidth

    static let emptyIconSize: CGFloat = 28
    static let emptyStackSpacing: CGFloat = 10
    static let emptyDashPhase: CGFloat = 8
    static let emptyDashLength: CGFloat = 7
    static let emptyDashStrokeWidth: CGFloat = 1.5
    static let emptyFillOpacity = 0.22
    static let emptyStrokeOpacity = 0.28

    static let thumbSize: CGFloat = 64
    static let thumbSpacing: CGFloat = 10
    static let thumbCornerRadius: CGFloat = 14
    static let thumbSelectedStrokeWidth: CGFloat = 2.5
    static let thumbIdleStrokeWidth: CGFloat = 1
    static let thumbStripTopPadding: CGFloat = 4
    static let thumbStripVerticalPadding: CGFloat = 2
    static let addThumbIconSize: CGFloat = 18

    static let videoBadgeSize: CGFloat = 34
    static let videoBadgeIconSize: CGFloat = 14
    static let videoBadgeInset: CGFloat = 12
    static let videoBadgeFillOpacity = 0.42

    static let removeControlSize: CGFloat = 30
    static let removeIconSize: CGFloat = 11
    static let removeInset: CGFloat = 10
    static let removeFillOpacity = 0.92
    static let removeStrokeOpacity = 0.18
    static let removeStrokeWidth: CGFloat = 1

    static let thumbPlayIconSize: CGFloat = 11
    static let thumbPlayShadowOpacity = 0.35
    static let thumbPlayShadowRadius: CGFloat = 2
    static let thumbPlayShadowY: CGFloat = 1
    static let addThumbDash: [CGFloat] = [5, 4]
    static let addThumbStrokeWidth: CGFloat = 1.2

    static let videoPlaceholderIconSize: CGFloat = 28
    static let videoPlaceholderIconOpacity = 0.88

    static let successIconFrame: CGFloat = 80
    static let successIconSize: CGFloat = 34
    static let successStackSpacing: CGFloat = 12
    static let successShadowOpacity = 0.22
    static let successShadowRadius: CGFloat = 20
    static let successShadowY: CGFloat = 8
}

enum AddYoursColor {
    static let emptyFill = Color.white.opacity(AddYoursLayout.emptyFillOpacity)
    static let thumbIdleStrokeOpacity = 0.16
    static let videoPlaceholderTop = PushColorPalette.Accent.walnut.opacity(0.55)
    static let videoPlaceholderBottom = PushColorPalette.Accent.walnut.opacity(0.28)
}
