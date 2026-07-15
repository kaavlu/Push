import Foundation

struct FriendRequestAlertModel: Identifiable, Equatable {
    let request: FriendRequest

    var id: String { request.id }

    var row: FriendRowModel {
        let person = request.requester
        let friend = FriendPuckData(
            id: person.id,
            name: person.displayName,
            avatarPlaceholder: person.initials,
            profileImageAssetName: person.imageAssetPath,
            activity: "Friend request",
            activitySymbolName: "person.badge.plus",
            activityDisplayText: "Sent you a friend request",
            availability: .unavailable,
            venueStatusText: "Sent you a friend request",
            lastUpdated: ""
        )
        return FriendRowModel(id: request.id, friend: friend, groupLabel: nil)
    }
}
