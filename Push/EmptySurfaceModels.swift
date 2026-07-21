import Foundation

enum SurfaceContentPhase: Equatable {
    case loading
    case empty
    case failed
    case content
    case deferred
}

enum EmptySurfaceCopy {
    static let mapEmptyTitle = "Friends will show up here"
    static let mapEmptyMessage = "When they share status — add friends to get started."
    static let addFriendsAction = "Add friends"

    static let friendsEmptyTitle = "No friends yet"
    static let friendsEmptyMessage = "Add friends to see who's around."

    static let feedDeferredTitle = "No Feed activity yet"
    static let feedDeferredMessage = "Feed isn't live yet — check back later."

    static let calendarEmptyFooter = "No hangouts this week"

    static let startPushEmptyTitle = "No one to push yet"
    static let startPushEmptyMessage = "Add friends first so you have people to send this to."
    static let startPushLoading = "Loading people"

    static let mapLoading = "Loading map"
    static let friendsLoading = "Loading friends"

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
