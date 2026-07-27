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

struct SelfPuckData: Equatable {
    let id: String
    let avatarPlaceholder: String
    let profileImageAssetName: String?
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: SelfPuckData, rhs: SelfPuckData) -> Bool {
        lhs.id == rhs.id
            && lhs.avatarPlaceholder == rhs.avatarPlaceholder
            && lhs.profileImageAssetName == rhs.profileImageAssetName
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct RegionalPuckModel: Identifiable, Equatable {
    private static let knownRegionAbbreviations = [
        "san francisco": "SF",
        "new york": "NYC",
        "new york city": "NYC",
        "san diego": "SD",
        "los angeles": "LA",
        "chicago": "CHI",
        "seattle": "SEA",
    ]

    let id: String
    let coordinate: CLLocationCoordinate2D
    let memberCount: Int
    let containsCurrentUser: Bool
    let containsJoinedGroup: Bool
    let activeCount: Int
    let joinableCount: Int
    let busyCount: Int
    let dominantAvailability: FriendAvailabilityState
    let representativeAvatars: [FriendPuckData]
    let regionName: String
    let activityScore: Double
    let groupIDs: [String]

    var regionAbbreviation: String {
        let normalized = regionName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let known = Self.knownRegionAbbreviations[normalized] {
            return known
        }

        let words = regionName.split(whereSeparator: \.isWhitespace)
        if words.count > 1 {
            let initials = words.prefix(3).compactMap(\.first).map(String.init).joined()
            return initials.isEmpty ? "NEAR" : initials.uppercased()
        }
        let compact = regionName.filter(\.isLetter)
        return compact.isEmpty ? "NEAR" : String(compact.prefix(3)).uppercased()
    }

    var isSociallyActive: Bool {
        activeCount > 0 || joinableCount > 0
    }

    var availabilitySummary: String {
        if joinableCount > 0 {
            return "\(activeCount) active · \(joinableCount) joinable"
        }
        if activeCount > 0 {
            return "\(activeCount) active now"
        }
        if busyCount > 0 {
            return busyCount == memberCount ? "Everyone is busy right now" : "\(busyCount) busy right now"
        }
        return "Availability not shared"
    }

    static func == (lhs: RegionalPuckModel, rhs: RegionalPuckModel) -> Bool {
        lhs.id == rhs.id
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.memberCount == rhs.memberCount
            && lhs.containsCurrentUser == rhs.containsCurrentUser
            && lhs.containsJoinedGroup == rhs.containsJoinedGroup
            && lhs.activeCount == rhs.activeCount
            && lhs.joinableCount == rhs.joinableCount
            && lhs.busyCount == rhs.busyCount
            && lhs.dominantAvailability == rhs.dominantAvailability
            && lhs.representativeAvatars == rhs.representativeAvatars
            && lhs.regionName == rhs.regionName
            && lhs.activityScore == rhs.activityScore
            && lhs.groupIDs == rhs.groupIDs
    }
}

struct RegionalPuckSource: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let people: [FriendPuckData]
    let availability: FriendAvailabilityState
    let regionName: String
    let containsCurrentUser: Bool
    let groupIDs: [String]

    static func == (lhs: RegionalPuckSource, rhs: RegionalPuckSource) -> Bool {
        lhs.id == rhs.id
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.people == rhs.people
            && lhs.availability == rhs.availability
            && lhs.regionName == rhs.regionName
            && lhs.containsCurrentUser == rhs.containsCurrentUser
            && lhs.groupIDs == rhs.groupIDs
    }
}

enum MapPuckRenderModel: Identifiable, Equatable {
    case selfPuck(SelfPuckData)
    case friend(MapPuckData)
    case smallGroup(MapPuckData)
    case regionalCluster(RegionalPuckModel)

    var id: String {
        switch self {
        case .selfPuck(let puck):
            return "self-\(puck.id)"
        case .friend(let puck), .smallGroup(let puck):
            return puck.id
        case .regionalCluster(let puck):
            return puck.id
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .selfPuck(let puck):
            return puck.coordinate
        case .friend(let puck), .smallGroup(let puck):
            return puck.coordinate
        case .regionalCluster(let puck):
            return puck.coordinate
        }
    }

    var containsCurrentUser: Bool {
        switch self {
        case .selfPuck:
            return true
        case .friend(let puck), .smallGroup(let puck):
            return puck.includesCurrentUser
        case .regionalCluster(let puck):
            return puck.containsCurrentUser
        }
    }
}
