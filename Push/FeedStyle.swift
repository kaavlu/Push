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
    static let chipToContentSpacing: CGFloat = 16
    static let placeholderCardMinHeight: CGFloat = 120
    static let placeholderCardPadding: CGFloat = 20
    static let placeholderCardSpacing: CGFloat = 8

    /// Vertical gap between stacked media carousels so the next card can peek.
    static func mediaStackSpacing(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.sectionSpacing
    }

    /// Unread-dot metrics — match map top-control indicator scale.
    static let alertIndicatorSize: CGFloat = 9
    static let alertIndicatorStrokeWidth: CGFloat = 1.5
    static let alertIndicatorInset: CGFloat = 1
}

/// Fixed geometry for the immersive Push media frame (Issue #9 prompt 1).
enum FeedMediaLayout {
    /// Width ÷ height — portrait 3:4 stays stable across differently sized media.
    static let aspectRatio: CGFloat = 3.0 / 4.0

    static func cornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat {
        PushRadiusTokens.card(layout)
    }

    static let progressHeight: CGFloat = 2.5
    static let progressSpacing: CGFloat = 4
    static let progressTopInset: CGFloat = 10
    static let progressHorizontalInset: CGFloat = 12

    static let placeholderIconSize: CGFloat = 36
    static let placeholderStackSpacing: CGFloat = 10

    /// Soft walnut stroke so the media card sits on ivory without a heavy frame.
    static let mediaStrokeOpacity = 0.14
    static let mediaStrokeWidth: CGFloat = 0.8
}

enum FeedMediaProgressStyle {
    static let currentOpacity = 1.0
    static let completedOpacity = 0.72
    static let remainingOpacity = 0.32
    static let segmentColor = Color.white
}

enum FeedMediaPlaceholderStyle {
    /// Deep warm wash under missing/loading media (not pure black).
    static let background = Color(red: 0.22, green: 0.14, blue: 0.08)
    static let iconColor = Color.white.opacity(0.72)
    static let captionColor = Color.white.opacity(0.55)
    static let spinnerTint = PushColorPalette.Accent.sunbeam
}

