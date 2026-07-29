//
//  PushEmptySurfaceModels.swift
//  Push
//
//  DS-070 / DS-071 — shared phase model + empty-surface copy/layout tokens.
//

import Foundation
import CoreGraphics

/// Required presentation phase for primary content surfaces (DS-070).
enum SurfaceContentPhase: Equatable {
    case loading
    case empty
    case failed
    case content
    case deferred
}

enum EmptySurfaceCopy {
    static let mapEmptyTitle = "Friends will show up here"
    /// Shown only when the viewer has zero friends (not when friends hide presence).
    static let mapEmptyMessage = "Add friends to see who's around."
    static let addFriendsAction = "Add friends"

    static let friendsEmptyTitle = "No friends yet"
    static let friendsEmptyMessage = "Add friends to see who's around."
    static let groupsEmptyTitle = "No groups yet"
    static let groupsEmptyMessage = "Create a circle to coordinate faster."
    static let searchNoMatchTitle = "No matches"
    static let searchNoMatchMessage = "Try a different name or place."

    /// Legacy deferred Feed copy (kept for EmptySurfaceTests / deferred-phase coverage).
    static let feedDeferredTitle = "No Feed activity yet"
    static let feedDeferredMessage = "Feed isn't live yet — check back later."

    static let feedPushesPlaceholderTitle = "Pushes coming next"
    static let feedPushesPlaceholderMessage = "Shared pushes will show up here soon."

    static let feedNowEmptyTitle = "Nothing live yet"
    static let feedNowEmptyMessage = "Live friend activity will appear here later."

    static let calendarEmptyFooter = "No hangouts this week"

    static let startPushEmptyTitle = "No one to push yet"
    static let startPushEmptyMessage = "Add friends first so you have people to send this to."
    static let startPushLoading = "Loading people"

    static let mapLoading = "Loading map"
    static let friendsLoading = "Loading friends"

    static let alertsEmptyTitle = "You're all caught up."
    static let alertsLoading = "Checking alerts"
    static let alertsSurfaceName = "alerts"

    static let blockedEmptyTitle = "No blocked people."
    static let blockedLoading = "Loading blocked people"
    static let blockedSurfaceName = "blocked people"

    static let addFriendsPromptTitle = "Search for friends"
    static let addFriendsPromptMessage = "Try a name or username to find people on Push."
    static let addFriendsSearching = "Searching"
    static let addFriendsNoResultsTitle = "No people found"
    static let addFriendsNoResultsMessage = "Check the spelling or try a different name."
    static let addFriendsSearchFailedTitle = "Couldn't search"

    static func failedTitle(surface: String) -> String {
        "Couldn't load \(surface)"
    }
    static let failedMessage = "Try again in a moment."
    static let retryAction = "Try again"
}

enum EmptySurfaceLayout {
    static let contentSpacing: CGFloat = 12
    static let textSpacing: CGFloat = 6
    static let iconSize: CGFloat = 30
    static let horizontalPadding: CGFloat = 28
    static let topPadding: CGFloat = 60
    static let actionTopPadding: CGFloat = 16
}
