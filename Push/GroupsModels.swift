//
//  GroupsModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Foundation

struct PushGroupData: Identifiable, Equatable {
    let id: String
    let name: String
    let memberCount: Int
    let memberIDs: [String]
    let status: PushGroupStatus
    let activeNowCount: Int
    let nearbyCount: Int
    let planCount: Int
    let imageAssetName: String?
    let fallbackSymbol: String
    let fallbackInitials: String
}

enum PushGroupStatus: String, Equatable {
    case activeNow = "Active now"
    case quiet = "Quiet"
    case planLive = "Push live"
    case nearby = "Nearby"
    case freeSoon = "Free soon"

    var title: String { rawValue }
}

struct PushGroupStat: Identifiable, Equatable {
    let id: String
    let value: Int
    let label: String
}

struct PushGroupMemberData: Identifiable, Equatable {
    /// Person id — stable row identity for friend rows.
    let id: String
    /// `GroupMembership.id` for cancel-invite / membership mutations.
    let membershipID: String
    let name: String
    let avatarPlaceholder: String
    let profileImageAssetName: String?
    let availability: FriendAvailabilityState?
    let activitySymbolName: String
    let venueStatusText: String
    let lastUpdated: String
    /// True when `GroupMembership.role == .owner`.
    let isOwner: Bool
    /// True for an invited-but-not-yet-accepted member (`GroupMembership.Status.invited`).
    /// Default false keeps existing call sites (previews, tests) unaffected.
    let isPending: Bool

    init(
        id: String,
        name: String,
        avatarPlaceholder: String,
        profileImageAssetName: String?,
        availability: FriendAvailabilityState?,
        activitySymbolName: String = "person.fill",
        venueStatusText: String? = nil,
        lastUpdated: String = "",
        membershipID: String = "",
        isOwner: Bool = false,
        isPending: Bool = false
    ) {
        self.id = id
        self.membershipID = membershipID
        self.name = name
        self.avatarPlaceholder = avatarPlaceholder
        self.profileImageAssetName = profileImageAssetName
        self.availability = availability
        self.activitySymbolName = activitySymbolName
        self.venueStatusText = venueStatusText ?? availability?.title ?? "Hidden right now"
        self.lastUpdated = lastUpdated
        self.isOwner = isOwner
        self.isPending = isPending
    }

    var friendRow: FriendRowModel {
        FriendRowModel(
            id: id,
            friend: FriendPuckData(
                id: id,
                name: name,
                avatarPlaceholder: avatarPlaceholder,
                profileImageAssetName: profileImageAssetName,
                activity: "",
                activitySymbolName: activitySymbolName,
                activityDisplayText: "",
                availability: availability ?? .unavailable,
                venueStatusText: venueStatusText,
                lastUpdated: lastUpdated,
                isCurrentUser: false
            ),
            groupLabel: nil
        )
    }
}
