//
//  GroupsModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Combine
import Foundation

struct PushGroupData: Identifiable, Equatable {
    let id: String
    let name: String
    let memberCount: Int
    let memberIDs: [String]
    let status: PushGroupStatus
    let activeNowCount: Int
    let nearbyCount: Int
    let planCount: Int
    let imageAssetName: String?
    let fallbackSymbol: String
    let fallbackInitials: String
}

enum PushGroupStatus: String, Equatable {
    case activeNow = "Active now"
    case quiet = "Quiet"
    case planLive = "Push live"
    case nearby = "Nearby"
    case freeSoon = "Free soon"

    var title: String { rawValue }
}

struct PushGroupStat: Identifiable, Equatable {
    let id: String
    let value: Int
    let label: String
}

struct PushGroupMemberData: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarPlaceholder: String
    let profileImageAssetName: String?
    let availability: FriendAvailabilityState?
    let activitySymbolName: String
    let venueStatusText: String
    let lastUpdated: String

    init(
        id: String,
        name: String,
        avatarPlaceholder: String,
        profileImageAssetName: String?,
        availability: FriendAvailabilityState?,
        activitySymbolName: String = "person.fill",
        venueStatusText: String? = nil,
        lastUpdated: String = ""
    ) {
        self.id = id
        self.name = name
        self.avatarPlaceholder = avatarPlaceholder
        self.profileImageAssetName = profileImageAssetName
        self.availability = availability
        self.activitySymbolName = activitySymbolName
        self.venueStatusText = venueStatusText ?? availability?.title ?? "Hidden right now"
        self.lastUpdated = lastUpdated
    }

    var friendRow: FriendRowModel {
        FriendRowModel(
            id: id,
            friend: FriendPuckData(
                id: id,
                name: name,
                avatarPlaceholder: avatarPlaceholder,
                profileImageAssetName: profileImageAssetName,
                activity: "",
                activitySymbolName: activitySymbolName,
                activityDisplayText: "",
                availability: availability ?? .unavailable,
                venueStatusText: venueStatusText,
                lastUpdated: lastUpdated,
                isCurrentUser: false
            ),
            groupLabel: nil
        )
    }
}

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published private(set) var groups: [PushGroupData] = []
    @Published private(set) var selectedGroupID: String?
    @Published private(set) var presentedGroupID: String?
    @Published private(set) var loadState: LoadState<[PushGroupData]> = .idle

    private let container: AppDataContainer?
    private var membersByGroupID: [String: [PushGroupMemberData]] = [:]
    // Holds the active store-change subscription; nil when container is absent.
    private var storeChangeSub: AnyCancellable?
    // Tracks the last revision we loaded so the subscription skips redundant reloads.
    private var lastSeenRevision = 0

    // `container` defaults via `?? .shared` (not `= .shared`) because default-argument
    // expressions are checked in a nonisolated context even inside a @MainActor
    // initializer; `.shared` is a MainActor-isolated mutable static, so the fallback
    // must live in the (MainActor) initializer body instead.
    init(container: AppDataContainer? = nil) {
        let container = container ?? .shared
        self.container = container
        Task { await load() }
        // Subscribe after the initial load task so each real mutation triggers a reload.
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
    }

    /// Preview/test seam: serve injected cards without touching repositories.
    init(groups: [PushGroupData]) {
        container = nil
        self.groups = groups
        selectedGroupID = groups.first?.id
        loadState = .loaded(groups)
    }

    func load() async {
        guard let container else { return }
        if loadState.value == nil { loadState = .loading }
        do {
            let groupList = try await container.groups.groups()
            let memberships = try await container.groups.memberships()
            let statuses = try await container.friends.presenceStatuses()
            let plans = try await container.pushes.activePlans()
            let friendList = try await container.friends.friends()
            let user = try await container.friends.currentUser()
            let places = try await container.pushes.allPlaces()

            let statusesByPersonID = Dictionary(
                uniqueKeysWithValues: statuses.map { ($0.personID, $0) }
            )
            let peopleByID = Dictionary(
                uniqueKeysWithValues: (friendList + [user]).map { ($0.id, $0) }
            )
            let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
            let now = Date()
            let cards = GroupContentBuilder.groupCards(
                groups: groupList,
                memberships: memberships,
                statuses: statusesByPersonID,
                plans: plans,
                now: now
            )
            membersByGroupID = Dictionary(uniqueKeysWithValues: groupList.map { group in
                (
                    group.id,
                    GroupContentBuilder.members(
                        groupID: group.id,
                        memberships: memberships,
                        people: peopleByID,
                        statuses: statusesByPersonID,
                        places: placesByID,
                        now: now
                    )
                )
            })
            groups = cards
            if selectedGroupID == nil { selectedGroupID = cards.first?.id }
            loadState = .loaded(cards)
            // Stamp the revision so the subscription guard can detect duplicates.
            lastSeenRevision = container.storeRevision
        } catch {
            loadState = .failed(error)
        }
    }

    func stats(for group: PushGroupData) -> [PushGroupStat] {
        [
            PushGroupStat(id: "active-now", value: group.activeNowCount, label: "Active now"),
            PushGroupStat(id: "nearby", value: group.nearbyCount, label: "Nearby"),
            PushGroupStat(id: "plans", value: group.planCount, label: "Pushes")
        ]
    }

    func isSelected(_ group: PushGroupData) -> Bool {
        selectedGroupID == group.id
    }

    func select(_ group: PushGroupData) {
        selectedGroupID = group.id
    }

    func openDetail(for group: PushGroupData) {
        selectedGroupID = group.id
        presentedGroupID = group.id
    }

    func closeDetail() {
        presentedGroupID = nil
    }

    func group(for id: String?) -> PushGroupData? {
        groups.first { $0.id == id }
    }

    func members(for group: PushGroupData) -> [PushGroupMemberData] {
        membersByGroupID[group.id] ?? []
    }
}
