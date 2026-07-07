//
//  GroupContentBuilder.swift
//  Push
//
//  Derives group cards, stats, and member rows from canonical data. The old
//  mock layer stored these counts by hand and they contradicted the map;
//  now they can't.
//

import Foundation

enum GroupContentBuilder {

    static func groupCards(
        groups: [FriendGroup],
        memberships: [GroupMembership],
        statuses: [Person.ID: PresenceStatus],
        plans: [PushPlan],
        now: Date
    ) -> [PushGroupData] {
        let activeMemberships = memberships.filter { $0.membershipStatus == .active }
        let occupancy = placeOccupancy(statuses: statuses)

        return groups.map { group in
            let memberIDs = activeMemberships.filter { $0.groupID == group.id }.map(\.personID)
            let stats = memberStats(memberIDs: memberIDs, statuses: statuses, occupancy: occupancy)
            let planCount = plans.filter { $0.groupID == group.id && $0.cancelledAt == nil }.count
            return PushGroupData(
                id: group.id,
                name: group.name,
                memberCount: memberIDs.count,
                memberIDs: memberIDs,
                status: badge(
                    groupID: group.id, stats: stats, memberIDs: memberIDs,
                    statuses: statuses, plans: plans, now: now
                ),
                activeNowCount: stats.activeNow,
                nearbyCount: stats.nearby,
                planCount: planCount,
                imageAssetName: group.imageAssetPath,
                fallbackSymbol: group.initials,
                fallbackInitials: group.initials
            )
        }
    }

    static func members(
        groupID: FriendGroup.ID,
        memberships: [GroupMembership],
        people: [Person.ID: Person],
        statuses: [Person.ID: PresenceStatus],
        places: [Place.ID: Place] = [:],
        now: Date = Date()
    ) -> [PushGroupMemberData] {
        memberships
            .filter { $0.groupID == groupID && $0.membershipStatus == .active }
            .compactMap { membership in
                guard let person = people[membership.personID] else { return nil }
                let status = statuses[person.id]
                return PushGroupMemberData(
                    id: person.id,
                    name: person.displayName,
                    avatarPlaceholder: person.initials,
                    profileImageAssetName: person.imageAssetPath,
                    availability: status?.availability,
                    activitySymbolName: status?.activity.symbolName ?? "moon.zzz.fill",
                    venueStatusText: memberStatusText(status: status, places: places),
                    lastUpdated: memberLastUpdated(status: status, now: now)
                )
            }
    }

    private static func memberStatusText(
        status: PresenceStatus?,
        places: [Place.ID: Place]
    ) -> String {
        guard let status else { return "Hidden right now" }
        if let note = status.statusNote, !note.isEmpty { return note }
        if let placeID = status.placeID, let place = places[placeID] {
            return "At \(place.shortName)"
        }
        return status.availability.title
    }

    private static func memberLastUpdated(status: PresenceStatus?, now: Date) -> String {
        guard let status else { return "" }
        return RelativeTimeFormatter.label(for: status.updatedAt, now: now)
    }

    // MARK: - Stats

    /// How many people share each place right now.
    private static func placeOccupancy(statuses: [Person.ID: PresenceStatus]) -> [Place.ID: Int] {
        statuses.values.reduce(into: [:]) { counts, status in
            guard let placeID = status.placeID else { return }
            counts[placeID, default: 0] += 1
        }
    }

    private static func memberStats(
        memberIDs: [Person.ID],
        statuses: [Person.ID: PresenceStatus],
        occupancy: [Place.ID: Int]
    ) -> (activeNow: Int, nearby: Int) {
        var activeNow = 0
        var nearby = 0
        for memberID in memberIDs {
            guard let placeID = statuses[memberID]?.placeID else { continue }
            if occupancy[placeID, default: 0] >= 2 {
                activeNow += 1
            } else {
                nearby += 1
            }
        }
        return (activeNow, nearby)
    }

    private static let activeNowThreshold = 2

    private static func badge(
        groupID: FriendGroup.ID,
        stats: (activeNow: Int, nearby: Int),
        memberIDs: [Person.ID],
        statuses: [Person.ID: PresenceStatus],
        plans: [PushPlan],
        now: Date
    ) -> PushGroupStatus {
        let hasLivePush = plans.contains { plan in
            plan.groupID == groupID
                && plan.cancelledAt == nil
                && plan.state == .collecting
                && Calendar.current.isDate(plan.startsAt, inSameDayAs: now)
        }
        if hasLivePush { return .planLive }
        if stats.activeNow >= activeNowThreshold { return .activeNow }
        if stats.nearby >= 1 { return .nearby }
        if memberIDs.contains(where: { statuses[$0]?.availability == .freeSoon }) { return .freeSoon }
        return .quiet
    }
}
