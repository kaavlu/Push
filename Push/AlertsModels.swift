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
        return FriendRowModel(id: request.id, friend: friend, groupLabel: nil)
    }
}

enum AlertsCopy {
    static let requestSubtitle = "Sent you a friend request."
    static let emptyTitle = "You're all caught up."
    static let sectionTitle = "Friend Requests"
    static let groupSectionTitle = "Group Requests"
    static let addedLabel = "Added"

    static func groupInviteSubtitle(inviterName: String) -> String {
        "\(inviterName) invited you to join."
    }

    static func groupMemberCountLabel(_ count: Int) -> String {
        "\(count) member\(count == 1 ? "" : "s")"
    }
}
