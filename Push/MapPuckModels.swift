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
    /// Canonical group IDs used for map filtering.
    let groupIDs: [String]

    init(
        id: String,
        kind: MapPuckKind,
        people: [FriendPuckData],
        activity: String,
        availability: FriendAvailabilityState,
        venueStatusText: String,
        coordinate: CLLocationCoordinate2D,
        groupIDs: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.people = people
        self.activity = activity
        self.availability = availability
        self.venueStatusText = venueStatusText
        self.coordinate = coordinate
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
            && lhs.groupIDs == rhs.groupIDs
    }
}
