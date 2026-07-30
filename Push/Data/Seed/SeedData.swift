//
//  SeedData.swift
//  Push
//
//  The single home for all local app content. Every entity referenced
//  anywhere in the UI is seeded here (people, groups, memberships, places)
//  or in the SeedData+* extensions (presence, plans, history).
//

import Foundation

struct SeedData {
    let currentUserID: Person.ID
    let people: [Person]
    /// Accepted direct friends of the current user (subset of `people`, excludes self).
    let acceptedFriendIDs: Set<Person.ID>
    let groups: [FriendGroup]
    let memberships: [GroupMembership]
    let places: [Place]
    let statuses: [PresenceStatus]
    let policies: [SharingPolicy]
    /// `var` so tests can append lifecycle-specific pushes (historical, cancelled)
    /// to the standard graph instead of rebuilding every field.
    var plans: [PushPlan]
    var responses: [PushResponse]
    let hangouts: [PastHangout]
    let feedEvents: [FeedEvent]
    let friendRequests: [FriendRequest]
    let profile: UserProfile
    /// Moment album rows. Default-empty so narrower seeds (empty graph, test
    /// fixtures) opt in explicitly — Moments never leak into a graph that has
    /// no friends to make them visible.
    var moments: [Moment] = []
    var momentMembers: [MomentMember] = []
    var momentMedia: [MomentMedia] = []

    static func standard(now: Date = Date()) -> SeedData {
        let friends = standardFriends()
        let discoverable = standardDiscoverablePeople()
        let people = friends + [standardCurrentUser()] + discoverable
        let acceptedFriendIDs = Set(friends.map(\.id))
        return SeedData(
            currentUserID: SeedIDs.currentUser,
            people: people,
            acceptedFriendIDs: acceptedFriendIDs,
            groups: standardGroups(),
            memberships: standardMemberships(now: now),
            places: standardPlaces(),
            statuses: standardStatuses(now: now),
            policies: standardPolicies(for: people),
            plans: standardPlans(now: now),
            responses: standardResponses(now: now),
            hangouts: standardHangouts(now: now),
            feedEvents: standardFeedEvents(now: now),
            friendRequests: standardFriendRequests(now: now, people: people),
            profile: standardProfile(),
            moments: standardMoments(now: now),
            momentMembers: standardMomentMembers(now: now),
            momentMedia: standardMomentMedia(now: now)
        )
    }

    /// Current user only — no friends, groups, presence, or plans.
    static func emptyGraph(now: Date = Date()) -> SeedData {
        let user = Person(
            id: SeedIDs.currentUser,
            firstName: "manav",
            imageAssetPath: "assets/profile/manav.jpeg"
        )
        return SeedData(
            currentUserID: SeedIDs.currentUser,
            people: [user],
            acceptedFriendIDs: [],
            groups: [],
            memberships: [],
            places: [],
            statuses: [],
            policies: [],
            plans: [],
            responses: [],
            hangouts: [],
            feedEvents: [],
            friendRequests: [],
            profile: standardProfile()
        )
    }

    /// Direct friends exist but no PresenceStatus rows — list shows "Hidden right now".
    static func friendsWithoutPresence(now: Date = Date()) -> SeedData {
        let seed = standard(now: now)
        return SeedData(
            currentUserID: seed.currentUserID,
            people: seed.people,
            acceptedFriendIDs: seed.acceptedFriendIDs,
            groups: seed.groups,
            memberships: seed.memberships,
            places: seed.places,
            statuses: [],
            policies: seed.policies,
            plans: seed.plans,
            responses: seed.responses,
            hangouts: seed.hangouts,
            feedEvents: seed.feedEvents,
            friendRequests: seed.friendRequests,
            profile: seed.profile
        )
    }

    private static func standardFriendRequests(now: Date, people: [Person]) -> [FriendRequest] {
        let austin = people.first { $0.id == "austin" }
            ?? Person(id: "austin", firstName: "austin", imageAssetPath: nil)
        return [
            FriendRequest(
                id: "request-austin",
                requester: austin,
                recipientID: SeedIDs.currentUser,
                createdAt: now.addingTimeInterval(-SeedTime.halfHour),
                status: .pending,
                isUnread: true,
                mutualFriendCount: 4
            )
        ]
    }

    // MARK: - People

    private static func standardFriends() -> [Person] {
        [
            friend("chitty"), friend("ishan"), friend("nitin"), friend("ohm"),
            friend("pranay"), friend("ram"), friend("roh"), friend("rohan"),
            friend("ryan"), friend("viplove")
        ] + RegionalClusterSeed.cohorts.flatMap(\.people)
    }

