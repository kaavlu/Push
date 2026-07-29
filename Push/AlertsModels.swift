import Foundation

struct FriendRequestAlertModel: Identifiable, Equatable {
    let request: FriendRequest

    var id: String { request.id }

    /// Presentation row for the shared Friends card shell — name, avatar, and request subtitle.
    var row: FriendRowModel {
        let person = request.requester
        let friend = FriendPuckData(
            id: person.id,
            name: person.displayName,
            avatarPlaceholder: person.initials,
            profileImageAssetName: person.imageAssetPath,
            activity: "",
            activitySymbolName: "",
            activityDisplayText: "",
            availability: .unavailable,
            venueStatusText: AlertsCopy.requestSubtitle,
            lastUpdated: ""
        )
        return FriendRowModel(
            id: request.id,
            friend: friend,
            groupLabel: AlertsCopy.mutualFriendCountLabel(request.mutualFriendCount)
        )
    }
}

enum AlertsCopy {
    static let requestSubtitle = "Sent you a friend request."
    /// Prefer `EmptySurfaceCopy.alertsEmptyTitle` for empty presentation.
    static let emptyTitle = EmptySurfaceCopy.alertsEmptyTitle
    static let sectionTitle = "Friend Requests"
    static let groupSectionTitle = "Group Requests"
    static let addedLabel = "Added"

    static func groupInviteSubtitle(inviterName: String) -> String {
        "\(inviterName) invited you"
    }

    static func groupMemberCountLabel(_ count: Int) -> String {
        "\(count) member\(count == 1 ? "" : "s")"
    }

    static func mutualFriendCountLabel(_ count: Int) -> String {
        let count = max(0, count)
        return "\(count) mutual friend\(count == 1 ? "" : "s")"
    }
}
