//
//  MapDisplayPuckBuilder.swift
//  Push
//
//  Builds zoom-aware map presentation pucks from canonical exact-place pucks.
//

import CoreLocation
import Foundation

enum MapDisplayPuckBuilder {
    static func renderPucks(
        from pucks: [MapPuckData],
        selfPuck: SelfPuckData?,
        vagueSources: [RegionalPuckSource] = [],
        latitudeDelta: Double,
        currentUserGroupIDs: Set<String> = []
    ) -> [MapPuckRenderModel] {
        let exact = pucks.map(ClusterSource.exact)
        let selfSource: ClusterSource? = pucks.contains(where: \.includesCurrentUser)
            ? nil
            : selfPuck.map(ClusterSource.selfPuck)
        let vague = vagueSources.map(ClusterSource.vague)

        guard latitudeDelta > Layout.closeLatitudeDelta else {
            return exactRenderPucks(from: pucks, selfPuck: selfPuck)
        }

        let sources = exact + Array(selfSource.map { [$0] } ?? []) + vague
        return regionalizedSources(
            from: sources,
            radiusMiles: Layout.finalRadiusMiles,
            currentUserGroupIDs: currentUserGroupIDs
        )
    }

    static func vagueRegionalSources(
        presences: [VisiblePresence],
        groups: [FriendGroup],
        memberships: [GroupMembership],
        now: Date
    ) -> [RegionalPuckSource] {
        let activeMembersByGroup = memberships.reduce(into: [String: Set<String>]()) {
            if $1.membershipStatus == .active { $0[$1.groupID, default: []].insert($1.personID) }
        }
        return presences.compactMap { presence in
            guard
                let placeInfo = presence.placeInfo,
                placeInfo.isVague,
                let coordinate = placeInfo.place.vagueCoordinate,
                let availability = presence.availability
            else { return nil }
            let personIDs: Set<String> = [presence.person.id]
            let groupIDs = groupTags(
                memberIDs: personIDs, groups: groups, activeMembersByGroup: activeMembersByGroup
            )
            return RegionalPuckSource(
                id: "vague-\(presence.person.id)",
                coordinate: coordinate,
                people: [friendPuck(from: presence, placeInfo: placeInfo, now: now)],
                availability: availability,
                regionName: placeInfo.place.vagueLabel,
                containsCurrentUser: presence.isCurrentUser,
                groupIDs: groupIDs
            )
        }
    }

    private static func exactRenderPucks(
        from pucks: [MapPuckData],
        selfPuck: SelfPuckData?
    ) -> [MapPuckRenderModel] {
        let exact = pucks.map { $0.kind == .individual ? MapPuckRenderModel.friend($0) : .smallGroup($0) }
        guard !pucks.contains(where: \.includesCurrentUser) else { return exact }
        return exact + Array(selfPuck.map { [.selfPuck($0)] } ?? [])
    }

    private static func regionalizedSources(
        from sources: [ClusterSource],
        radiusMiles: Double,
        currentUserGroupIDs: Set<String>
    ) -> [MapPuckRenderModel] {
        var remaining = sources
        var result: [MapPuckRenderModel] = []
        while let seed = remaining.first {
            let cluster = remaining.filter {
                seed.coordinate.distanceMiles(to: $0.coordinate) <= radiusMiles
            }
            remaining.removeAll { item in cluster.contains { $0.id == item.id } }
            if !cluster.isEmpty {
                result.append(.regionalCluster(regionalPuck(from: cluster, currentUserGroupIDs: currentUserGroupIDs)))
            }
        }
        return result
    }

    private static func regionalPuck(
        from sources: [ClusterSource],
        currentUserGroupIDs: Set<String>
    ) -> RegionalPuckModel {
        let people = uniquePeople(from: sources)
        let groupIDs = Array(Set(sources.flatMap(\.groupIDs))).sorted()
        let availabilityCounts = Dictionary(grouping: people, by: \.availability).mapValues(\.count)
        return RegionalPuckModel(
            id: "regional-\(sources.map(\.id).sorted().joined(separator: "-"))",
            coordinate: centerCoordinate(for: sources),
            memberCount: people.count,
            containsCurrentUser: sources.contains(where: \.containsCurrentUser),
            containsJoinedGroup: !Set(groupIDs).isDisjoint(with: currentUserGroupIDs),
            activeCount: activeCount(from: people),
            joinableCount: availabilityCounts[.joinable, default: 0],
            busyCount: busyCount(from: availabilityCounts),
            dominantAvailability: dominantAvailability(from: availabilityCounts),
            representativeAvatars: Array(people.prefix(Layout.representativeAvatarLimit)),
            regionName: dominantRegionName(from: sources),
            activityScore: activityScore(from: people),
            groupIDs: groupIDs
        )
    }

    private static func uniquePeople(from sources: [ClusterSource]) -> [FriendPuckData] {
        var seen: Set<String> = []
        return sources.flatMap(\.people).filter {
            guard !$0.id.hasPrefix(Layout.groupAvatarIDPrefix), !seen.contains($0.id) else { return false }
            seen.insert($0.id)
            return true
        }
    }

    private static func activeCount(from people: [FriendPuckData]) -> Int {
        people.filter { [.freeNow, .joinable, .maybeDown, .freeSoon].contains($0.availability) }.count
    }

    private static func busyCount(from counts: [FriendAvailabilityState: Int]) -> Int {
        counts[.busy, default: 0] + counts[.driving, default: 0] + counts[.unavailable, default: 0]
    }

