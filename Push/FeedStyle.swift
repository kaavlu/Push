//
//  FeedStyle.swift
//  Push
//
//  Layout tokens for the Feed shell + media carousel foundation.
//  Colors defer to shared palette / cream surfaces.
//

import SwiftUI

enum FeedLayout {
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.pageHorizontalPadding
    }

    static let topPadding: CGFloat = FriendsLayout.topPadding

    static func screenStackSpacing(_ layout: PushAdaptiveLayout) -> CGFloat {
        FriendsLayout.screenStackSpacing(layout)
    }

    /// Scroll clearance above ContentView's floating bottom nav.
    static func contentBottomClearance(_ layout: PushAdaptiveLayout) -> CGFloat {
        FriendsLayout.contentBottomClearance(layout)
    }

    static let headerActionSpacing: CGFloat = 10
    /// Space between pinned filter chips and scroll content.
    static let chipToContentSpacing: CGFloat = 14
    static let placeholderCardMinHeight: CGFloat = 120
    static let placeholderCardPadding: CGFloat = 20
    static let placeholderCardSpacing: CGFloat = 8

    /// Consistent vertical gap between media cards (next card peeks slightly).
    static let mediaStackSpacing: CGFloat = 14

    /// Unread-dot metrics — match map top-control indicator scale.
    static let alertIndicatorSize: CGFloat = 9
    static let alertIndicatorStrokeWidth: CGFloat = 1.5
    static let alertIndicatorInset: CGFloat = 1
}

/// Compact cinematic media frame for Feed Push cards.
enum FeedMediaLayout {
    /// Width ÷ height — compact portrait (~0.86) so the first card mostly fits
    /// on screen and the next card peeks below.
    static let aspectRatio: CGFloat = 0.86

    /// Single rounded rectangle — production media corner (28–32pt band).
    static let cornerRadius: CGFloat = 30

    static let progressHeight: CGFloat = 2.5
    static let progressSpacing: CGFloat = 3
    /// Inset from media edges for the top progress row.
    static let progressEdgeInset: CGFloat = 12

    static let placeholderIconSize: CGFloat = 32
    static let placeholderStackSpacing: CGFloat = 10

    /// Soft walnut stroke so the media card sits on ivory without a heavy frame.
    static let mediaStrokeOpacity = 0.12
    static let mediaStrokeWidth: CGFloat = 0.8
}

enum FeedMediaProgressStyle {
    static let currentOpacity = 1.0
    /// Visited segments stay readable but quieter than current.
    static let completedOpacity = 0.55
    static let remainingOpacity = 0.28
    static let segmentColor = Color.white
}

enum FeedMediaPlaceholderStyle {
    /// Deep warm wash under missing/loading media (not pure black).
    static let background = Color(red: 0.22, green: 0.14, blue: 0.08)
    static let iconColor = Color.white.opacity(0.72)
    static let captionColor = Color.white.opacity(0.55)
    static let spinnerTint = PushColorPalette.Accent.sunbeam
}
