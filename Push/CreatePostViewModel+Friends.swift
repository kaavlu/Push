//
//  CreatePostViewModel+Friends.swift
//  Push
//
//  Tagging: picker selection and the "With" member rows. Selection ids are real
//  `Person.ID`s (the hub loads the catalog from the social graph), so a pick
//  maps straight onto `MomentDraft.taggedPersonIDs`.
//

import Foundation

@MainActor
extension CreatePostViewModel {

    // MARK: - Friend selection

    func isFriendSelected(_ id: String) -> Bool {
        selectedFriendIDs.contains(id)
    }

    func toggleFriend(_ id: String) {
        guard phase == .composing, screen == .selectFriends else { return }
        guard availableFriends.contains(where: { $0.id == id }) else { return }
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
    }

    func applySelectedFriendsToMembers() {
        let byID = Dictionary(uniqueKeysWithValues: availableFriends.map { ($0.id, $0) })
        // Keep prior With order for still-selected people; append newly tagged friends.
        let retainedIDs = memberPersonRows.map(\.id).filter { selectedFriendIDs.contains($0) }
        let retainedSet = Set(retainedIDs)
        let newcomers = availableFriends.filter {
            selectedFriendIDs.contains($0.id) && !retainedSet.contains($0.id)
        }
        let ordered = retainedIDs.compactMap { byID[$0] } + newcomers

        displayParticipants = ordered.map { friend in
            FeedMediaParticipant(
                id: friend.id,
                displayName: friend.name,
                imageAssetPath: friend.imageAssetName
            )
        }
        memberPersonRows = ordered.map(Self.personRow(from:))
    }

    func seedSelectedFriendsFromMembers() {
        mergeParticipantsIntoAvailableFriends(displayParticipants)
        // Prefer current member order; fall back to selected set already on the draft.
        if !memberPersonRows.isEmpty {
            selectedFriendIDs = Set(memberPersonRows.map(\.id))
        }
    }

    func mergeParticipantsIntoAvailableFriends(_ people: [FeedMediaParticipant]) {
        var byID = Dictionary(uniqueKeysWithValues: availableFriends.map { ($0.id, $0) })
        for person in people where byID[person.id] == nil {
            byID[person.id] = PushRecipientItem(
                id: person.id,
                name: person.displayName,
                memberCount: nil,
                imageAssetName: person.imageAssetPath,
                initials: person.initials,
                isGroup: false
            )
        }
        // Catalog first (stable order), then any extras not already listed.
        let baseIDs = Set(baseAvailableFriends.map(\.id))
        let extras = byID.values
            .filter { !baseIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        availableFriends = baseAvailableFriends + extras
    }

    static func personRow(from friend: PushRecipientItem) -> FriendRowModel {
        FriendRowModel(
            id: friend.id,
            friend: FriendPuckData(
                id: friend.id,
                name: friend.name,
                avatarPlaceholder: friend.initials,
                profileImageAssetName: friend.imageAssetName,
                activity: "",
                activitySymbolName: "",
                activityDisplayText: "",
                availability: .busy,
                venueStatusText: "",
                lastUpdated: ""
            ),
            groupLabel: nil
        )
    }
}
