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
                    withWhom: nil
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
                    withWhom: nil
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
                    withWhom: ["Viplove"]
                ),
                RealWorldMockData.friendPuck(
                    "viplove",
                    activity: "Lunch",
                    symbolName: "fork.knife",
                    displayText: "Souvla",
                    availability: .joinable,
                    venueStatusText: "With Ishan",
                    lastUpdated: "Just now",
                    withWhom: ["Ishan"]
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
                    withWhom: ["Rohan", "Ryan", "Pranay"]
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
                    lastUpdated: "12 min ago"
                ),
                RealWorldMockData.friendPuck(
                    "ram",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Wrapping up",
                    lastUpdated: "12 min ago",
                    withWhom: ["Ohm", "Roh"]
                ),
                RealWorldMockData.friendPuck(
                    "ohm",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "With the crew",
                    lastUpdated: "12 min ago",
                    withWhom: ["Ram", "Roh"]
                ),
                RealWorldMockData.friendPuck(
                    "roh",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Joining soon",
                    lastUpdated: "12 min ago",
                    withWhom: ["Ram", "Ohm"]
                )
            ],
            activity: "Gym",
            availability: .joinable,
            venueStatusText: "Exec at Crunch",
            coordinate: CLLocationCoordinate2D(latitude: 37.7898, longitude: -122.4210),
            groups: [.exec]
        )
    ]
}