    private static func dominantAvailability(
        from counts: [FriendAvailabilityState: Int]
    ) -> FriendAvailabilityState {
        counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.priority > rhs.key.priority : lhs.value < rhs.value
        }?.key ?? .busy
    }

    private static func activityScore(from people: [FriendPuckData]) -> Double {
        let score = people.reduce(0.0) { total, person in
            total + max(0.0, Double(Layout.unavailableScore - person.availability.priority))
        }
        return min(1.0, score / max(Double(people.count * Layout.unavailableScore), 1.0))
    }

    private static func centerCoordinate(for sources: [ClusterSource]) -> CLLocationCoordinate2D {
        let count = Double(max(sources.count, 1))
        let latitude = sources.reduce(0) { $0 + $1.coordinate.latitude } / count
        let longitude = sources.reduce(0) { $0 + $1.coordinate.longitude } / count
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func dominantRegionName(from sources: [ClusterSource]) -> String {
        let grouped = Dictionary(grouping: sources.map(\.regionName), by: { $0 })
        return grouped.max { $0.value.count < $1.value.count }?.key ?? "Nearby"
    }

    private static func friendPuck(
        from presence: VisiblePresence,
        placeInfo: VisiblePresence.VisiblePlaceInfo,
        now: Date
    ) -> FriendPuckData {
        // Regional sources keep vague place wording for the status line even when
        // activity is present — activity still drives badge name + symbol.
        let activity = PresenceActivityPresentation.fields(from: presence)
        return FriendPuckData(
            id: presence.person.id,
            name: presence.person.displayName,
            avatarPlaceholder: presence.person.initials,
            profileImageAssetName: presence.person.imageAssetPath,
            activity: activity.activityName,
            activitySymbolName: activity.activitySymbolName,
            activityDisplayText: activity.activityDisplayText,
            availability: presence.availability ?? .unavailable,
            venueStatusText: "Near \(placeInfo.place.vagueLabel)",
            lastUpdated: RelativeTimeFormatter.label(
                for: presence.updatedAt, now: now, isCurrentUser: presence.isCurrentUser
            ),
            locationLabel: nil,
            placeName: placeInfo.place.vagueLabel,
            isCurrentUser: presence.isCurrentUser
        )
    }

    private static func groupTags(
        memberIDs: Set<Person.ID>,
        groups: [FriendGroup],
        activeMembersByGroup: [FriendGroup.ID: Set<Person.ID>]
    ) -> [String] {
        groups.filter { group in
            guard let groupMembers = activeMembersByGroup[group.id] else { return false }
            return !memberIDs.isDisjoint(with: groupMembers)
        }.map(\.id)
    }
}

private enum ClusterSource {
    case exact(MapPuckData)
    case selfPuck(SelfPuckData)
    case vague(RegionalPuckSource)

    var id: String {
        switch self {
        case .exact(let puck): return puck.id
        case .selfPuck(let puck): return "self-\(puck.id)"
        case .vague(let source): return source.id
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .exact(let puck): return puck.coordinate
        case .selfPuck(let puck): return puck.coordinate
        case .vague(let source): return source.coordinate
        }
    }

    var people: [FriendPuckData] {
        switch self {
        case .exact(let puck): return puck.people
        case .selfPuck(let puck):
            return [FriendPuckData(
                id: puck.id, name: "You", avatarPlaceholder: puck.avatarPlaceholder,
                profileImageAssetName: puck.profileImageAssetName, activity: "",
                activitySymbolName: "person.fill", activityDisplayText: "You",
                availability: .maybeDown, venueStatusText: "You", isCurrentUser: true
            )]
        case .vague(let source): return source.people
        }
    }

    var groupIDs: [String] {
        switch self {
        case .exact(let puck): return puck.groupIDs
        case .selfPuck: return []
        case .vague(let source): return source.groupIDs
        }
    }

    var regionName: String {
        switch self {
        case .exact(let puck): return puck.people.first?.placeName ?? "Nearby"
        case .selfPuck: return "Your area"
        case .vague(let source): return source.regionName
        }
    }

    var canRenderExactly: Bool {
        if case .vague = self { return false }
        return true
    }

    var isVague: Bool {
        if case .vague = self { return true }
        return false
    }

    var containsCurrentUser: Bool {
        switch self {
        case .exact(let puck): return puck.includesCurrentUser
        case .selfPuck: return true
        case .vague(let source): return source.containsCurrentUser
        }
    }

    var isIndividualExact: Bool {
        if case .exact(let puck) = self { return puck.kind == .individual }
        return false
    }

    var isSmallGroupExact: Bool {
        if case .exact(let puck) = self { return puck.kind != .individual }
        return false
    }

    var renderModel: MapPuckRenderModel {
        switch self {
        case .exact(let puck):
            return puck.kind == .individual ? .friend(puck) : .smallGroup(puck)
        case .selfPuck(let puck):
            return .selfPuck(puck)
        case .vague:
            fatalError("Vague sources must render inside regional clusters.")
        }
    }

    func containsJoinedGroup(_ currentUserGroupIDs: Set<String>) -> Bool {
        !Set(groupIDs).isDisjoint(with: currentUserGroupIDs)
    }
}

private extension CLLocationCoordinate2D {
    func distanceMiles(to other: CLLocationCoordinate2D) -> Double {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to) / Layout.metersPerMile
    }
}

private enum Layout {
    static let closeLatitudeDelta = 0.22
    static let finalRadiusMiles = 100.0
    static let metersPerMile = 1_609.344
    static let groupAvatarIDPrefix = "group-"
    static let representativeAvatarLimit = 3
    static let unavailableScore = 6
}
