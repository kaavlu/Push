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
    static let mediaStackSpacing: CGFloat = 24

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
    /// Distance from the top edge — sits a bit below the card rim.
    static let progressTopInset: CGFloat = 18
    /// Extra side margin so segments clear the rounded corners.
    static let progressHorizontalInset: CGFloat = 22

    /// Seconds each multi-item page holds before auto-advancing.
    static let autoAdvanceDuration: TimeInterval = 3.5
    static let autoAdvanceAnimationDuration: TimeInterval = 0.32

    static let placeholderIconSize: CGFloat = 32
    static let placeholderStackSpacing: CGFloat = 10

    /// Soft walnut stroke so the media card sits on ivory without a heavy frame.
    static let mediaStrokeOpacity = 0.12
    static let mediaStrokeWidth: CGFloat = 0.8

    /// Gap between progress row and metadata (location / time / overflow).
    static let progressToMetadataSpacing: CGFloat = 10
    /// Side inset for the metadata row (matches progress side margin).
    static let metadataHorizontalInset: CGFloat = progressHorizontalInset
    /// Top inset when progress is hidden (single-item carousels).
    static let metadataTopInsetWithoutProgress: CGFloat = progressTopInset
    /// Space between location and date/time lines.
    static let metadataTextStackSpacing: CGFloat = 3
    /// Soft top scrim height so white type stays legible on light or dark media.
    static let metadataScrimHeight: CGFloat = 118

    /// Bottom interaction inset from media edges (matches top chrome side inset).
    static let bottomHorizontalInset: CGFloat = progressHorizontalInset
    static let bottomEdgeInset: CGFloat = 16
    /// Gap between participant row and Add yours.
    static let bottomRowToCTASpacing: CGFloat = 12
    /// Soft bottom scrim height behind the interaction section.
    static let bottomScrimHeight: CGFloat = 168
}

/// Bottom media interaction chrome (avatars, names, play, Add yours).
enum FeedMediaBottomStyle {
    static let avatarSize: CGFloat = 34
    static let avatarOverlap: CGFloat = -11
    static let avatarStrokeWidth: CGFloat = 1.5
    static let avatarStrokeOpacity = 0.92
    static let avatarToTextSpacing: CGFloat = 10
    static let textStackSpacing: CGFloat = 2
    static let rowToPlaySpacing: CGFloat = 10

    static let namesFont = Font.subheadline.weight(.semibold)
    static let contributorFont = Font.caption.weight(.medium)
    static let textColor = Color.white
    static let contributorOpacity = 0.88
    static let textShadowRadius: CGFloat = 2
    static let textShadowY: CGFloat = 1

    static let overflowFontSize: CGFloat = 12
    static let playButtonSize: CGFloat = 44
    static let playIconSize: CGFloat = 16
    static var playCornerRadius: CGFloat { playButtonSize / 2 }

    static let addYoursHeight: CGFloat = 52
    static let addYoursIconSize: CGFloat = 15
    static let addYoursLabelSpacing: CGFloat = 8
    static let addYoursFont = Font.headline.weight(.bold)

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

/// Top chrome over media — compact location pill + overflow (Feed media only).
enum FeedMediaMetadataStyle {
    /// Compact single-line location label on liquid glass.
    static let locationFont = Font.subheadline.weight(.semibold)
    /// Walnut on liquid glass — same as map filter pill / top controls.
    static let textColor = PushControlColors.activeForeground
    static let scrimTopOpacity = 0.40
    static let scrimMidOpacity = 0.16
    static let scrimMidStop = 0.55

    /// Same diameter/radius family as the overflow control so the pill and `…`
    /// circle share visual curvature (half of 44pt control = capsule ends).
    static let overflowButtonSize: CGFloat = 44
    static let overflowIconSize: CGFloat = 17
    static let overflowIconWeight: Font.Weight = .semibold
    static var overflowCornerRadius: CGFloat { overflowButtonSize / 2 }

    /// Single-row pill height matches the overflow circle; radius matches ends.
    static let chipHeight: CGFloat = overflowButtonSize
    static let chipCornerRadius: CGFloat = overflowCornerRadius
    static let chipHorizontalPadding: CGFloat = 16
}
