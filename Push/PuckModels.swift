//
//  PuckModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import Foundation

enum FriendAvailabilityState: CaseIterable, Equatable {
    case freeNow
    case freeSoon
    case maybeDown
    case busy
    case joinable
    case driving
    case unavailable

    var title: String {
        switch self {
        case .freeNow:
            return "Free now"
        case .freeSoon:
            return "Free soon"
        case .maybeDown:
            return "Maybe down"
        case .busy:
            return "Busy"
        case .joinable:
            return "Joinable"
        case .driving:
            return "Driving / ETA"
        case .unavailable:
            return "Unavailable"
        }
    }

    var symbolName: String {
        switch self {
        case .freeNow:
            return "sparkles"
        case .freeSoon:
            return "clock.fill"
        case .maybeDown:
            return "sparkle.magnifyingglass"
        case .busy:
            return "moon.fill"
        case .joinable:
            return "figure.wave"
        case .driving:
            return "car.fill"
        case .unavailable:
            return "minus.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .freeNow:
            return "green"
        case .freeSoon, .maybeDown:
            return "yellow"
        case .joinable:
            return "blue"
        case .busy:
            return "orange"
        case .driving:
            return "cyan"
        case .unavailable:
            return "gray"
        }
    }

    var priority: Int {
        switch self {
        case .freeNow:
            return 0
        case .joinable:
            return 1
        case .maybeDown:
            return 2
        case .freeSoon:
            return 3
        case .busy:
            return 4
        case .driving:
            return 5
        case .unavailable:
            return 6
        }
    }
}

struct FriendPuckData: Identifiable, Equatable {
    let id: UUID
    let name: String
    let avatarPlaceholder: String
    let profileImageAssetName: String?
    let activity: String
    let activitySymbolName: String
    let activityDisplayText: String
    let availability: FriendAvailabilityState
    let venueStatusText: String
    let lastUpdated: String
    let withWhom: [String]?
    let locationLabel: String?
    let placeName: String?

    init(
        id: UUID = UUID(),
        name: String,
        avatarPlaceholder: String,
        profileImageAssetName: String? = nil,
        activity: String,
        activitySymbolName: String,
        activityDisplayText: String,
        availability: FriendAvailabilityState,
        venueStatusText: String,
        lastUpdated: String = "Just now",
        withWhom: [String]? = nil,
        locationLabel: String? = nil,
        placeName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.avatarPlaceholder = avatarPlaceholder
        self.profileImageAssetName = profileImageAssetName
        self.activity = activity
        self.activitySymbolName = activitySymbolName
        self.activityDisplayText = activityDisplayText
        self.availability = availability
        self.venueStatusText = venueStatusText
        self.lastUpdated = lastUpdated
        self.withWhom = withWhom
        self.locationLabel = locationLabel
        self.placeName = placeName
    }
}

struct PuckLabScenario: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let friends: [FriendPuckData]
    let puckStyle: PuckLabPuckStyle

    init(
        title: String,
        subtitle: String,
        friends: [FriendPuckData],
        puckStyle: PuckLabPuckStyle = .automatic
    ) {
        self.id = title
        self.title = title
        self.subtitle = subtitle
        self.friends = friends
        self.puckStyle = puckStyle
    }
}

enum PuckLabPuckStyle: Equatable {
    case automatic
    case friendGroup
}

enum FriendClusterLayoutKind: Equatable {
    case pair
    case smallGroup

    init(friendsCount: Int) {
        self = friendsCount == 2 ? .pair : .smallGroup
    }
}

enum PuckLabMockData {
    static let scenarios: [PuckLabScenario] = singleFriendScenarios + clusterScenarios + friendGroupScenarios

    static let singleFriendScenarios: [PuckLabScenario] = [
        PuckLabScenario(
            title: "Free now",
            subtitle: "Green live glow, open to move",
            friends: [
                RealWorldMockData.friendPuck(
                    "chitty",
                    activity: "Coffee",
                    symbolName: "cup.and.saucer.fill",
                    displayText: "Blue Bottle",
                    availability: .freeNow,
                    venueStatusText: "At Blue Bottle"
                )
            ]
        ),
        PuckLabScenario(
            title: "Maybe down",
            subtitle: "Yellow, soft social signal",
            friends: [
                RealWorldMockData.friendPuck(
                    "nitin",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .maybeDown,
                    venueStatusText: "Near Dolores"
                )
            ]
        ),
        PuckLabScenario(
            title: "Joinable",
            subtitle: "Blue, clear pull-up energy",
            friends: [
                RealWorldMockData.friendPuck(
                    "ishan",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "At Crunch"
                )
            ]
        ),
        PuckLabScenario(
            title: "Busy-ish",
            subtitle: "Orange, currently in something",
            friends: [
                RealWorldMockData.friendPuck(
                    "ram",
                    activity: "Food",
                    symbolName: "fork.knife",
                    displayText: "Cotijas",
                    availability: .busy,
                    venueStatusText: "Eating at Cotijas"
                )
            ]
        ),
        PuckLabScenario(
            title: "Driving",
            subtitle: "Cyan, moving with ETA context",
            friends: [
                RealWorldMockData.friendPuck(
                    "rohan",
                    activity: "Driving",
                    symbolName: "car.fill",
                    displayText: "Driving",
                    availability: .driving,
                    venueStatusText: "ETA 12 min"
                )
            ]
        ),
        PuckLabScenario(
            title: "Unavailable",
            subtitle: "Gray, low social availability",
            friends: [
                RealWorldMockData.friendPuck(
                    "ohm",
                    activity: "Work",
                    symbolName: "laptopcomputer",
                    displayText: "Work",
                    availability: .unavailable,
                    venueStatusText: "Heads down"
                )
            ]
        )
    ]

    private static let clusterScenarios: [PuckLabScenario] = [
        PuckLabScenario(
            title: "Together",
            subtitle: "Two friends already hanging out",
            friends: [
                RealWorldMockData.friendPuck(
                    "ishan",
                    activity: "Lunch",
                    symbolName: "fork.knife",
                    displayText: "Souvla",
                    availability: .joinable,
                    venueStatusText: "At Souvla"
                ),
                RealWorldMockData.friendPuck(
                    "viplove",
                    activity: "Lunch",
                    symbolName: "fork.knife",
                    displayText: "Souvla",
                    availability: .joinable,
                    venueStatusText: "With Ishan"
                )
            ]
        ),
        PuckLabScenario(
            title: "Small group",
            subtitle: "Four people, one social signal",
            friends: [
                RealWorldMockData.friendPuck(
                    "ram",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Near Dolores"
                ),
                RealWorldMockData.friendPuck(
                    "rohan",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Walking over"
                ),
                RealWorldMockData.friendPuck(
                    "ryan",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Free in 20"
                ),
                RealWorldMockData.friendPuck(
                    "pranay",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Already there"
                )
            ]
        )
    ]

    private static let friendGroupScenarios: [PuckLabScenario] = [
        PuckLabScenario(
            title: "Friend group",
            subtitle: "Saved circle, one group presence",
            friends: [
                RealWorldMockData.groupPuck(
                    "india",
                    activity: "Gym",
                    displayText: "Crunch"
                ),
                RealWorldMockData.friendPuck(
                    "chitty",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Already there"
                ),
                RealWorldMockData.friendPuck(
                    "nitin",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "With the crew"
                ),
                RealWorldMockData.friendPuck(
                    "ishan",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Wrapping up"
                ),
                RealWorldMockData.friendPuck(
                    "roh",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Joining soon"
                )
            ],
            puckStyle: .friendGroup
        )
    ]
}
