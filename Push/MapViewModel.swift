//
//  MapViewModel.swift
//  Push
//
//  Owns the main map's pucks and group filter chips, sourced from the data
//  layer. ContentView renders only what this exposes.
//

import Foundation

struct GroupFilterItem: Identifiable, Equatable {
    static let allFriendsID = "all"

    let id: String
    let title: String

    static let allFriends = GroupFilterItem(id: allFriendsID, title: "All Friends")
}

@MainActor
final class MapViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<[MapPuckData]> = .idle
    @Published private(set) var filters: [GroupFilterItem] = [.allFriends]
    @Published var selectedFilterID: String = GroupFilterItem.allFriendsID

    private let friends: FriendRepository
    private let groups: GroupRepository
    private let sharing: SharingRepository
    private let pushes: PushRepository

    init(
        friends: FriendRepository,
        groups: GroupRepository,
        sharing: SharingRepository,
        pushes: PushRepository
    ) {
        self.friends = friends
        self.groups = groups
        self.sharing = sharing
        self.pushes = pushes
        Task { await load() }
    }

    convenience init(container: AppDataContainer = .shared) {
        self.init(
            friends: container.friends,
            groups: container.groups,
            sharing: container.sharing,
            pushes: container.pushes
        )
    }

    var filteredPucks: [MapPuckData] {
        let pucks = loadState.value ?? []
        guard selectedFilterID != GroupFilterItem.allFriendsID else { return pucks }
        return pucks.filter { $0.groupIDs.contains(selectedFilterID) }
    }

    var selectedFilterTitle: String {
        filters.first { $0.id == selectedFilterID }?.title ?? GroupFilterItem.allFriends.title
    }

    func load() async {
        loadState = .loading
        do {
            let now = Date()
            let user = try await friends.currentUser()
            let friendList = try await friends.friends()
            let statuses = try await friends.presenceStatuses()
            let groupList = try await groups.groups()
            let memberships = try await groups.memberships()
            let policies = try await sharing.allPolicies()
            let places = try await pushes.allPlaces()

            let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
            let peopleByID = Dictionary(
                uniqueKeysWithValues: (friendList + [user]).map { ($0.id, $0) }
            )
            let groupIDsByPerson: [Person.ID: Set<String>] = memberships
                .filter { $0.membershipStatus == .active }
                .reduce(into: [:]) { $0[$1.personID, default: []].insert($1.groupID) }
            let viewerGroups = groupIDsByPerson[user.id] ?? []

            let presences = statuses.compactMap { status -> VisiblePresence? in
                guard let owner = peopleByID[status.personID] else { return nil }
                let shared = viewerGroups.intersection(groupIDsByPerson[owner.id] ?? [])
                return VisiblePresenceBuilder.visiblePresence(
                    of: status,
                    owner: owner,
                    viewerID: user.id,
                    sharedGroupIDs: shared,
                    policies: policies,
                    placesByID: placesByID,
                    now: now
                )
            }

            filters = [.allFriends] + groupList.map { GroupFilterItem(id: $0.id, title: $0.name) }
            loadState = .loaded(
                MapContentBuilder.pucks(
                    presences: presences, groups: groupList, memberships: memberships, now: now
                )
            )
        } catch {
            loadState = .failed(error)
        }
    }
}
