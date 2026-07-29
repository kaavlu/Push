//
//  CreatePostStyle.swift
//  Push
//
//  Layout tokens for Feed create-post hub + compose.
//  Hub chooser density lives in PushMomentChooserMetrics (DS-091).
//

import SwiftUI

enum CreatePostLayout {
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
    static let titleMaxLength = 80
    static let locationMaxLength = 80

    static let navTopPadding = StartPushLayout.navTopPadding
    /// Compose nav only — hub uses tighter header-to-action spacing below.
    static let navBottomPadding = StartPushLayout.navBottomPadding
    /// Hub: subtitle → segment — same as Friends header → Friends/Groups switch.
    static func hubHeaderToSegmentSpacing(_ layout: PushAdaptiveLayout) -> CGFloat {
        FriendsLayout.screenStackSpacing(layout)
    }
    static let contentTopSpacing = StartPushLayout.contentTopSpacing
    static let sectionLabelSpacing = StartPushLayout.sectionLabelSpacing

    // Hub vertical rhythm
    /// Segmented control → pinned Create from scratch.
    static let segmentToCreateSpacing: CGFloat = 8
    /// Create from scratch → scrolling chooser list.
    static let createToListSpacing: CGFloat = 8
    /// Between moment / past-Push rows.
    static let chooserListSpacing: CGFloat = 8

    // Media drag reorder feedback
    static let thumbDragScale: CGFloat = 1.08
    static let thumbDragShadowOpacity = 0.28
    static let thumbDragShadowRadius: CGFloat = 10
    static let thumbDragShadowY: CGFloat = 4
    static let coverBadgeFontSize: CGFloat = 9
    static let coverBadgeHorizontalPadding: CGFloat = 5
    static let coverBadgeVerticalPadding: CGFloat = 2
    static let coverBadgeInset: CGFloat = 4

    // Compose
    static let fieldHeight: CGFloat = 48
    static let fieldCornerRadius: CGFloat = 16
    static let fieldHorizontalPadding: CGFloat = 14
    static let fieldStackSpacing: CGFloat = 10
    static let composeMediaMinHeight: CGFloat = 180
    static let composeMediaStageHeight: CGFloat = 220
    static let composeMediaMaxFraction: CGFloat = 0.38
    static let peopleAvatarSize: CGFloat = 32
    static let peopleRowSpacing: CGFloat = 10
    static let successIconFrame = StartPushLayout.confirmIconFrame
    static let successIconSize = StartPushLayout.confirmIconSize
    static let successStackSpacing: CGFloat = 12
    static let successShadowOpacity = 0.22
    static let successShadowRadius: CGFloat = 20
    static let successShadowY: CGFloat = 8

    static let backIconSize = StartPushLayout.backIconSize
    static let backHorizontalPadding = StartPushLayout.backHorizontalPadding
    static let closeButtonSize = StartPushLayout.closeButtonSize
}

enum CreatePostColor {
    static let fieldFill = StartPushColor.textEditorFill
    static let cardStrokeOpacity = StartPushColor.textEditorStrokeOpacity
    static let mediaPlaceholderTop = PushColorPalette.Accent.walnut.opacity(0.18)
    static let mediaPlaceholderBottom = PushColorPalette.Accent.walnut.opacity(0.08)
}
