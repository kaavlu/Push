//
//  FeedStyle.swift
//  Push
//
//  Layout tokens for the Feed shell. Colors defer to shared palette / cream surfaces.
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

    /// Unread-dot metrics — match map top-control indicator scale.
    static let alertIndicatorSize: CGFloat = 9
    static let alertIndicatorStrokeWidth: CGFloat = 1.5
    static let alertIndicatorInset: CGFloat = 1
}
