//
//  FriendDetailSheetStyle.swift
//  Push
//

import Foundation

enum FriendDetailSheetLayout {

    // MARK: - Shared

    static let heroTopPadding: CGFloat = 25
    static let heroBottomPadding: CGFloat = 20
    static let heroGroupSize: CGFloat = 80
    static let heroNameSpacing: CGFloat = 8
    static let heroInnerSpacing: CGFloat = 4
    static let dividerVerticalPadding: CGFloat = 20
    static let actionHorizontalPadding: CGFloat = 20
    static let actionBottomPadding: CGFloat = 14
    static let actionSpacing: CGFloat = 10

    // MARK: - Group Info Rows

    static let infoHorizontalPadding: CGFloat = 24
    static let infoRowVerticalPadding: CGFloat = 10
    static let infoIconSize: CGFloat = 14
    static let infoIconFrameWidth: CGFloat = 20
    static let infoIconSpacing: CGFloat = 10

    // MARK: - Group Action Buttons

    static let actionHeight: CGFloat = 56
    static let actionCornerRadius: CGFloat = 16
    static let actionIconSize: CGFloat = 16
    static let actionLabelSpacing: CGFloat = 4
    static let actionMinimumScaleFactor: CGFloat = 0.8
    static let primaryTintOpacity: CGFloat = 0.35

    // MARK: - Individual: Section

    static let sectionSpacing: CGFloat = 10
    static let contentHorizontalPadding: CGFloat = 20

    // MARK: - Individual: Header

    static let headerAvatarSize: CGFloat = 62
    static let headerSpacing: CGFloat = 14
    static let headerTextSpacing: CGFloat = 4
    static let headerLiveIndicatorSize: CGFloat = 6

    // MARK: - Individual: Activity Status Card

    static let statusCardPadding: CGFloat = 14
    static let statusCardCornerRadius: CGFloat = 20
    static let statusCardIconSpacing: CGFloat = 14
    static let statusCardIconSize: CGFloat = 18
    static let statusCardIconCircleSize: CGFloat = 44
    static let statusCardIconCircleOpacity: CGFloat = 0.18
    static let statusCardTextSpacing: CGFloat = 6
    static let statusCardAccentTintOpacity: CGFloat = 0.08
    static let statusCardAccentStrokeOpacity: CGFloat = 0.20
    static let statusCardStrokeWidth: CGFloat = 0.8

    // MARK: - Individual: Status Chip

    static let statusChipHorizontalPadding: CGFloat = 8
    static let statusChipVerticalPadding: CGFloat = 3
    static let statusChipBackgroundOpacity: CGFloat = 0.18
    static let statusChipStrokeOpacity: CGFloat = 0.28

    // MARK: - Individual: Header Chip

    static let headerChipHorizontalPadding: CGFloat = 10
    static let headerChipVerticalPadding: CGFloat = 3

    // MARK: - Individual: Sheet Presentation

    static let individualSheetHeight: CGFloat = 250
    static let sheetCornerRadius: CGFloat = 32

    // MARK: - Individual: Primary Action Cards

    static let actionCardHeight: CGFloat = 58
    static let actionCardCornerRadius: CGFloat = 20
    static let actionCardIconSize: CGFloat = 18
    static let actionCardLabelSpacing: CGFloat = 5

    // MARK: - Toast

    static let toastHorizontalPadding: CGFloat = 18
    static let toastVerticalPadding: CGFloat = 10
    static let toastCornerRadius: CGFloat = 22
    static let toastTopPadding: CGFloat = 12
}

enum FriendDetailSheetContent {
    static func groupHeadline(for people: [FriendPuckData]) -> String {
        guard !people.isEmpty else { return "Group" }
        if people.count == 2 {
            return "\(people[0].name) + \(people[1].name)"
        }
        return "\(people.count) people"
    }
}
