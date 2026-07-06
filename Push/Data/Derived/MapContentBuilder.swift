//
//  MapContentBuilder.swift
//  Push
//
//  Derives map pucks from visible presence. Grouping is by exact place:
//  people at the same place form one puck. Being together is what makes a
//  puck joinable, so member availability inside multi-person pucks renders
//  as .joinable while canonical availability powers other screens.
//

import Foundation

enum MapContentBuilder {

    static func pucks(
        presences: [VisiblePresence],
        groups: [FriendGroup],
        memberships: [GroupMembership],
        now: Date
    ) -> [MapPuckData] {
        let onMap = presences.filter {
            $0.placeInfo != nil && $0.placeInfo?.isVague == false && $0.availability != nil
        }

        var placeOrder: [Place.ID] = []
        var presencesByPlace: [Place.ID: [VisiblePresence]] = [:]
        for presence in onMap {
            guard let placeID = presence.placeInfo?.place.id else { continue }
            if presencesByPlace[placeID] == nil { placeOrder.append(placeID) }
            presencesByPlace[placeID, default: []].append(presence)
        }

        let activeMembersByGroup: [FriendGroup.ID: Set<Person.ID>] = memberships
            .filter { $0.membershipStatus == .active }
            .reduce(into: [:]) { $0[$1.groupID, default: []].insert($1.personID) }

        return placeOrder.compactMap { placeID in
            guard
                var members = presencesByPlace[placeID],
                let place = members.first?.placeInfo?.place
            else { return nil }
            // Current user renders last in avatar stacks, matching today's map.
            members = members.filter { !$0.isCurrentUser } + members.filter(\.isCurrentUser)
            return puck(
                place: place,
                members: members,
                groups: groups,
                activeMembersByGroup: activeMembersByGroup,
                now: now
            )
        }
    }

    // MARK: - Single puck

    private static func puck(
        place: Place,
        members: [VisiblePresence],
        groups: [FriendGroup],
        activeMembersByGroup: [FriendGroup.ID: Set<Person.ID>],
        now: Date
    ) -> MapPuckData {
        let memberIDs = Set(members.map(\.person.id))
        let kind = puckKind(
            memberIDs: memberIDs, groups: groups, activeMembersByGroup: activeMembersByGroup
        )
        let matchedGroup = groups.first { activeMembersByGroup[$0.id] == memberIDs }
        let isMulti = members.count > 1

        var people = members.map { member in
            friendPuck(member, at: place, others: members, isMulti: isMulti, now: now)
        }
        if kind == .friendGroup, let group = matchedGroup {
            people.insert(groupAvatarEntry(for: group, members: members, at: place, now: now), at: 0)
        }

        return MapPuckData(
            id: "puck-\(place.id)",
            kind: kind,
            people: people,
            activity: members.first?.activity?.name ?? "",
            availability: isMulti ? .joinable : (members.first?.availability ?? .unavailable),
            venueStatusText: puckVenueText(kind: kind, place: place, members: members),
            coordinate: place.coordinate,
            groupIDs: groupTags(
                memberIDs: memberIDs, isMulti: isMulti,
                groups: groups, activeMembersByGroup: activeMembersByGroup
            )
        )
    }

    private static func puckKind(
        memberIDs: Set<Person.ID>,
        groups: [FriendGroup],
        activeMembersByGroup: [FriendGroup.ID: Set<Person.ID>]
    ) -> MapPuckKind {
        switch memberIDs.count {
        case 1:
            return .individual
        case 2:
            return .hangout
        default:
            let matchesWholeGroup = groups.contains { activeMembersByGroup[$0.id] == memberIDs }
            return matchesWholeGroup ? .friendGroup : .cluster
        }
    }

    private static func puckVenueText(
        kind: MapPuckKind,
        place: Place,
        members: [VisiblePresence]
    ) -> String {
        switch kind {
        case .individual:
            return members.first?.statusNote ?? "At \(place.shortName)"
        case .hangout, .friendGroup:
            return "At \(place.shortName)"
        case .cluster:
            return "Group forming near \(place.shortName)"
        }
    }

    /// Individual pucks carry the person's groups; multi pucks carry groups
    /// that contain every member, so filters match today's behavior.
    private static func groupTags(
        memberIDs: Set<Person.ID>,
        isMulti: Bool,
        groups: [FriendGroup],
        activeMembersByGroup: [FriendGroup.ID: Set<Person.ID>]
    ) -> [String] {
        groups.filter { group in
            guard let groupMembers = activeMembersByGroup[group.id] else { return false }
            return isMulti
                ? memberIDs.isSubset(of: groupMembers)
                : !memberIDs.isDisjoint(with: groupMembers)
        }.map(\.id)
    }

    // MARK: - People entries

    private static func friendPuck(
        _ member: VisiblePresence,
        at place: Place,
        others: [VisiblePresence],
        isMulti: Bool,
        now: Date
    ) -> FriendPuckData {
        let companions = others
            .filter { $0.person.id != member.person.id }
            .map(\.person.displayName)
        return FriendPuckData(
            id: member.person.id,
            name: member.person.displayName,
            avatarPlaceholder: member.person.initials,
            profileImageAssetName: member.person.imageAssetPath,
            activity: member.activity?.name ?? "",
            activitySymbolName: member.activity?.symbolName ?? "mappin",
            activityDisplayText: place.shortName,
            availability: isMulti ? .joinable : (member.availability ?? .unavailable),
            venueStatusText: member.statusNote ?? "At \(place.shortName)",
            lastUpdated: RelativeTimeFormatter.label(
                for: member.updatedAt, now: now, isCurrentUser: member.isCurrentUser
            ),
            withWhom: companions.isEmpty ? nil : companions,
            locationLabel: place.address,
            placeName: place.name,
            isCurrentUser: member.isCurrentUser
        )
    }

    private static func groupAvatarEntry(
        for group: FriendGroup,
        members: [VisiblePresence],
        at place: Place,
        now: Date
    ) -> FriendPuckData {
        let newest = members.map(\.updatedAt).max() ?? now
        return FriendPuckData(
            id: "group-\(group.id)",
            name: group.name,
            avatarPlaceholder: group.initials,
            profileImageAssetName: group.imageAssetPath,
            activity: members.first?.activity?.name ?? "",
            activitySymbolName: "person.3.fill",
            activityDisplayText: place.shortName,
            availability: .joinable,
            venueStatusText: "\(group.name) is together",
            lastUpdated: RelativeTimeFormatter.label(for: newest, now: now),
            withWhom: nil,
            locationLabel: place.address,
            placeName: place.name
        )
    }
}
