//
//  FriendsStyle.swift
//  Push
//
//  Layout tokens and the mode enum for the Friends screen. Colors defer to
//  the shared Push palette / glass system; only screen-local geometry and
//  opacities live here.
//

import SwiftUI

enum FriendsMode: String, CaseIterable, Identifiable {
    case friends
    case groups

    var id: Self { self }

    var title: String {
        switch self {
        case .friends: return "Friends"
        case .groups:  return "Groups"
        }
    }

    var subtitle: String {
        switch self {
        case .friends: return "See who's around"
        case .groups:  return "Your circles"
        }
    }
}

enum FriendsLayout {
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.pageHorizontalPadding }
    static let topPadding: CGFloat = 14
    static func bottomPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 82, standard: 90, large: 96) }
    static func screenStackSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 12, standard: 14, large: 16) }

    // Header
    static let headerButtonSize: CGFloat = 44
    static let headerButtonIconSize: CGFloat = 15
    static let headerSubtitleSpacing: CGFloat = 3

    // Mode switch
    static let switchPadding: CGFloat = 4
    static let switchItemSpacing: CGFloat = 4
    static let switchCornerRadius: CGFloat = 22
    static let switchItemCornerRadius: CGFloat = 18
    static let switchItemVerticalPadding: CGFloat = 9
    static let switchCountSpacing: CGFloat = 6
    static let switchCountHorizontalPadding: CGFloat = 7
    static let switchCountVerticalPadding: CGFloat = 2
    static let switchContainerShadowRadius: CGFloat = 10
    static let switchContainerShadowYOffset: CGFloat = 3
    static let switchSelectedShadowRadius: CGFloat = 8
    static let switchSelectedShadowYOffset: CGFloat = 3
    static let switchAnimationResponse = 0.28
    static let switchAnimationDamping = 0.86

    // Search
    static let searchCornerRadius: CGFloat = 18
    static let searchHorizontalPadding: CGFloat = 14
    static let searchVerticalPadding: CGFloat = 11
    static let searchIconSize: CGFloat = 14
    static let searchSpacing: CGFloat = 9
    static let searchRowSpacing: CGFloat = 10

    // Filter chips
    static let chipRowSpacing: CGFloat = 8
    static let filterChipHorizontalPadding: CGFloat = 13
    static let filterChipVerticalPadding: CGFloat = 8
    static let filterChipCornerRadius: CGFloat = 16
    static let chipCountSpacing: CGFloat = 6
    static let chipCountHorizontalPadding: CGFloat = 6
    static let chipCountVerticalPadding: CGFloat = 1
    static let chipStrokeWidth: CGFloat = 0.9

    // Section header
    static let sectionHeaderSpacing: CGFloat = 8
    static let sectionHeaderKerning: CGFloat = 0.9
    static let sectionCountHorizontalPadding: CGFloat = 7
    static let sectionCountVerticalPadding: CGFloat = 2
    static let sectionHeaderBottomPadding: CGFloat = 2

    // Rows / cards
    static let listSpacing: CGFloat = 11
    static let cardCornerRadius: CGFloat = 24
    static func cardPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 11, standard: 12, large: 13) }

    // Friend row
    static func rowSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.rowSpacing }
    static func rowAvatarSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.avatarSmall }
    static let rowRingWidth: CGFloat = 2.5
    static let rowTextSpacing: CGFloat = 4
    static let rowSubtitleSpacing: CGFloat = 5
    static let rowSubtitleIconSize: CGFloat = 11
    static let rowGroupTagSpacing: CGFloat = 4
    static let rowGroupTagIconSize: CGFloat = 9
    static let rowTrailingSpacing: CGFloat = 6
    static let chipHorizontalPadding: CGFloat = 10
    static let chipVerticalPadding: CGFloat = 5
    static let liveDotSize: CGFloat = 5
    static let liveTimestampSpacing: CGFloat = 4

    // Group card
    static func groupAvatarSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 48, standard: 51, large: 54) }
    static func groupAvatarCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 16, standard: 17, large: 18) }
    static func groupIdentitySpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.rowSpacing }
    static let groupTextSpacing: CGFloat = 3
    static let groupSummarySpacing: CGFloat = 10

    // Empty state
    static let emptyStateSpacing: CGFloat = 10
    static let emptyStateIconSize: CGFloat = 30
    static let emptyStateTopPadding: CGFloat = 60

    static let minimumTextScale = 0.82
}

enum FriendsColor {
    static let cardStrokeOpacity = 0.18
    static let cardStrokeWidth: CGFloat = 0.8
    static let ringOpacity = 0.9
    static let chipStrokeOpacity = 0.30

    // Warm cream / ivory system — keeps the screen off the gray system material.
    static let pageIvory = Color(red: 0.988, green: 0.964, blue: 0.902)
    static let cardCream = Color(red: 1.0, green: 0.992, blue: 0.955)
    static let cardCreamOpacity = 0.58

    // Segmented control: champagne track, ivory selection, walnut/gold details.
    static let switchTrack = Color(red: 0.925, green: 0.872, blue: 0.755)
    static let switchTrackHighlight = Color(red: 1.0, green: 0.972, blue: 0.902)
    static let switchTrackShadow = Color(red: 0.50, green: 0.34, blue: 0.18)
    static let switchSelectedCream = Color(red: 1.0, green: 0.988, blue: 0.935)
    static let switchSelectedShadow = Color(red: 0.56, green: 0.36, blue: 0.16)
    static let switchActiveText = PushColorPalette.Accent.walnut
    static let switchInactiveText = Color(red: 0.55, green: 0.40, blue: 0.25)
    static let switchActiveCountFill = Color(red: 0.965, green: 0.855, blue: 0.515)
    static let switchInactiveCountFill = Color(red: 0.805, green: 0.690, blue: 0.475)
    static let switchCountText = Color(red: 0.40, green: 0.25, blue: 0.13)
    static let switchContainerShadowOpacity = 0.10
    static let switchContainerHighlightOpacity = 0.48
    static let switchContainerInsetOpacity = 0.08
    static let switchSelectedShadowOpacity = 0.18

    // Filter chips + section badge: walnut fill vs. cream glass.
    static let chipSelectedFill = PushColorPalette.Accent.walnut
    static let chipSelectedText = Color(red: 1.0, green: 0.97, blue: 0.90)
    static let chipStrokeWalnutOpacity = 0.18
    static let chipCountInactiveOpacity = 0.12
    static let chipCountSelectedOpacity = 0.24
    static let sectionBadgeFillOpacity = 0.12
}
