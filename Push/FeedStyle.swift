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

    /// Space between pinned filter chips and scroll content.
    static let chipToContentSpacing: CGFloat = 14
    static let placeholderCardMinHeight: CGFloat = 120
    static let placeholderCardPadding: CGFloat = 20
    static let placeholderCardSpacing: CGFloat = 8

    /// Consistent vertical gap between media cards (next card peeks slightly).
    static let mediaStackSpacing: CGFloat = 24
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
    /// Distance from the top edge — sits a bit below the card rim.
    static let progressTopInset: CGFloat = 18
    /// Extra side margin so segments clear the rounded corners.
    static let progressHorizontalInset: CGFloat = 22

    /// Seconds each multi-item page holds before auto-advancing.
    static let autoAdvanceDuration: TimeInterval = 3.5
    static let autoAdvanceAnimationDuration: TimeInterval = 0.32
    /// Progress-bar tick interval while the active segment fills (~60 fps).
    static let progressTickNanoseconds: UInt64 = 16_666_666
    /// Fraction of card height that must be on-screen for autoplay (avoids the peeking next card).
    static let autoplayVisibilityThreshold: CGFloat = 0.55

    static let placeholderIconSize: CGFloat = 32
    static let placeholderStackSpacing: CGFloat = 10

    /// Soft walnut stroke so the media card sits on ivory without a heavy frame.
    static let mediaStrokeOpacity = 0.12
    static let mediaStrokeWidth: CGFloat = 0.8

    /// Soft top scrim height so progress stays legible on light or dark media.
    static let metadataScrimHeight: CGFloat = 118

    /// Bottom interaction inset from media edges (matches top chrome side inset).
    static let bottomHorizontalInset: CGFloat = progressHorizontalInset
    static let bottomEdgeInset: CGFloat = 16
    /// Soft bottom scrim behind participants + playback (Add yours is under media).
    static let bottomScrimHeight: CGFloat = 112

    /// Shared outer radius for media + cream content band (one unified card).
    static var cardCornerRadius: CGFloat { cornerRadius }
}

/// Compact cream band under feed media (title, meta, trailing + / …).
enum FeedMediaContentSectionStyle {
    /// Outer padding — compact so the stack stays dense on the Feed.
    static let horizontalPadding: CGFloat = 14
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 12
    /// Title → location · date line.
    static let titleToMetaSpacing: CGFloat = 4
    /// Gap between title/meta column and trailing action cluster.
    static let titleToOverflowSpacing: CGFloat = 10
    /// Gap between sunbeam + and overflow … (same-size circle pair).
    static let actionSpacing: CGFloat = 8

    static let titleFont = Font.headline.weight(.semibold)
    static let titleColor = PushControlColors.textEspresso
    static let metaFont = Font.caption.weight(.medium)
    static let metaColor = PushControlColors.textSecondary
    static let titleLineLimit = 2
    static let metaLineLimit = 1
}

/// Bottom media interaction chrome (avatars + names on media).
enum FeedMediaBottomStyle {
    static let avatarSize: CGFloat = 34
    static let avatarOverlap: CGFloat = -11
    static let avatarStrokeWidth: CGFloat = 1.5
    static let avatarStrokeOpacity = 0.92
    static let avatarToTextSpacing: CGFloat = 10
    static let textStackSpacing: CGFloat = 2

    static let namesFont = Font.subheadline.weight(.semibold)
    static let contributorFont = Font.caption.weight(.medium)
    static let textColor = Color.white
    static let contributorOpacity = 0.88
    static let textShadowRadius: CGFloat = 2
    static let textShadowY: CGFloat = 1

    static let overflowFontSize: CGFloat = 12

    static let scrimBottomOpacity = 0.58
    static let scrimMidOpacity = 0.28
    static let scrimMidStop = 0.45
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

/// Soft top scrim over media (progress readability).
enum FeedMediaMetadataStyle {
    static let scrimTopOpacity = 0.40
    static let scrimMidOpacity = 0.16
    static let scrimMidStop = 0.55
}
