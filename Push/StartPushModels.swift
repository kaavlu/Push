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

@MainActor
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

    @Published private(set) var groups: [PushRecipientItem] = []
    @Published private(set) var friends: [PushRecipientItem] = []
    @Published private(set) var likelyFreeNow: [PushRecipientItem] = []
    @Published private(set) var mightBeInterested: [PushRecipientItem] = []
    @Published private(set) var loadState: LoadState<Void> = .idle

    private let container: AppDataContainer?
    // Prevents duplicate submissions if the user somehow triggers the flow twice.
    private var hasSubmitted = false

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

    init(container: AppDataContainer = .shared) {
        self.container = container
        Task { await load() }
    }

    func load() async {
        guard let container else { return }
        loadState = .loading
        do {
            let groupList = try await container.groups.groups()
            let memberships = try await container.groups.memberships()
            let friendList = try await container.friends.friends()
            let statuses = try await container.friends.presenceStatuses()

            let statusByPersonID = Dictionary(uniqueKeysWithValues: statuses.map { ($0.personID, $0) })
            let memberCountByGroup: [String: Int] = memberships
                .filter { $0.membershipStatus == .active }
                .reduce(into: [:]) { $0[$1.groupID, default: 0] += 1 }

            groups = groupList.map { group in
                PushRecipientItem(
                    id: "group_\(group.id)",
                    name: group.name,
                    memberCount: memberCountByGroup[group.id] ?? 0,
                    imageAssetName: group.imageAssetPath,
                    initials: String(group.name.prefix(2)).uppercased(),
                    isGroup: true
                )
            }
            let friendItems = friendList.map { friend in
                (person: friend, item: PushRecipientItem(
                    id: "friend_\(friend.id)",
                    name: friend.displayName,
                    memberCount: nil,
                    imageAssetName: friend.imageAssetPath,
                    initials: friend.initials,
                    isGroup: false
                ))
            }
            friends = friendItems.map(\.item)
            likelyFreeNow = friendItems.filter {
                let availability = statusByPersonID[$0.person.id]?.availability
                return availability == .freeNow || availability == .joinable
            }.map(\.item)
            mightBeInterested = friendItems.filter {
                let availability = statusByPersonID[$0.person.id]?.availability
                return availability == .maybeDown || availability == .freeSoon
            }.map(\.item)
            loadState = .loaded(())
        } catch {
            loadState = .failed(error)
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

    /// Submits the draft into shared local state. Called when the flow advances
    /// from step 3 to the confirmation step, so the push exists before step 4.
    func submit() async {
        guard let container, !hasSubmitted else { return }
        hasSubmitted = true
        let draft = PushDraft(
            title: pushText.trimmingCharacters(in: .whitespacesAndNewlines),
            recipientIDs: selectedRecipientIDs,
            startsAt: selectedTime,
            locationText: location.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            creatorID: container.currentUserID
        )
        do {
            _ = try await container.pushes.createPush(draft)
        } catch {
            // Local repo never throws; a real backend would surface this. Flag
            // stays true so a failed submit does not silently retry.
        }
    }
}
