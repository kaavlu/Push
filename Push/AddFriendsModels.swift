import Foundation

/// Presentation row for one search hit on Add Friends.
struct AddFriendRowModel: Identifiable, Equatable {
    let result: PersonSearchResult
    var id: String { result.id }

    var displayName: String { result.person.displayName }
    var handle: String {
        let raw = result.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "" }
        return raw.hasPrefix("@") ? raw : "@\(raw)"
    }
    var imageAssetPath: String? { result.person.imageAssetPath }
    var initials: String { result.person.initials }
    var relation: FriendshipRelation { result.relation }

    var row: FriendRowModel {
        let friend = FriendPuckData(
            id: result.person.id,
            name: displayName,
            avatarPlaceholder: initials,
            profileImageAssetName: imageAssetPath,
            activity: handle,
            activitySymbolName: "person.fill",
            activityDisplayText: handle,
            availability: .unavailable,
            venueStatusText: handle,
            lastUpdated: ""
        )
        return FriendRowModel(id: result.id, friend: friend, groupLabel: nil)
    }
}

enum AddFriendsContentState: Equatable {
    case prompt
    case loading
    case results([AddFriendRowModel])
    case noResults
    case failed
}