    /// Not yet friends — searchable for Add Friends (and austin seeds an incoming request).
    private static func standardDiscoverablePeople() -> [Person] {
        [
            Person(id: "austin", firstName: "austin", imageAssetPath: nil),
            Person(id: "jordan", firstName: "jordan", imageAssetPath: nil)
        ]
    }

    private static func standardCurrentUser() -> Person {
        Person(
            id: SeedIDs.currentUser,
            firstName: "manav",
            imageAssetPath: "assets/profile/manav.jpeg"
        )
    }

    private static func friend(_ slug: String) -> Person {
        Person(id: slug, firstName: slug, imageAssetPath: "assets/friends/\(slug).png")
    }

    // MARK: - Groups + memberships

    private static func standardGroups() -> [FriendGroup] {
        [
            FriendGroup(id: "india", name: "India", imageAssetPath: "assets/groups/India/chitty.png"),
            FriendGroup(id: "exec", name: "Exec", imageAssetPath: "assets/groups/Exec/ram.png"),
            FriendGroup(id: "michigan", name: "Michigan", imageAssetPath: "assets/groups/Michigan/ram.png")
        ]
    }

    /// First listed member of each group is its owner.
    private static let groupRosters: [(groupID: String, memberIDs: [String])] = [
        ("india", ["chitty", "nitin", "ishan", "viplove", "roh"]),
        ("exec", ["ram", "ohm"]),
        ("michigan", ["ram", "rohan", "ryan", "ohm", "pranay"])
    ]

    private static func standardMemberships(now: Date) -> [GroupMembership] {
        let joinedAt = now.addingTimeInterval(-SeedTime.ninetyDays)
        let activeMemberships = groupRosters.flatMap { roster in
            roster.memberIDs.enumerated().map { index, personID in
                GroupMembership(
                    id: "membership-\(roster.groupID)-\(personID)",
                    personID: personID,
                    groupID: roster.groupID,
                    role: index == 0 ? .owner : .member,
                    sharingLevel: .full,
                    membershipStatus: .active,
                    joinedAt: joinedAt
                )
            }
        }
        return activeMemberships + standardPendingGroupInvites(now: now)
    }

    /// Two pending invites addressed to the current user so Alerts' "Group
    /// Requests" section has something to show out of the box in DEBUG,
    /// mirroring `standardFriendRequests`. Both existing groups already have
    /// an owner (ram), so no new group/roster is needed just for this.
    private static func standardPendingGroupInvites(now: Date) -> [GroupMembership] {
        [
            GroupMembership(
                id: "membership-exec-\(SeedIDs.currentUser)",
                personID: SeedIDs.currentUser,
                groupID: "exec",
                role: .member,
                sharingLevel: .full,
                membershipStatus: .invited,
                joinedAt: now.addingTimeInterval(-SeedTime.halfHour)
            ),
            GroupMembership(
                id: "membership-michigan-\(SeedIDs.currentUser)",
                personID: SeedIDs.currentUser,
                groupID: "michigan",
                role: .member,
                sharingLevel: .full,
                membershipStatus: .invited,
                joinedAt: now.addingTimeInterval(-SeedTime.hour)
            )
        ]
    }

    // MARK: - Places

