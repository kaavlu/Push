import SwiftUI

enum AlertsLayout {
    static let topPadding: CGFloat = 14
    static let headerSpacing: CGFloat = 3
    static let listSpacing: CGFloat = 11
    static let cardHeight: CGFloat = 88
    static let actionSpacing: CGFloat = 7
    static let actionHorizontalPadding: CGFloat = 11
    static let actionVerticalPadding: CGFloat = 8
    static let actionStrokeWidth: CGFloat = 0.8
    static let stateSpacing: CGFloat = 12
    static let stateIconSize: CGFloat = 34
    static let stateHorizontalPadding: CGFloat = 28
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.pageHorizontalPadding }
    static func bottomPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 82, standard: 90, large: 96) }
}

enum AlertsColor {
    static let denyStrokeOpacity = 0.28
    static let disabledOpacity = 0.55
}
