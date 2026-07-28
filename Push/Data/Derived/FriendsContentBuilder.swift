//
//  FriendsContentBuilder.swift
//  Push
//
//  Derives the Friends list from canonical people plus their viewer-scoped
//  visible presence. One row per direct friend — including friends whose
//  presence resolves to nothing, which surface as a hidden/ghost row so the
//  list always answers "who are my people?" in full, never silently dropping
//  someone because they're private right now.
//

import Foundation

enum FriendsContentBuilder {

    static func rows(
        friends: [Person],
        presenceByPersonID: [Person.ID: VisiblePresence],
        groupLabelByPersonID: [Person.ID: String],
        now: Date
    ) -> [FriendRowModel] {
        friends
            .map { person in
                FriendRowModel(
                    id: person.id,
                    friend: friendPuck(for: person, presence: presenceByPersonID[person.id], now: now),
                    groupLabel: groupLabelByPersonID[person.id]
                )
            }
            .sorted(by: rowOrder)
    }

    /// Most-available friends float to the top; ties break alphabetically so
    /// order stays stable between refreshes.
    private static func rowOrder(_ lhs: FriendRowModel, _ rhs: FriendRowModel) -> Bool {
        let lhsPriority = lhs.friend.availability.priority
        let rhsPriority = rhs.friend.availability.priority
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        return lhs.friend.name < rhs.friend.name
    }

    private static func friendPuck(
        for person: Person,
        presence: VisiblePresence?,
        now: Date
    ) -> FriendPuckData {
        guard let presence, let availability = presence.availability else {
            return hiddenFriendPuck(for: person)
        }
        let placeInfo = presence.placeInfo
        let activity = PresenceActivityPresentation.fields(from: presence)
        return FriendPuckData(
            id: person.id,
            name: person.displayName,
            avatarPlaceholder: person.initials,
            profileImageAssetName: person.imageAssetPath,
            activity: activity.activityName,
            activitySymbolName: activity.activitySymbolName,
            activityDisplayText: activity.activityDisplayText,
            availability: availability,
            venueStatusText: activity.venueStatusText,
            lastUpdated: RelativeTimeFormatter.label(
                for: presence.updatedAt, now: now, isCurrentUser: presence.isCurrentUser
            ),
            withWhom: nil,
            locationLabel: placeInfo?.place.address,
            placeName: placeInfo?.place.name,
            isCurrentUser: presence.isCurrentUser
        )
    }

    /// A friend the viewer can't see right now still belongs on the list, shown
    /// calmly as hidden rather than fabricating a location.
    private static func hiddenFriendPuck(for person: Person) -> FriendPuckData {
        let activity = PresenceActivityPresentation.hiddenFields()
        return FriendPuckData(
            id: person.id,
            name: person.displayName,
            avatarPlaceholder: person.initials,
            profileImageAssetName: person.imageAssetPath,
            activity: activity.activityName,
            activitySymbolName: activity.activitySymbolName,
            activityDisplayText: activity.activityDisplayText,
            availability: .unavailable,
            venueStatusText: activity.venueStatusText,
            lastUpdated: "",
            isCurrentUser: false
        )
    }
}
