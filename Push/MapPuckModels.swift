//
//  MapPuckModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import CoreLocation
import Foundation

enum MapPuckKind: Equatable {
    case individual
    case hangout
    case cluster
    case friendGroup
}

struct MapPuckData: Identifiable, Equatable {
    let id: String
    let kind: MapPuckKind
    let people: [FriendPuckData]
    let activity: String
    let availability: FriendAvailabilityState
    let venueStatusText: String
    let coordinate: CLLocationCoordinate2D
    let groups: [FriendGroupFilter]
    /// Canonical group IDs used for map filtering. Replaces the legacy
    /// `groups` enum field, which goes away with the old mock layer.
    let groupIDs: [String]

    init(
        id: String,
        kind: MapPuckKind,
        people: [FriendPuckData],
        activity: String,
        availability: FriendAvailabilityState,
        venueStatusText: String,
        coordinate: CLLocationCoordinate2D,
        groups: [FriendGroupFilter] = [],
        groupIDs: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.people = people
        self.activity = activity
        self.availability = availability
        self.venueStatusText = venueStatusText
        self.coordinate = coordinate
        self.groups = groups
        self.groupIDs = groupIDs
    }

    var includesCurrentUser: Bool {
        people.contains { $0.isCurrentUser }
    }

    static func == (lhs: MapPuckData, rhs: MapPuckData) -> Bool {
        lhs.id == rhs.id
            && lhs.kind == rhs.kind
            && lhs.people == rhs.people
            && lhs.activity == rhs.activity
            && lhs.availability == rhs.availability
            && lhs.venueStatusText == rhs.venueStatusText
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.groups == rhs.groups
            && lhs.groupIDs == rhs.groupIDs
    }
}

enum MapPuckMockData {
    static let pucks: [MapPuckData] = [
        MapPuckData(
            id: "chitty-blue-bottle",
            kind: .individual,
            people: [
                RealWorldMockData.friendPuck(
                    "chitty",
                    activity: "Coffee",
                    symbolName: "cup.and.saucer.fill",
                    displayText: "Blue Bottle",
                    availability: .freeNow,
                    venueStatusText: "At Blue Bottle",
                    lastUpdated: "3 min ago",
                    withWhom: nil,
                    locationLabel: "315 Linden St",
                    placeName: "Blue Bottle"
                )
            ],
            activity: "Coffee",
            availability: .freeNow,
            venueStatusText: "At Blue Bottle",
            coordinate: CLLocationCoordinate2D(latitude: 37.7812, longitude: -122.4078),
            groups: [.india]
        ),
        MapPuckData(
            id: "nitin-dolores",
            kind: .individual,
            people: [
                RealWorldMockData.friendPuck(
                    "nitin",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .maybeDown,
                    venueStatusText: "Near Dolores",
                    lastUpdated: "8 min ago",
                    withWhom: nil,
                    locationLabel: "19th St & Dolores St",
                    placeName: "Dolores Park"
                )
            ],
            activity: "Park",
            availability: .maybeDown,
            venueStatusText: "Near Dolores",
            coordinate: CLLocationCoordinate2D(latitude: 37.7596, longitude: -122.4269),
            groups: [.india]
        ),
        MapPuckData(
            id: "ishan-viplove-souvla",
            kind: .hangout,
            people: [
                RealWorldMockData.friendPuck(
                    "ishan",
                    activity: "Lunch",
                    symbolName: "fork.knife",
                    displayText: "Souvla",
                    availability: .joinable,
                    venueStatusText: "At Souvla",
                    lastUpdated: "Just now",
                    withWhom: ["Viplove"],
                    locationLabel: "517 Hayes St"
                ),
                RealWorldMockData.friendPuck(
                    "viplove",
                    activity: "Lunch",
                    symbolName: "fork.knife",
                    displayText: "Souvla",
                    availability: .joinable,
                    venueStatusText: "With Ishan",
                    lastUpdated: "Just now",
                    withWhom: ["Ishan"],
                    locationLabel: "517 Hayes St"
                )
            ],
            activity: "Lunch",
            availability: .joinable,
            venueStatusText: "At Souvla",
            coordinate: CLLocationCoordinate2D(latitude: 37.7765, longitude: -122.4231),
            groups: [.india]
        ),
        MapPuckData(
            id: "michigan-cluster",
            kind: .cluster,
            people: [
                RealWorldMockData.friendPuck(
                    "ram",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Already there",
                    lastUpdated: "5 min ago",
                    withWhom: ["Rohan", "Ryan", "Pranay"],
                    locationLabel: "Dolores Park, 19th St"
                ),
                RealWorldMockData.friendPuck(
                    "rohan",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Walking over",
                    lastUpdated: "5 min ago",
                    withWhom: ["Ram", "Ryan", "Pranay"]
                ),
                RealWorldMockData.friendPuck(
                    "ryan",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Free in 20",
                    lastUpdated: "5 min ago",
                    withWhom: ["Ram", "Rohan", "Pranay"]
                ),
                RealWorldMockData.friendPuck(
                    "pranay",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Maybe pulling up",
                    lastUpdated: "5 min ago",
                    withWhom: ["Ram", "Rohan", "Ryan"]
                )
            ],
            activity: "Park",
            availability: .joinable,
            venueStatusText: "Group forming near Dolores",
            coordinate: CLLocationCoordinate2D(latitude: 37.7673, longitude: -122.4358),
            groups: [.michigan]
        ),
        MapPuckData(
            id: "exec-crunch",
            kind: .friendGroup,
            people: [
                RealWorldMockData.groupPuck(
                    "exec",
                    activity: "Gym",
                    displayText: "Crunch",
                    lastUpdated: "12 min ago",
                    locationLabel: "350 Bay St"
                ),
                RealWorldMockData.friendPuck(
                    "ram",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Wrapping up",
                    lastUpdated: "12 min ago",
                    withWhom: ["Ohm"]
                ),
                RealWorldMockData.friendPuck(
                    "ohm",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "With Ram",
                    lastUpdated: "12 min ago",
                    withWhom: ["Ram"]
                ),
                RealWorldMockData.userPuck(
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "With Ram & Ohm",
                    lastUpdated: "Now",
                    withWhom: ["Ram", "Ohm"],
                    locationLabel: "350 Bay St"
                )
            ],
            activity: "Gym",
            availability: .joinable,
            venueStatusText: "At Crunch",
            coordinate: CLLocationCoordinate2D(latitude: 37.7898, longitude: -122.4210),
            groups: [.exec]
        )
    ]
}
