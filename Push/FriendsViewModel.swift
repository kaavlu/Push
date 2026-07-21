//
//  FriendsViewModel.swift
//  Push
//
//  Owns the Friends list: one row per direct friend, viewer-scoped through
//  the same VisiblePresence pipeline the map uses so privacy is applied in
//  exactly one place. Groups mode reuses GroupsViewModel untouched — this
//  view model is friends-only.
//

import Combine
import Foundation

/// One friend list row: a presentation-ready friend plus optional circle
/// context. Reuses `FriendPuckData` so the existing detail sheet and avatar
/// components render it without adaptation.
struct FriendRowModel: Identifiable, Equatable {
    let id: String
    let friend: FriendPuckData
    let groupLabel: String?

    var searchHaystack: String {
        [friend.name, friend.activity, friend.venueStatusText, friend.placeName ?? "", groupLabel ?? ""]
            .joined(separator: " ")
            .lowercased()
    }
}

/// Quick lenses over the friend list. Membership derives entirely from a
/// friend's live presence — nothing is hardcoded.
enum FriendsFilter: String, CaseIterable, Identifiable {
    case all
    case nearby
    case free
    case active

    var id: Self { self }

    var title: String {
        switch self {
        case .all:    return "All"
        case .nearby: return "Nearby"
        case .free:   return "Free"
        case .active: return "Active"
        }
    }

