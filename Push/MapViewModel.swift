//
//  MapViewModel.swift
//  Push
//
//  Owns the main map's pucks and group filter chips, sourced from the data
//  layer. ContentView renders only what this exposes.
//

import Combine
import Foundation
import MapKit

struct GroupFilterItem: Identifiable, Equatable {
    static let allFriendsID = "all"

    let id: String
    let title: String

    static let allFriends = GroupFilterItem(id: allFriendsID, title: "All Friends")
}

struct MapFocusRequest: Identifiable, Equatable {
    let id = UUID()
    let region: MKCoordinateRegion

    static func == (lhs: MapFocusRequest, rhs: MapFocusRequest) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class MapViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<[MapPuckData]> = .idle
    @Published private(set) var filters: [GroupFilterItem] = [.allFriends]
    @Published private(set) var selfPuck: SelfPuckData?
    @Published private(set) var mapFocusRequest: MapFocusRequest?
    @Published var selectedFilterID: String = GroupFilterItem.allFriendsID

    private var vagueRegionalSources: [RegionalPuckSource] = []
    private var currentUserGroupIDs: Set<String> = []
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

    var filteredPucks: [MapPuckData] {
        let pucks = loadState.value ?? []
        guard selectedFilterID != GroupFilterItem.allFriendsID else { return pucks }
        return pucks.filter { $0.groupIDs.contains(selectedFilterID) }
    }

    func renderPucks(for span: MKCoordinateSpan) -> [MapPuckRenderModel] {
        MapDisplayPuckBuilder.renderPucks(
            from: filteredPucks,
            selfPuck: selfPuck,
            vagueSources: filteredVagueRegionalSources,
            latitudeDelta: span.latitudeDelta,
            currentUserGroupIDs: currentUserGroupIDs
        )
    }

    func select(_ renderPuck: MapPuckRenderModel) -> MapPuckData? {
        switch renderPuck {
        case .friend(let puck), .smallGroup(let puck):
            return puck
        case .selfPuck:
            return nil
        case .regionalCluster(let puck):
            mapFocusRequest = MapFocusRequest(
                region: MKCoordinateRegion(
                    center: puck.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: MapFocusLayout.regionalZoomLatitudeDelta,
                        longitudeDelta: MapFocusLayout.regionalZoomLongitudeDelta
                    )
                )
            )
            return nil
        }
    }

    var selectedFilterTitle: String {
        filters.first { $0.id == selectedFilterID }?.title ?? GroupFilterItem.allFriends.title
    }

    /// Friend-derived map content only — self-only does not count.
    /// Vague sources are per-person (`RegionalPuckSource`); only non-self rows count.
    var hasFriendMapContent: Bool {
        let pucks = loadState.value ?? []
        let hasFriendVague = vagueRegionalSources.contains { !$0.containsCurrentUser }
        return !pucks.isEmpty || hasFriendVague
    }

    var surfacePhase: SurfaceContentPhase {
        switch loadState {
        case .idle, .loading:
            return loadState.value == nil ? .loading : phaseForLoadedContent()
        case .failed:
            return loadState.value == nil ? .failed : phaseForLoadedContent()
        case .loaded:
            return phaseForLoadedContent()
        }
    }

    private func phaseForLoadedContent() -> SurfaceContentPhase {
        hasFriendMapContent ? .content : .empty
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
            selfPuck = Self.selfPuck(from: presences, currentUserID: user.id)
            currentUserGroupIDs = viewerGroups
            vagueRegionalSources = MapDisplayPuckBuilder.vagueRegionalSources(
                presences: presences,
                groups: groupList,
                memberships: memberships,
                now: now
            )
            loadState = .loaded(
                MapContentBuilder.pucks(
                    presences: presences, groups: groupList, memberships: memberships, now: now
                )
            )
            // Stamp the revision so the subscription guard can detect duplicates.
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
        } catch {
            selfPuck = nil
            currentUserGroupIDs = []
            vagueRegionalSources = []
            loadState = .failed(error)
        }
    }

    private static func selfPuck(
        from presences: [VisiblePresence],
        currentUserID: Person.ID
    ) -> SelfPuckData? {
        guard
            let presence = presences.first(where: { $0.person.id == currentUserID }),
            let place = presence.placeInfo?.place
        else { return nil }
        return SelfPuckData(
            id: presence.person.id,
            avatarPlaceholder: presence.person.initials,
            profileImageAssetName: presence.person.imageAssetPath,
            coordinate: place.coordinate
        )
    }

    private var filteredVagueRegionalSources: [RegionalPuckSource] {
        guard selectedFilterID != GroupFilterItem.allFriendsID else { return vagueRegionalSources }
        return vagueRegionalSources.filter { $0.groupIDs.contains(selectedFilterID) }
    }
}

private enum MapFocusLayout {
    static let regionalZoomLatitudeDelta = 0.06
    static let regionalZoomLongitudeDelta = 0.06
}
