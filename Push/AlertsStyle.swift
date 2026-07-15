import SwiftUI

/// Alert-only geometry and motion. Spacing, card chrome, and horizontal margins
/// reuse `FriendsLayout` / `FriendsColor` so the page matches Friends.
enum AlertsLayout {
    /// Extra gap under the page subtitle before the section header / empty state.
    static let contentTopSpacing: CGFloat = 6
    static let actionSpacing: CGFloat = 8
    static let actionHorizontalPadding: CGFloat = 12
    static let actionVerticalPadding: CGFloat = 7
    static let actionStrokeWidth: CGFloat = 0.9
    static let actionMinWidth: CGFloat = 58
    static let stateSpacing: CGFloat = 10
    static let stateIconSize: CGFloat = 28
    static let stateHorizontalPadding: CGFloat = 36
    /// Brief hold on the "Added" pill before the card leaves.
    static let addedHoldNanoseconds: UInt64 = 700_000_000
    /// Matches the deny fade/collapse animation duration.
    static let denyCollapseNanoseconds: UInt64 = 280_000_000
    static let denyCollapseDuration: Double = 0.28
    static let addedTransitionDuration: Double = 0.22
    static let removeDuration: Double = 0.32
}

enum AlertsColor {
    static let denyStrokeOpacity = 0.22
    static let denyFillOpacity = 0.42
    static let disabledOpacity = 0.55
    static let addedFillOpacity = 0.88
}
