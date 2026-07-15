import SwiftUI

enum AddFriendsLayout {
    static let topPadding: CGFloat = 14
    static let headerSpacing: CGFloat = 3
    static let stackSpacing: CGFloat = 14
    static let listSpacing: CGFloat = 11
    static let cardHeight: CGFloat = 88
    static let actionSpacing: CGFloat = 7
    static let actionHorizontalPadding: CGFloat = 12
    static let actionVerticalPadding: CGFloat = 8
    static let actionStrokeWidth: CGFloat = 0.8
    static let stateSpacing: CGFloat = 12
    static let stateIconSize: CGFloat = 34
    static let stateHorizontalPadding: CGFloat = 28
    static let searchDebounceNanoseconds: UInt64 = 280_000_000
    static let minQueryLength = 1

    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.pageHorizontalPadding
    }

    static func bottomPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.value(compact: 82, standard: 90, large: 96)
    }
}

enum AddFriendsColor {
    static let denyStrokeOpacity = 0.28
    static let disabledOpacity = 0.55
}