    private static func standardPlaces() -> [Place] {
        [
            Place(
                id: "blue-bottle", name: "Blue Bottle", shortName: "Blue Bottle",
                address: "315 Linden St", vagueLabel: "Hayes Valley",
                latitude: 37.7812, longitude: -122.4078,
                vagueLatitude: 37.7767, vagueLongitude: -122.4241
            ),
            Place(
                id: "dolores-park", name: "Dolores Park", shortName: "Dolores",
                address: "19th St & Dolores St", vagueLabel: "Mission",
                latitude: 37.7596, longitude: -122.4269,
                vagueLatitude: 37.7599, vagueLongitude: -122.4148
            ),
            Place(
                id: "dolores-lawn", name: "Dolores Park Lawn", shortName: "Dolores",
                address: "Dolores Park, 19th St", vagueLabel: "Mission",
                latitude: 37.7673, longitude: -122.4358,
                vagueLatitude: 37.7599, vagueLongitude: -122.4148
            ),
            Place(
                id: "souvla", name: "Souvla", shortName: "Souvla",
                address: "517 Hayes St", vagueLabel: "Hayes Valley",
                latitude: 37.7765, longitude: -122.4231,
                vagueLatitude: 37.7767, vagueLongitude: -122.4241
            ),
            Place(
                id: "crunch", name: "Crunch Fitness", shortName: "Crunch",
                address: "350 Bay St", vagueLabel: "North Beach",
                latitude: 37.7898, longitude: -122.4210,
                vagueLatitude: 37.8061, vagueLongitude: -122.4103
            ),
            Place(
                id: "north-park", name: "North Park", shortName: "North Park",
                address: "North Park", vagueLabel: "North Park",
                latitude: 37.7700, longitude: -122.4100,
                vagueLatitude: 37.7700, vagueLongitude: -122.4100
            ),
            Place(
                id: "little-italy", name: "Little Italy", shortName: "Little Italy",
                address: "Columbus Ave", vagueLabel: "North Beach",
                latitude: 37.7997, longitude: -122.4098,
                vagueLatitude: 37.8061, vagueLongitude: -122.4103
            ),
            Place(
                id: "rams-place", name: "Ram's place", shortName: "Ram's place",
                address: "Ram's place", vagueLabel: "Nob Hill",
                latitude: 37.7920, longitude: -122.4150,
                vagueLatitude: 37.7930, vagueLongitude: -122.4161
            ),
        ] + RegionalClusterSeed.cohorts.map(\.place)
    }

    // MARK: - Regional cluster visual fixtures

    /// DEBUG mock cohorts positioned far enough apart to remain independent
    /// within the map's 100-mile regional clustering radius.
    ///
    /// Counts intentionally exercise every `RegionalActivityPuck` size tier:
    /// New York = small (5), Chicago = medium (6), Seattle = large (16).
    /// Existing SF people and coordinates above remain unchanged.
    static var regionalClusterCohorts: [RegionalClusterSeed.Cohort] {
        RegionalClusterSeed.cohorts
    }
}

enum RegionalClusterSeed {
    struct Cohort {
        let id: String
        let city: String
        let count: Int
        let latitude: Double
        let longitude: Double

        var people: [Person] {
            (1...count).map { index in
                Person(
                    id: "regional-\(id)-\(index)",
                    firstName: "\(city) \(index)",
                    imageAssetPath: nil
                )
            }
        }

        var place: Place {
            Place(
                id: placeID,
                name: "\(city) cluster",
                shortName: city,
                address: city,
                vagueLabel: city,
                latitude: latitude,
                longitude: longitude,
                vagueLatitude: latitude,
                vagueLongitude: longitude
            )
        }

        var placeID: String {
            "regional-\(id)"
        }

        var personIDs: [Person.ID] {
            people.map(\.id)
        }
    }

    static let cohorts: [Cohort] = [
        Cohort(
            id: "new-york", city: "New York", count: 5,
            latitude: 40.7128, longitude: -74.0060
        ),
        Cohort(
            id: "chicago", city: "Chicago", count: 6,
            latitude: 41.8781, longitude: -87.6298
        ),
        Cohort(
            id: "seattle", city: "Seattle", count: 16,
            latitude: 47.6062, longitude: -122.3321
        ),
    ]
}

extension SeedData {
    // MARK: - Policies

    /// Full-visibility global defaults so today's screens render unchanged.
    /// Vague/hidden paths are exercised by unit tests with non-default policies.
    private static func standardPolicies(for people: [Person]) -> [SharingPolicy] {
        people.map { person in
            SharingPolicy(
                id: "policy-\(person.id)-default",
                ownerPersonID: person.id,
                audienceType: .globalDefault,
                audienceID: nil,
                locationVisibility: .exact,
                activityVisibility: .full,
                availabilityVisibility: .full,
                expiresAt: nil
            )
        }
    }

    // MARK: - Date helpers

    /// Next occurrence of a weekday (1 = Sunday … 7 = Saturday) at hour:minute.
    static func next(weekday: Int, hour: Int, minute: Int, after now: Date) -> Date {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        return Calendar.current.nextDate(
            after: now, matching: components, matchingPolicy: .nextTime
        ) ?? now
    }

    /// Today at hour:minute (may be in the past late at night — acceptable for a prototype seed).
    static func today(hour: Int, minute: Int, relativeTo now: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }
}

enum SeedIDs {
    static let currentUser = "manav"
}

enum SeedTime {
    static let minute: TimeInterval = 60
    static let hour: TimeInterval = 3600
    static let halfHour: TimeInterval = 1800
    static let sixHours: TimeInterval = 6 * 3600
    static let ninetyDays: TimeInterval = 90 * 24 * 3600
}
