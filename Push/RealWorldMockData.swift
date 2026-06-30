//
//  RealWorldMockData.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Foundation

struct RealFriendSeed: Identifiable, Equatable {
    let id: String
    let firstName: String
    let imageAssetName: String

    var displayName: String {
        firstName.prefix(1).uppercased() + firstName.dropFirst()
    }

    var initials: String {
        String(firstName.prefix(2)).uppercased()
    }
}

struct RealGroupSeed: Identifiable, Equatable {
    let id: String
    let name: String
    let memberIDs: [String]
    let imageAssetName: String?
    let status: PushGroupStatus
    let activeNowCount: Int
    let nearbyCount: Int
    let planCount: Int
}

enum RealWorldMockData {
    static let profileImageAssetName = "assets/profile/manav.jpeg"

    static let friends: [RealFriendSeed] = [
        friend("chitty"),
        friend("ishan"),
        friend("nitin"),
        friend("ohm"),
        friend("pranay"),
        friend("ram"),
        friend("roh"),
        friend("rohan"),
        friend("ryan"),
        friend("viplove")
    ]

    static let groups: [RealGroupSeed] = [
        RealGroupSeed(
            id: "india",
            name: "India",
            memberIDs: ["chitty", "nitin", "ishan", "viplove", "roh"],
            imageAssetName: "assets/groups/India/chitty.png",
            status: .activeNow,
            activeNowCount: 3,
            nearbyCount: 2,
            planCount: 1
        ),
        RealGroupSeed(
            id: "exec",
            name: "Exec",
            memberIDs: ["ram", "ohm", "manav"],
            imageAssetName: "assets/groups/Exec/ram.png",
            status: .nearby,
            activeNowCount: 1,
            nearbyCount: 1,
            planCount: 0
        ),
        RealGroupSeed(
            id: "michigan",
            name: "Michigan",
            memberIDs: ["ram", "rohan", "ryan", "ohm", "pranay"],
            imageAssetName: "assets/groups/Michigan/ram.png",
            status: .planLive,
            activeNowCount: 2,
            nearbyCount: 1,
            planCount: 1
        )
    ]

    static func friend(withID id: String) -> RealFriendSeed {
        friends.first { $0.id == id } ?? friend(id)
    }

    static func friendPuck(
        _ id: String,
        activity: String,
        symbolName: String,
        displayText: String,
        availability: FriendAvailabilityState,
        venueStatusText: String,
        lastUpdated: String = "Just now",
        withWhom: [String]? = nil,
        locationLabel: String? = nil,
        placeName: String? = nil
    ) -> FriendPuckData {
        let seed = friend(withID: id)
        return FriendPuckData(
            name: seed.displayName,
            avatarPlaceholder: seed.initials,
            profileImageAssetName: seed.imageAssetName,
            activity: activity,
            activitySymbolName: symbolName,
            activityDisplayText: displayText,
            availability: availability,
            venueStatusText: venueStatusText,
            lastUpdated: lastUpdated,
            withWhom: withWhom,
            locationLabel: locationLabel,
            placeName: placeName
        )
    }

    static func groupPuck(
        _ groupID: String,
        activity: String,
        displayText: String,
        lastUpdated: String = "Just now",
        locationLabel: String? = nil
    ) -> FriendPuckData {
        let group = groups.first { $0.id == groupID }
        return FriendPuckData(
            name: group?.name ?? groupID,
            avatarPlaceholder: initials(for: group?.name ?? groupID),
            profileImageAssetName: group?.imageAssetName,
            activity: activity,
            activitySymbolName: "person.3.fill",
            activityDisplayText: displayText,
            availability: .joinable,
            venueStatusText: "\(group?.name ?? "Group") is together",
            lastUpdated: lastUpdated,
            withWhom: nil,
            locationLabel: locationLabel
        )
    }

    static func userPuck(
        activity: String,
        symbolName: String,
        displayText: String,
        availability: FriendAvailabilityState,
        venueStatusText: String,
        lastUpdated: String = "Just now",
        withWhom: [String]? = nil,
        locationLabel: String? = nil
    ) -> FriendPuckData {
        FriendPuckData(
            name: "Manav",
            avatarPlaceholder: "MK",
            profileImageAssetName: profileImageAssetName,
            activity: activity,
            activitySymbolName: symbolName,
            activityDisplayText: displayText,
            availability: availability,
            venueStatusText: venueStatusText,
            lastUpdated: lastUpdated,
            withWhom: withWhom,
            locationLabel: locationLabel,
            isCurrentUser: true
        )
    }

    private static func friend(_ firstName: String) -> RealFriendSeed {
        RealFriendSeed(
            id: firstName,
            firstName: firstName,
            imageAssetName: "assets/friends/\(firstName).png"
        )
    }

    private static func initials(for name: String) -> String {
        name.split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
