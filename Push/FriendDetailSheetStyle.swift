//
//  FriendDetailSheetStyle.swift
//  Push
//

import Foundation

enum FriendDetailSheetLayout {
    static let heroTopPadding: CGFloat = 24
    static let heroBottomPadding: CGFloat = 20
    static let heroAvatarSize: CGFloat = 72
    static let heroGroupSize: CGFloat = 80
    static let heroNameSpacing: CGFloat = 8
    static let heroInnerSpacing: CGFloat = 4
    static let infoHorizontalPadding: CGFloat = 24
    static let infoRowVerticalPadding: CGFloat = 10
    static let infoIconSize: CGFloat = 14
    static let infoIconFrameWidth: CGFloat = 20
    static let infoIconSpacing: CGFloat = 10
    static let dividerVerticalPadding: CGFloat = 20
    static let actionHorizontalPadding: CGFloat = 20
    static let actionBottomPadding: CGFloat = 32
    static let actionSpacing: CGFloat = 10
    static let actionHeight: CGFloat = 56
    static let actionCornerRadius: CGFloat = 16
    static let actionIconSize: CGFloat = 16
    static let actionLabelSpacing: CGFloat = 4
    static let actionMinimumScaleFactor: CGFloat = 0.8
    static let primaryTintOpacity: CGFloat = 0.35
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