    func matches(_ friend: FriendPuckData) -> Bool {
        switch self {
        case .all:
            return true
        case .nearby:
            // Anyone with a visible place is somewhere on the map right now.
            return friend.placeName != nil
        case .free:
            return friend.availability == .freeNow || friend.availability == .freeSoon
        case .active:
            return friend.availability == .joinable || friend.availability == .freeNow
        }
    }
}

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published private(set) var rows: [FriendRowModel] = []
    @Published private(set) var loadState: LoadState<[FriendRowModel]> = .idle
    @Published var searchText: String = ""
    @Published var selectedFilter: FriendsFilter = .all
    /// The single row expanded inline for its Directions/Start push/Remove actions.
    @Published var expandedFriendID: String?
    /// Friend IDs with an in-flight remove call, so the row can disable its button.
    @Published private(set) var removingFriendIDs: Set<String> = []
    /// Recoverable mutation error (remove friend) with Retry via `retryLastAction`.
    @Published private(set) var actionError: ActionErrorState?

    private let friends: FriendRepository
    private let groups: GroupRepository
    private let sharing: SharingRepository
    private let pushes: PushRepository
    // Set only in the container convenience init; used to stamp lastSeenRevision after each load.
    private var containerForRefresh: AppDataContainer? = nil
    // Holds the active store-change subscription; nil when initialised without a container.
    private var storeChangeSub: AnyCancellable?
    // Tracks the last revision we loaded so the subscription skips redundant reloads.
    private var lastSeenRevision = 0
    private var pendingRemove: FriendRowModel?

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

    // `container` defaults via `?? .shared` (not `= .shared`) because default-argument
    // expressions are checked in a nonisolated context even inside a @MainActor
    // initializer; `.shared` is a MainActor-isolated mutable static, so the fallback
    // must live in the (MainActor) initializer body instead.
    convenience init(container: AppDataContainer? = nil) {
        let container = container ?? .shared
        self.init(
            friends: container.friends,
            groups: container.groups,
            sharing: container.sharing,
            pushes: container.pushes
        )
        // Capture container so load() can stamp lastSeenRevision via the store.
        containerForRefresh = container
        // Subscribe after the initial load task so each real mutation triggers a reload.
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
    }

    /// Total direct friends — powers the "Friends N" segment badge.
    var friendsCount: Int { rows.count }

    /// Live per-filter tallies for the chip badges.
    var filterCounts: [FriendsFilter: Int] {
        Dictionary(
            uniqueKeysWithValues: FriendsFilter.allCases.map { filter in
                (filter, rows.filter { filter.matches($0.friend) }.count)
            }
        )
    }

    /// Search and the active filter compose: both must pass.
    var filteredRows: [FriendRowModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows.filter { row in
            selectedFilter.matches(row.friend)
                && (query.isEmpty || row.searchHaystack.contains(query))
        }
    }

    func load() async {
        if loadState.value == nil { loadState = .loading }
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

            let presenceByID = visiblePresence(
                statuses: statuses,
                viewer: user,
                peopleByID: peopleByID,
                groupIDsByPerson: groupIDsByPerson,
                viewerGroups: viewerGroups,
                policies: policies,
                placesByID: placesByID,
                now: now
            )
            let groupLabels = primaryGroupLabels(
                friends: friendList, memberships: memberships, groups: groupList
            )

            let builtRows = FriendsContentBuilder.rows(
                friends: friendList,
                presenceByPersonID: presenceByID,
                groupLabelByPersonID: groupLabels,
                now: now
            )
            rows = builtRows
            loadState = .loaded(builtRows)
            // Stamp the revision so the subscription guard can detect duplicates.
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
        } catch {
            loadState = .failed(error)
        }
    }

    /// Toggles inline expansion for `row`; expanding one row collapses any other.
    func toggleExpanded(_ row: FriendRowModel) {
        expandedFriendID = (expandedFriendID == row.id) ? nil : row.id
    }

    func collapse() {
        expandedFriendID = nil
    }

    func dismissActionError() {
        actionError = nil
    }

    func retryLastAction() async {
        guard let pendingRemove else { return }
        await removeFriend(pendingRemove)
    }

    /// Pull-to-refresh: re-warm live snapshot, then reload the friends list.
    func refresh() async {
        try? await containerForRefresh?.refreshSession()
        await load()
    }

    /// Hard-removes the friendship, then reloads so the row disappears from the list.
    func removeFriend(_ row: FriendRowModel) async {
        guard removingFriendIDs.insert(row.id).inserted else { return }
        defer { removingFriendIDs.remove(row.id) }
        do {
            try await friends.removeFriend(row.friend.id)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            if expandedFriendID == row.id { expandedFriendID = nil }
            actionError = nil
            pendingRemove = nil
            await load()
        } catch {
            pendingRemove = row
            actionError = ActionErrorState(
                message: "Couldn't remove \(row.friend.name). Try again."
            )
        }
    }

    // MARK: - Derivation helpers

    private func visiblePresence(
        statuses: [PresenceStatus],
        viewer: Person,
        peopleByID: [Person.ID: Person],
        groupIDsByPerson: [Person.ID: Set<String>],
        viewerGroups: Set<String>,
        policies: [SharingPolicy],
        placesByID: [Place.ID: Place],
        now: Date
    ) -> [Person.ID: VisiblePresence] {
        var result: [Person.ID: VisiblePresence] = [:]
        for status in statuses {
            guard let owner = peopleByID[status.personID], owner.id != viewer.id else { continue }
            let shared = viewerGroups.intersection(groupIDsByPerson[owner.id] ?? [])
            if let presence = VisiblePresenceBuilder.visiblePresence(
                of: status,
                owner: owner,
                viewerID: viewer.id,
                sharedGroupIDs: shared,
                policies: policies,
                placesByID: placesByID,
                now: now
            ) {
                result[owner.id] = presence
            }
        }
        return result
    }

    private func primaryGroupLabels(
        friends: [Person],
        memberships: [GroupMembership],
        groups: [FriendGroup]
    ) -> [Person.ID: String] {
        let groupNameByID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
        return friends.reduce(into: [Person.ID: String]()) { result, person in
            guard
                let membership = memberships.first(where: {
                    $0.personID == person.id && $0.membershipStatus == .active
                }),
                let name = groupNameByID[membership.groupID]
            else { return }
            result[person.id] = name
        }
    }
}
