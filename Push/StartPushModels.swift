//
//  StartPushModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import Foundation


struct PushRecipientItem: Identifiable, Equatable {
    let id: String
    let name: String
    let memberCount: Int?
    let imageAssetName: String?
    let initials: String
    let isGroup: Bool
}

let pushSuggestions = ["Coffee run", "Taco night", "Sunset walk", "Hit the gym", "Dessert run", "Game night"]

private let pushTextMaxLength = 120

final class StartPushViewModel: ObservableObject {
    @Published var step: Int = 1
    @Published var selectedRecipientIDs: Set<String> = []
    @Published var pushText: String = "" {
        didSet {
            if pushText.count > pushTextMaxLength {
                pushText = String(pushText.prefix(pushTextMaxLength))
            }
        }
    }
    @Published var selectedTime: Date = Date()
    @Published var location: String = ""
    @Published var notes: String = ""
    @Published var searchText: String = ""

    let groups: [PushRecipientItem]
    let friends: [PushRecipientItem]

    var canAdvanceStep1: Bool { !selectedRecipientIDs.isEmpty }
    var canAdvanceStep2: Bool { !pushText.trimmingCharacters(in: .whitespaces).isEmpty }
    var characterCount: Int { pushText.count }
    var pushTextMaxCount: Int { pushTextMaxLength }

    var selectedRecipients: [PushRecipientItem] {
        (groups + friends).filter { selectedRecipientIDs.contains($0.id) }
    }

    var filteredFriends: [PushRecipientItem] {
        guard !searchText.isEmpty else { return friends }
        return friends.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredGroups: [PushRecipientItem] {
        guard !searchText.isEmpty else { return groups }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var primaryRecipientLabel: String {
        guard let first = selectedRecipients.first else { return "" }
        let extra = selectedRecipients.count - 1
        return extra == 0 ? first.name : "\(first.name) +\(extra)"
    }

    init() {
        groups = GroupsMockData.groups.map { group in
            PushRecipientItem(
                id: "group_\(group.id)",
                name: group.name,
                memberCount: group.memberCount,
                imageAssetName: group.imageAssetName,
                initials: String(group.name.prefix(2)).uppercased(),
                isGroup: true
            )
        }
        friends = RealWorldMockData.friends.map { friend in
            PushRecipientItem(
                id: "friend_\(friend.id)",
                name: friend.displayName,
                memberCount: nil,
                imageAssetName: friend.imageAssetName,
                initials: friend.initials,
                isGroup: false
            )
        }
    }

    func toggleRecipient(_ id: String) {
        if selectedRecipientIDs.contains(id) {
            selectedRecipientIDs.remove(id)
        } else {
            selectedRecipientIDs.insert(id)
        }
    }

    func isSelected(_ id: String) -> Bool {
        selectedRecipientIDs.contains(id)
    }

    func advance() {
        guard step < 4 else { return }
        step += 1
    }

    func goBack() {
        guard step > 1 else { return }
        step -= 1
    }

    func editFromConfirmation() {
        step = 3
    }
}
